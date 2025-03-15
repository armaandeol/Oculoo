import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_init;
import 'package:android_intent_plus/android_intent.dart';
import 'dart:convert';
import 'dart:io';

enum DateRangeOption { forever, thisMonth, custom }

class PillReminderPage extends StatefulWidget {
  @override
  _PillReminderPageState createState() => _PillReminderPageState();
}

class _PillReminderPageState extends State<PillReminderPage> {
  final _formKey = GlobalKey<FormState>();

  // Notifications plugin
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Controllers for basic info
  final TextEditingController _medicineController = TextEditingController();
  final TextEditingController _dosageController = TextEditingController();
  final TextEditingController _unitController = TextEditingController();

  // Track upcoming notifications for debugging
  List<Map<String, dynamic>> _upcomingNotifications = [];

  // Controllers for dates
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();

  // Time(s) controller list for daily dosages
  int _dosageCount = 1;
  List<TextEditingController> _timeControllers = [TextEditingController()];

  // Frequency & days
  String _frequency = 'Daily'; // Options: Daily, Weekly, Custom
  String _selectedWeeklyDay = 'Monday';
  Map<String, bool> _selectedCustomDays = {
    'Mon': false,
    'Tue': false,
    'Wed': false,
    'Thu': false,
    'Fri': false,
    'Sat': false,
    'Sun': false
  };

  DateRangeOption _dateRangeOption = DateRangeOption.forever;

  // Color scheme
  final Color _primaryColor = Color(0xFF6C5CE7);
  final Color _secondaryColor = Color(0xFFA8A5E6);
  final Color _accentColor = Color(0xFF00C2CB);
  final LinearGradient _mainGradient = LinearGradient(
    colors: [Color(0xFF6C5CE7), Color(0xFF00C2CB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Track scheduled notification IDs
  final Map<String, List<int>> _scheduledNotificationIds = {};

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    // By default, set startDate as today and endDate far in the future
    _startDateController.text = _formatDate(today);
    _endDateController.text = _formatDate(
        DateTime(today.year + 100, today.month, today.day)); // "Forever"

    // Initialize notifications
    _initializeNotifications();

    // Check notification permissions
    _checkNotificationStatus();
  }

  // Initialize local notifications
  Future<void> _initializeNotifications() async {
    tz_init.initializeTimeZones();

    // Request Android notification permissions for Android 13+
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
          flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      await androidPlugin?.requestNotificationsPermission();

      // Create notification channels for Android 8.0+
      await androidPlugin?.createNotificationChannel(
        AndroidNotificationChannel(
          'medication_channel',
          'Medication Reminders',
          description: 'Notifications for medication reminders',
          importance: Importance.max,
          playSound: true,
        ),
      );

      // Create test notification channel
      await androidPlugin?.createNotificationChannel(
        AndroidNotificationChannel(
          'test_channel',
          'Test Notifications',
          description: 'For testing notifications',
          importance: Importance.max,
        ),
      );
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse:
          (NotificationResponse notificationResponse) async {
        if (notificationResponse.payload != null) {
          debugPrint('Notification payload: ${notificationResponse.payload}');

          // Handle notification tap with payload
          final payload = jsonDecode(notificationResponse.payload!);
          final medicationName = payload['medicationName'];
          final endDate = DateTime.parse(payload['endDate']);

          // Check if the end date has passed
          if (DateTime.now().isAfter(endDate) &&
              notificationResponse.id != null) {
            // Cancel this notification if end date has passed
            await flutterLocalNotificationsPlugin
                .cancel(notificationResponse.id!);
          }
        }
      },
    );
  }

  // Schedule notifications for medication reminders
  Future<void> _scheduleNotifications(String medicationName, List<String> times,
      String unit, String dosage, String startDate, String endDate) async {
    // Request permission
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

    final now = DateTime.now();
    final endDateDateTime = DateTime.parse(endDate);

    for (int i = 0; i < times.length; i++) {
      if (times[i].isEmpty) continue;

      final timeParts = times[i].split(':');
      if (timeParts.length != 2) continue;

      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      // Create notification time
      DateTime scheduledDate = DateTime(
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      // If time for today has already passed, schedule for tomorrow
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(Duration(days: 1));
      }

      // Generate unique ID
      final uniqueId = "${medicationName}_${hour}_$minute".hashCode;

      // Schedule notification with end date check
      await _scheduleNotificationWithEndDate(
        id: uniqueId,
        title: 'Medication Reminder: $medicationName',
        body: 'Time to take $dosage $unit of $medicationName',
        scheduledDate: scheduledDate,
        endDate: endDateDateTime,
        repeatDaily: true,
      );

      // Track scheduled IDs
      if (_scheduledNotificationIds[medicationName] == null) {
        _scheduledNotificationIds[medicationName] = [];
      }
      _scheduledNotificationIds[medicationName]!.add(uniqueId);
    }
  }

  Future<void> _scheduleNotificationWithEndDate({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    required DateTime endDate,
    required bool repeatDaily,
  }) async {
    // Always use inexact alarms to avoid permission issues
    final androidScheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'medication_channel',
      'Medication Reminders',
      channelDescription: 'Notifications for medication reminders',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    try {
      if (repeatDaily) {
        await flutterLocalNotificationsPlugin.zonedSchedule(
          id,
          title,
          body,
          tz.TZDateTime.from(scheduledDate, tz.local),
          notificationDetails,
          androidScheduleMode: androidScheduleMode,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: jsonEncode({
            'medicationName': title.split(':').last.trim(),
            'endDate': endDate.toIso8601String(),
          }),
        );

        // Store notification info for debugging
        final now = DateTime.now();
        final difference = scheduledDate.difference(now);

        // Debug info in console
        debugPrint('🔔 Notification scheduled:');
        debugPrint('ID: $id');
        debugPrint('Title: $title');
        debugPrint('Time: ${scheduledDate.toString()}');
        debugPrint('Seconds until trigger: ${difference.inSeconds}');

        // Add to tracked notifications for UI display
        setState(() {
          _upcomingNotifications.add({
            'id': id,
            'title': title,
            'scheduledTime': scheduledDate,
            'body': body,
            'repeating': repeatDaily,
          });

          // Sort by time (earliest first)
          _upcomingNotifications.sort((a, b) => (a['scheduledTime'] as DateTime)
              .compareTo(b['scheduledTime'] as DateTime));

          // Limit list size
          if (_upcomingNotifications.length > 10) {
            _upcomingNotifications = _upcomingNotifications.sublist(0, 10);
          }
        });
      } else {
        // One-time notification code...
      }
    } catch (e) {
      debugPrint('Failed to schedule notification: $e');
      // Additional error handling...
    }
  }

  // Add a method to test notifications immediately
  Future<void> _testNotification() async {
    final now = DateTime.now().add(Duration(seconds: 5));

    try {
      AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'test_channel',
        'Test Notifications',
        channelDescription: 'For testing notifications',
        importance: Importance.max,
        priority: Priority.high,
      );

      NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidDetails,
      );

      await flutterLocalNotificationsPlugin.zonedSchedule(
        99999, // Use a unique ID for test
        'TEST NOTIFICATION',
        'This is a test notification - ${DateTime.now().toString()}',
        tz.TZDateTime.from(now, tz.local),
        platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '⏰ Test notification scheduled for 5 seconds from now!',
          ),
          backgroundColor: _primaryColor,
        ),
      );

      // Add to tracked notifications
      setState(() {
        _upcomingNotifications.add({
          'id': 99999,
          'title': 'TEST NOTIFICATION',
          'scheduledTime': now,
          'body': 'This is a test notification',
          'repeating': false,
        });

        // Sort by time
        _upcomingNotifications.sort((a, b) => (a['scheduledTime'] as DateTime)
            .compareTo(b['scheduledTime'] as DateTime));
      });
    } catch (e) {
      debugPrint('Test notification failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  // Check notification permissions and potential issues
  Future<void> _checkNotificationStatus() async {
    if (Platform.isAndroid) {
      final androidPlugin =
          flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        debugPrint('Checking notification permissions...');

        // Check notification permission
        final bool? areNotificationsEnabled =
            await androidPlugin.areNotificationsEnabled();
        debugPrint('Notifications enabled: $areNotificationsEnabled');

        // Check exact alarms permission (Android 12+)
        try {
          final bool? hasExactAlarmPermission =
              await androidPlugin.canScheduleExactNotifications();
          debugPrint('Has exact alarm permission: $hasExactAlarmPermission');
        } catch (e) {
          debugPrint('Error checking exact alarm permission: $e');
        }

        // Power optimization info
        debugPrint(
            'Note: If running on MIUI (Xiaomi), EMUI (Huawei), or other heavily customized Android versions,');
        debugPrint(
            'additional battery optimization settings may need to be disabled for notifications to work properly.');
      }
    }
  }

  /// Formats DateTime as yyyy-MM-dd
  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  /// Opens a time picker and saves the selected time as a 24-hour string.
  Future<void> _pickTime(int index) async {
    final initialTime = TimeOfDay.now();
    final picked =
        await showTimePicker(context: context, initialTime: initialTime);
    if (picked != null) {
      setState(() {
        final hour = picked.hour.toString().padLeft(2, '0');
        final minute = picked.minute.toString().padLeft(2, '0');
        _timeControllers[index].text = "$hour:$minute";
      });
    }
  }

  /// Opens a date range picker for custom date range selection.
  Future<void> _pickDateRange() async {
    final today = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange:
          DateTimeRange(start: today, end: today.add(Duration(days: 7))),
    );
    if (range != null) {
      setState(() {
        _startDateController.text = _formatDate(range.start);
        _endDateController.text = _formatDate(range.end);
      });
    }
  }

  /// Updates date range values based on the selected option.
  void _onDateRangeOptionChanged(DateRangeOption? option) async {
    if (option == null) return;
    setState(() {
      _dateRangeOption = option;
    });
    final today = DateTime.now();
    if (option == DateRangeOption.forever) {
      _startDateController.text = _formatDate(today);
      _endDateController.text =
          _formatDate(DateTime(today.year + 100, today.month, today.day));
    } else if (option == DateRangeOption.thisMonth) {
      final firstDay = DateTime(today.year, today.month, 1);
      final lastDay = DateTime(today.year, today.month + 1, 0);
      _startDateController.text = _formatDate(firstDay);
      _endDateController.text = _formatDate(lastDay);
    } else if (option == DateRangeOption.custom) {
      await _pickDateRange();
    }
  }

  /// Updates the number of daily dosages and ensures a matching list of time controllers.
  void _updateDosageCount(String value) {
    final count = int.tryParse(value) ?? 1;
    if (count > 0) {
      setState(() {
        _dosageCount = count;
        if (_timeControllers.length < _dosageCount) {
          for (var i = _timeControllers.length; i < _dosageCount; i++) {
            _timeControllers.add(TextEditingController());
          }
        } else if (_timeControllers.length > _dosageCount) {
          _timeControllers = _timeControllers.sublist(0, _dosageCount);
        }
      });
    }
  }

  /// Validates the form, builds the reminder data map, and saves it to Firestore.
  Future<void> _submitReminder() async {
    if (!_formKey.currentState!.validate()) return;

    // Prepare the days field based on frequency.
    dynamic daysSelected;
    if (_frequency == "Weekly") {
      daysSelected = [_selectedWeeklyDay];
    } else if (_frequency == "Custom") {
      daysSelected = _selectedCustomDays.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList();
    } else {
      daysSelected = "Daily";
    }

    // Build the reminder data map.
    Map<String, dynamic> reminderData = {
      "pillName": _medicineController.text.trim(),
      "dosage": _dosageController.text.trim(),
      "unit": _unitController.text.trim(),
      "times": _timeControllers.map((c) => c.text.trim()).toList(),
      "startDate": _startDateController.text.trim(),
      "endDate": _endDateController.text.trim(),
      "frequency": _frequency,
      "days": daysSelected,
      "createdAt": FieldValue.serverTimestamp(),
    };

    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("User not authenticated.")));
        return;
      }
      final uid = user.uid;
      CollectionReference remindersRef = FirebaseFirestore.instance
          .collection('patient')
          .doc(uid)
          .collection('Medications');
      await remindersRef.add(reminderData);

      // Check if we have exact alarm permission and show appropriate message
      final canUseExactAlarms = await _requestExactAlarmPermission();
      if (!canUseExactAlarms) {
        // Show dialog about inexact notifications
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              "Medication notifications may not arrive at the exact time due to system restrictions."),
          duration: Duration(seconds: 5),
          action: SnackBarAction(
            label: 'SETTINGS',
            onPressed: () {
              // Replace open_settings with direct app settings navigation
              _openNotificationSettings();
            },
          ),
        ));
      }

      // Schedule notifications for each time
      await _scheduleNotifications(
        _medicineController.text.trim(),
        _timeControllers.map((c) => c.text.trim()).toList(),
        _unitController.text.trim(),
        _dosageController.text.trim(),
        _startDateController.text.trim(),
        _endDateController.text.trim(),
      );

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Pill reminder set successfully with notifications.")));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error saving reminder: $e")));
    }
  }

  @override
  void dispose() {
    // Cancel all scheduled notifications when the widget is disposed
    _scheduledNotificationIds.forEach((medication, ids) {
      for (final id in ids) {
        flutterLocalNotificationsPlugin.cancel(id);
      }
    });
    _scheduledNotificationIds.clear();

    _medicineController.dispose();
    _dosageController.dispose();
    _unitController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _timeControllers.forEach((controller) => controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Pill Reminder",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 24,
            )),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: _mainGradient),
        ),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Add test button to check if notifications work
          IconButton(
            icon: Icon(Icons.notifications_active, color: Colors.white),
            onPressed: _testNotification,
            tooltip: 'Test Notification (5 sec)',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Color(0xFFF8F9FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: ListView(
              physics: BouncingScrollPhysics(),
              children: [
                _buildSectionTitle("Medicine Details", Icons.medical_services),
                _buildMedicineCard(),
                SizedBox(height: 20),
                _buildSectionTitle("Dosage Schedule", Icons.schedule),
                _buildScheduleCard(),
                SizedBox(height: 20),
                _buildSectionTitle("Reminder Settings", Icons.notifications),
                _buildSettingsCard(),
                SizedBox(height: 20),

                // Add upcoming notifications section for debugging
                if (_upcomingNotifications.isNotEmpty)
                  _buildSectionTitle(
                      "Upcoming Notifications (Debug)", Icons.bug_report),
                if (_upcomingNotifications.isNotEmpty)
                  _buildUpcomingNotificationsCard(),

                SizedBox(height: 30),
                _buildSubmitButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: _primaryColor, size: 28),
          SizedBox(width: 10),
          Text(text,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _primaryColor,
              )),
        ],
      ),
    );
  }

  Widget _buildMedicineCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildIconInputField(
              controller: _medicineController,
              label: "Medicine Name",
              icon: Icons.medication,
              validator: (v) => v!.isEmpty ? "Required" : null,
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildIconInputField(
                      controller: _dosageController,
                      label: "Dosage",
                      icon: Icons.exposure,
                      keyboardType: TextInputType.number,
                      validator: (v) => v!.isEmpty ? "Required" : null),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _buildIconInputField(
                      controller: _unitController,
                      label: "Unit",
                      icon: Icons.square_foot,
                      validator: (v) => v!.isEmpty ? "Required" : null),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildTimeInputs(),
            SizedBox(height: 16),
            _buildDateRangeSelector(),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeInputs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            children: [
              Icon(Icons.timer, color: _accentColor, size: 20),
              SizedBox(width: 8),
              Text("Dosage Times",
                  style: TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        ...List.generate(_dosageCount, (index) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: TextFormField(
              controller: _timeControllers[index],
              readOnly: true,
              onTap: () => _pickTime(index),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                hintText: "Select Time ${index + 1}",
                prefixIcon: Icon(Icons.access_time, color: _primaryColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 15),
                suffix: _buildDosageNumber(index + 1),
              ),
              style: TextStyle(fontSize: 16),
              validator: (v) => v!.isEmpty ? "Required" : null,
            ),
          );
        }),
        _buildDosageCounter(),
      ],
    );
  }

  Widget _buildDosageNumber(int number) {
    return Container(
      padding: EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: _primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text("#$number",
          style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildDosageCounter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text("Total Daily Dosages:", style: TextStyle(color: Colors.grey[700])),
        Container(
          decoration: BoxDecoration(
            color: _primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.remove, color: _primaryColor),
                onPressed: () => _updateDosageCount("${_dosageCount - 1}"),
              ),
              Text("$_dosageCount", style: TextStyle(fontSize: 18)),
              IconButton(
                icon: Icon(Icons.add, color: _primaryColor),
                onPressed: () => _updateDosageCount("${_dosageCount + 1}"),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDateRangeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            children: [
              Icon(Icons.calendar_today, color: _accentColor, size: 20),
              SizedBox(width: 8),
              Text("Date Range", style: TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: DateRangeOption.values.map((option) {
            final isSelected = _dateRangeOption == option;
            return GestureDetector(
              onTap: () => _onDateRangeOptionChanged(option),
              child: Container(
                width: 110,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _primaryColor.withOpacity(0.15)
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? _primaryColor : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      _getDateRangeIcon(option),
                      color: isSelected ? _primaryColor : Colors.grey[600],
                      size: 28,
                    ),
                    SizedBox(height: 8),
                    Text(
                      _getDateRangeLabel(option),
                      style: TextStyle(
                        color: isSelected ? _primaryColor : Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  IconData _getDateRangeIcon(DateRangeOption option) {
    switch (option) {
      case DateRangeOption.forever:
        return Icons.all_inclusive;
      case DateRangeOption.thisMonth:
        return Icons.calendar_month;
      case DateRangeOption.custom:
        return Icons.edit_calendar;
    }
  }

  String _getDateRangeLabel(DateRangeOption option) {
    switch (option) {
      case DateRangeOption.forever:
        return "Forever";
      case DateRangeOption.thisMonth:
        return "This Month";
      case DateRangeOption.custom:
        return "Custom";
    }
  }

  Widget _buildSettingsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildFrequencySelector(),
            SizedBox(height: 16),
            if (_frequency == "Weekly") _buildWeeklySelector(),
            if (_frequency == "Custom") _buildCustomDaysSelector(),
          ],
        ),
      ),
    );
  }

  Widget _buildFrequencySelector() {
    return InputDecorator(
      decoration: InputDecoration(
          labelText: "Frequency",
          labelStyle: TextStyle(color: _primaryColor),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _frequency,
          icon: Icon(Icons.arrow_drop_down, color: _primaryColor),
          items: ["Daily", "Weekly", "Custom"].map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value, style: TextStyle(fontSize: 16)),
            );
          }).toList(),
          onChanged: (val) => setState(() => _frequency = val!),
        ),
      ),
    );
  }

  Widget _buildWeeklySelector() {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Wrap(
      spacing: 8,
      children: days.map((day) {
        final isSelected = _selectedWeeklyDay.contains(day);
        return ChoiceChip(
          label: Text(day),
          selected: isSelected,
          onSelected: (_) => setState(() => _selectedWeeklyDay = day),
          selectedColor: _primaryColor,
          labelStyle:
              TextStyle(color: isSelected ? Colors.white : _primaryColor),
          backgroundColor: Colors.white,
          shape: StadiumBorder(
              side: BorderSide(color: _primaryColor.withOpacity(0.3))),
        );
      }).toList(),
    );
  }

  Widget _buildCustomDaysSelector() {
    return Wrap(
      spacing: 8,
      children: _selectedCustomDays.keys.map((day) {
        return FilterChip(
          label: Text(day),
          selected: _selectedCustomDays[day]!,
          onSelected: (val) => setState(() => _selectedCustomDays[day] = val),
          selectedColor: _primaryColor,
          checkmarkColor: Colors.white,
          labelStyle: TextStyle(
              color: _selectedCustomDays[day]! ? Colors.white : _primaryColor),
          backgroundColor: Colors.white,
          shape: StadiumBorder(
              side: BorderSide(color: _primaryColor.withOpacity(0.3))),
        );
      }).toList(),
    );
  }

  Widget _buildIconInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[600]),
        filled: true,
        fillColor: Colors.white,
        prefixIcon: Icon(icon, color: _primaryColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: EdgeInsets.symmetric(vertical: 15),
      ),
      keyboardType: keyboardType,
      validator: validator,
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _submitReminder,
      style: ElevatedButton.styleFrom(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 3,
        shadowColor: _primaryColor.withOpacity(0.3),
      ),
      child: Text("SET REMINDER",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }

  // Add this method to your class
  Future<bool> _requestExactAlarmPermission() async {
    if (Platform.isAndroid) {
      final androidPlugin =
          flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      // Check if we need this permission (Android 12+)
      if (androidPlugin != null) {
        try {
          final bool? granted =
              await androidPlugin.requestExactAlarmsPermission();
          return granted ?? false;
        } catch (e) {
          debugPrint('Error requesting exact alarms permission: $e');
          return false;
        }
      }
    }
    return true; // For iOS or when plugin is null
  }

  // Add this method to open notification settings
  void _openNotificationSettings() {
    if (Platform.isAndroid) {
      // Use your actual application ID from android/app/build.gradle
      final String packageName =
          'com.ocucare.oculoo02'; // Update this to match your actual applicationId

      try {
        // For Android
        AndroidIntent intent = AndroidIntent(
          action: 'android.settings.APP_NOTIFICATION_SETTINGS',
          arguments: <String, dynamic>{
            'android.provider.extra.APP_PACKAGE': packageName,
          },
        );
        intent.launch();
        debugPrint('Opening notification settings for $packageName');
      } catch (e) {
        debugPrint('Could not open notification settings: $e');

        // Fallback to app details settings
        try {
          AndroidIntent appSettingsIntent = AndroidIntent(
            action: 'android.settings.APPLICATION_DETAILS_SETTINGS',
            data: 'package:$packageName',
          );
          appSettingsIntent.launch();
          debugPrint('Opening app settings for $packageName');
        } catch (e) {
          debugPrint('Could not open app settings: $e');
        }
      }
    } else if (Platform.isIOS) {
      // For iOS, opening settings requires a system dialog
      debugPrint('iOS users need to open settings manually');
    }
  }

  // Add a widget to display upcoming notifications for debug purposes
  Widget _buildUpcomingNotificationsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Upcoming Notifications",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: _primaryColor,
              ),
            ),
            SizedBox(height: 10),
            ..._upcomingNotifications.map((notification) {
              final DateTime scheduledTime =
                  notification['scheduledTime'] as DateTime;
              final difference = scheduledTime.difference(DateTime.now());

              // Show in different color if in the past
              final bool isInPast = difference.isNegative;

              return ListTile(
                leading: Icon(
                  isInPast
                      ? Icons.notification_important
                      : Icons.notifications_active,
                  color: isInPast ? Colors.red : _primaryColor,
                ),
                title: Text(notification['title'] as String),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(notification['body'] as String),
                    _buildCountdownTimer(scheduledTime),
                  ],
                ),
                dense: true,
              );
            }).toList(),
            Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Having issues?",
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
                TextButton.icon(
                  icon: Icon(Icons.settings),
                  label: Text("Open Settings"),
                  onPressed: _openNotificationSettings,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Build a countdown timer widget for notifications
  Widget _buildCountdownTimer(DateTime scheduledTime) {
    return StreamBuilder(
        stream: Stream.periodic(Duration(seconds: 1)),
        builder: (context, snapshot) {
          final now = DateTime.now();
          final difference = scheduledTime.difference(now);

          String timeText;
          Color timeColor;

          if (difference.isNegative) {
            // Notification time has passed
            final overdue = difference.abs();
            if (overdue.inDays > 0) {
              timeText = "Overdue by ${overdue.inDays} days";
            } else if (overdue.inHours > 0) {
              timeText = "Overdue by ${overdue.inHours} hours";
            } else if (overdue.inMinutes > 0) {
              timeText = "Overdue by ${overdue.inMinutes} minutes";
            } else {
              timeText = "Overdue by ${overdue.inSeconds} seconds";
            }
            timeColor = Colors.red;
          } else {
            // Notification is upcoming
            if (difference.inDays > 0) {
              timeText = "In ${difference.inDays} days";
            } else if (difference.inHours > 0) {
              timeText =
                  "In ${difference.inHours} hours, ${difference.inMinutes % 60} min";
            } else if (difference.inMinutes > 0) {
              timeText =
                  "In ${difference.inMinutes} min, ${difference.inSeconds % 60} sec";
            } else {
              timeText = "In ${difference.inSeconds} seconds";
            }
            timeColor = difference.inMinutes < 5 ? Colors.orange : Colors.green;
          }

          return Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              timeText,
              style: TextStyle(
                color: timeColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        });
  }
}

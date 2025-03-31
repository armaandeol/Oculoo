import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:oculoo02/presentation/widgets/bottom_nav_bar.dart';
import 'package:oculoo02/core/configs/theme/app_color.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:oculoo02/Patient/pages/add_medications.dart';
// Timezone packages for scheduled notifications.
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool isMedicationScheduledOnDate(Map<String, dynamic> med, DateTime date) {
    try {
      final startDate =
          DateFormat('yyyy-MM-dd').parse(med['startDate'] as String);
      final endDate = DateFormat('yyyy-MM-dd').parse(med['endDate'] as String);

      if (date.isBefore(startDate) || date.isAfter(endDate)) {
        return false;
      }
    } catch (e) {
      print('Error parsing dates: $e');
      return false;
    }

    final frequency = med['frequency'] as String? ?? 'Daily';
    final days = med['days'] as List<dynamic>? ?? [];

    if (frequency == 'Daily') {
      return true;
    }

    if (frequency == 'Weekly' || frequency == 'Custom') {
      final dayName = DateFormat('EEEE').format(date);
      return days.contains(dayName);
    }

    return false;
  }

  final int initialDays = 14;
  late DateTime _startDate;
  DateTime? _selectedDate;
  final ScrollController _dateScrollController = ScrollController();

  // Instance of the notifications plugin.
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  // Flag to avoid showing notifications for logs already present on first load.
  bool _isInitialLogLoad = true;

  @override
  void initState() {
    super.initState();
    // Initialize timezone data
    tz.initializeTimeZones();

    // For testing with sample data.
    _startDate = DateTime.now(); // Changed from DateTime(2025, 2, 15)
    _selectedDate = _startDate;
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());

    // Initialize notifications.
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    initializeNotifications();

    // Debug print to verify scheduling.
    print("Scheduling test notification in 15 seconds...");
    // Schedule a test notification after 15 seconds.
    Future.delayed(const Duration(seconds: 15), () {
      print("Showing test notification now");
      showSimpleNotification();
    });

    // Listen for changes in the Logs collection and show a notification for every new log.
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    FirebaseFirestore.instance
        .collection('patient')
        .doc(uid)
        .collection('Logs')
        .snapshots()
        .listen((snapshot) {
      // Skip the initial snapshot containing all existing documents.
      if (_isInitialLogLoad) {
        _isInitialLogLoad = false;
        return;
      }
      // Loop through the document changes.
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final log = change.doc.data() as Map<String, dynamic>;
          showLogNotification(log);
        }
      }
    });
  }

  // Initialize notifications for both Android and iOS.
  Future<void> initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        // Handle notification tap
        print("Notification tapped: ${details.payload}");
      },
    );

    // On iOS, explicitly request permissions.
    if (Platform.isIOS) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    }

    // Create notification channels for Android (required for Android 8.0+).
    if (Platform.isAndroid) {
      // Channel for medication reminders.
      const AndroidNotificationChannel medicationChannel =
          AndroidNotificationChannel(
        'medication_reminders',
        'Medication Reminders',
        description: 'Channel for medication reminders',
        importance: Importance.max,
        enableVibration: true,
        playSound: true,
      );

      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(medicationChannel);

      // Channel for log notifications.
      const AndroidNotificationChannel logChannel = AndroidNotificationChannel(
        'log_notifications',
        'Log Notifications',
        description: 'Notifications for medication logs',
        importance: Importance.max,
        enableVibration: true,
        playSound: true,
      );

      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(logChannel);
    }
  }

  // Function to show a simple test notification.
  Future<void> showSimpleNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'your_channel_id', // Must match the channel created above.
      'your_channel_name',
      channelDescription: 'Your channel description',
      importance: Importance.max,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iosNotificationDetails =
        DarwinNotificationDetails(
      presentAlert:
          true, // Forces the notification to display even when the app is in foreground.
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iosNotificationDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      0,
      'Test Notification',
      'This is a test notification after 15 seconds.',
      platformChannelSpecifics,
    );
  }

  // Function to show a notification when a new log is added.
  Future<void> showLogNotification(Map<String, dynamic> log) async {
    final bool isCorrect = log['verification_result'] ?? false;
    final String title = isCorrect ? 'Correct Medication' : 'Wrong Medication';
    final String body = isCorrect
        ? 'Medicine detected correctly. Please go ahead and take your medicine.'
        : 'Wrong medicine detected! Please make sure you have the correct one.';

    // Use a unique notification ID. Here we use the current time in milliseconds.
    int notificationId =
        DateTime.now().millisecondsSinceEpoch.remainder(100000);

    await flutterLocalNotificationsPlugin.show(
      notificationId,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'log_notifications',
          'Log Notifications',
          channelDescription: 'Notifications for medication logs',
          importance: Importance.max,
          priority: Priority.high,
          color: isCorrect ? Colors.green : Colors.red,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  // Schedules a medication reminder notification using the computed scheduled time.
  Future<void> scheduleMedicationNotification({
    required int notificationId,
    required DateTime scheduledTime,
    required String medicineName,
    required String dosage,
  }) async {
    final tz.TZDateTime scheduledDate =
        tz.TZDateTime.from(scheduledTime, tz.local);

    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        notificationId,
        'Medication Reminder',
        'Time to take $dosage of $medicineName',
        scheduledDate,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'medication_reminders',
            'Medication Reminders',
            channelDescription: 'Channel for medication reminders',
            importance: Importance.max,
            priority: Priority.high,
            enableVibration: true,
            playSound: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );

      print(
          'Scheduled notification for $medicineName at ${scheduledDate.toString()}');
    } catch (e) {
      print('Error scheduling notification: $e');
    }
  }

  void _scrollToSelected() {
    final index = _selectedDate!.difference(_startDate).inDays;
    final screenWidth = MediaQuery.of(context).size.width;
    final itemWidth = screenWidth * 0.22;
    final offset = (itemWidth * index) - (screenWidth / 2 - itemWidth / 2);
    _dateScrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<DateTime> _generateDates() =>
      List.generate(initialDays, (i) => _startDate.add(Duration(days: i)));

  /// Returns a color based on the medication frequency.
  Color _getCardColor(String frequency) {
    switch (frequency) {
      case "Daily":
        return Colors.blue.shade50;
      case "Weekly":
        return Colors.green.shade50;
      case "Custom":
        return Colors.orange.shade50;
      default:
        return Colors.grey.shade100;
    }
  }

  /// Formats days list into a readable sentence
  String _formatScheduledDays(List<dynamic> days) {
    if (days.isEmpty) return "No specific days scheduled";
    if (days.length == 7) return "Scheduled every day";

    return "Scheduled for ${days.join(', ')}";
  }

  /// Formats a list of time strings to AM/PM format
  String _formatTimeList(List<dynamic> times) {
    List<String> formattedTimes = [];

    for (var time in times) {
      try {
        List<String> parts = (time as String).split(":");
        int hour = int.parse(parts[0]);
        int minute = int.parse(parts[1]);

        // Create a DateTime object to utilize DateFormat
        final timeObj = DateTime(2023, 1, 1, hour, minute);
        formattedTimes.add(DateFormat('h:mm a').format(timeObj));
      } catch (e) {
        formattedTimes.add(time.toString());
      }
    }

    return "Scheduled at: ${formattedTimes.join(', ')}";
  }

  /// Computes the next scheduled time for a medication on the selected day.
  DateTime? computeNextScheduledTime(
      Map<String, dynamic> med, DateTime selectedDate) {
    List<dynamic> timesList = med['times'] as List<dynamic>? ?? [];
    List<DateTime> scheduledTimes = [];
    for (var t in timesList) {
      try {
        List<String> parts = (t as String).split(":");
        int hour = int.parse(parts[0]);
        int minute = int.parse(parts[1]);
        DateTime dt = DateTime(selectedDate.year, selectedDate.month,
            selectedDate.day, hour, minute);
        scheduledTimes.add(dt);
      } catch (e) {
        continue;
      }
    }
    if (scheduledTimes.isEmpty) return null;
    scheduledTimes.sort((a, b) => a.compareTo(b));
    if (isSameDay(selectedDate, DateTime.now())) {
      DateTime now = DateTime.now();
      for (var dt in scheduledTimes) {
        if (dt.isAfter(now)) return dt;
      }
      return scheduledTimes.first;
    } else {
      return scheduledTimes.first;
    }
  }

  /// Formats a Duration as "X hrs Y mins".
  String formatDuration(Duration d) {
    int hours = d.inHours;
    int minutes = d.inMinutes.remainder(60);
    String hr = hours > 0 ? "$hours hrs " : "";
    String min = minutes > 0 ? "$minutes mins" : "";
    return (hr + min).trim();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? '';
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColor.background,
      bottomNavigationBar: const BottomNavBarCustome(),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColor.primary,
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (context) => PillReminderPage())),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: size.width * 0.04,
              vertical: size.height * 0.02,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(size),
                SizedBox(height: size.height * 0.02),
                _buildDateSelector(size),
                SizedBox(height: size.height * 0.03),
                _buildMedicationSection(uid, size),
                SizedBox(height: size.height * 0.03),
                _buildLogSection(uid, size),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Size size) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          child: Text(
            getGreeting(),
            key: ValueKey(getGreeting()),
            style: TextStyle(
              fontSize: size.width * 0.06,
              fontWeight: FontWeight.bold,
              color: AppColor.primary,
            ),
          ),
        ),
        StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('patient')
              .doc(FirebaseAuth.instance.currentUser?.uid)
              .snapshots(),
          builder: (context, snapshot) {
            final name = snapshot.data?.get('name') ?? 'User';
            return FadeIn(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: size.width * 0.055,
                  fontWeight: FontWeight.w600,
                  color: AppColor.primary,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDateSelector(Size size) {
    return SizedBox(
      height: size.height * 0.12,
      child: ListView.builder(
        controller: _dateScrollController,
        scrollDirection: Axis.horizontal,
        itemCount: initialDays,
        itemBuilder: (ctx, i) {
          final date = _startDate.add(Duration(days: i));
          final isSelected = isSameDay(date, _selectedDate!);
          return GestureDetector(
            onTap: () => setState(() {
              _selectedDate = date;
              _scrollToSelected();
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: size.width * 0.22,
              margin: EdgeInsets.symmetric(horizontal: size.width * 0.015),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? LinearGradient(
                        colors: [AppColor.primary, Colors.blue.shade400])
                    : LinearGradient(
                        colors: [Colors.grey.shade200, Colors.grey.shade100]),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: isSelected
                        ? AppColor.primary.withOpacity(0.3)
                        : Colors.grey.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat.E().format(date),
                    style: TextStyle(
                      fontSize: size.width * 0.035,
                      color: isSelected ? Colors.white : Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: size.height * 0.005),
                  Text(
                    DateFormat.d().format(date),
                    style: TextStyle(
                      fontSize: size.width * 0.045,
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMedicationSection(String uid, Size size) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Medication Reminders', size),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('patient')
              .doc(uid)
              .collection('Medications')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data?.docs ?? [];
            final filteredDocs = docs.where((doc) {
              final med = doc.data() as Map<String, dynamic>;
              return isMedicationScheduledOnDate(med, _selectedDate!);
            }).toList();

            if (filteredDocs.isEmpty) {
              return Padding(
                padding: EdgeInsets.symmetric(vertical: size.height * 0.02),
                child: Center(child: Text('No medications for selected date')),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredDocs.length,
              itemBuilder: (ctx, i) {
                final med = filteredDocs[i].data() as Map<String, dynamic>;
                final String docId = filteredDocs[i].id;
                final nextTime =
                    computeNextScheduledTime(med, _selectedDate!) ??
                        DateTime(_selectedDate!.year, _selectedDate!.month,
                            _selectedDate!.day, 0, 0);
                return Dismissible(
                  key: Key(docId),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: EdgeInsets.only(right: size.width * 0.05),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) async {
                    await docs[i].reference.delete();
                  },
                  child: _buildMedicationItem(
                      med, nextTime, docId, size), // Pass docId here
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildMedicationItem(
      Map<String, dynamic> med, DateTime nextTime, String docId, Size size) {
    if (!isMedicationScheduledOnDate(med, _selectedDate!)) {
      return SizedBox.shrink(); // Don't render if not scheduled
    }

    // Time info formatting
    String timeInfo = "";
    bool isToday = isSameDay(_selectedDate!, DateTime.now());
    if (isToday) {
      DateTime now = DateTime.now();
      if (nextTime.isAfter(now)) {
        Duration diff = nextTime.difference(now);
        // If less than 1 hour, show minutes
        if (diff.inHours < 1) {
          timeInfo = "Next in ${diff.inMinutes} mins";
        } else {
          timeInfo = "Next at ${DateFormat('h:mm a').format(nextTime)}";
        }
      } else {
        timeInfo = "Next at ${DateFormat('h:mm a').format(nextTime)}";
      }
    } else {
      timeInfo = "Next at ${DateFormat('h:mm a').format(nextTime)}";
    }

    Color cardColor = _getCardColor(med['frequency'] as String? ?? "Daily");
    String dosageText = "${med['dosage']}${med['unit']}";

    return FadeIn(
      child: Card(
        color: cardColor,
        elevation: 5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        margin: EdgeInsets.symmetric(
            vertical: size.height * 0.008, horizontal: size.width * 0.02),
        child: ExpansionTile(
          leading: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.shade200,
                    blurRadius: 5,
                    offset: Offset(0, 2),
                  )
                ]),
            child: Icon(
              Icons.medication,
              color: Colors.blue.shade800,
              size: 30,
            ),
          ),
          title: Text(
            med['pillName'] ?? 'Unknown Medicine',
            style: TextStyle(
              fontSize: size.width * 0.045,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                timeInfo,
                style: TextStyle(
                  fontSize: size.width * 0.035,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Row(
                children: [
                  Text(
                    dosageText,
                    style: TextStyle(
                      fontSize: size.width * 0.04,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // "Mark as Taken" button
              IconButton(
                icon: Icon(Icons.check_circle, color: Colors.green),
                onPressed: () async {
                  int notificationId = med['createdAt'].toString().hashCode;
                  await flutterLocalNotificationsPlugin.cancel(notificationId);

                  // Schedule the next reminder (if any) based on computed time
                  DateTime? nextDose =
                      computeNextScheduledTime(med, _selectedDate!);
                  if (nextDose != null && nextDose.isAfter(DateTime.now())) {
                    await scheduleMedicationNotification(
                      notificationId: notificationId,
                      scheduledTime: nextDose,
                      medicineName: med['pillName'] ?? 'Medicine',
                      dosage: '${med['dosage']}${med['unit']}',
                    );
                  }
                },
              ),
              // Delete button
              IconButton(
                icon: Icon(Icons.delete, color: Colors.red),
                onPressed: () async {
                  try {
                    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
                    await FirebaseFirestore.instance
                        .collection('patient')
                        .doc(uid)
                        .collection('Medications')
                        .doc(docId)
                        .delete();

                    int notificationId =
                        med['createdAt']?.toString().hashCode ??
                            DateTime.now().millisecondsSinceEpoch;
                    await flutterLocalNotificationsPlugin
                        .cancel(notificationId);
                  } catch (e) {
                    print('Error deleting medication: $e');

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error deleting medication: $e')),
                    );
                  }
                },
              ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Format days in a more readable way
                  Text(
                    _formatScheduledDays(med['days'] as List<dynamic>? ?? []),
                    style: TextStyle(
                      fontSize: size.width * 0.04,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  SizedBox(height: 8),
                  // Format times in AM/PM style
                  Text(
                    _formatTimeList(med['times'] as List<dynamic>? ?? []),
                    style: TextStyle(
                      fontSize: size.width * 0.04,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogSection(String uid, Size size) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Medicine Logs', size),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('patient')
              .doc(uid)
              .collection('Logs')
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return const Center(child: Text('Error loading logs'));
            }

            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return Padding(
                padding: EdgeInsets.symmetric(vertical: size.height * 0.02),
                child: const Center(child: Text('No logs available')),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              itemBuilder: (ctx, i) {
                final log = docs[i].data() as Map<String, dynamic>;
                final isCorrect = log['verification_result'] ?? false;
                final detectedPills =
                    List<String>.from(log['detected_pills'] ?? []);
                final expectedPills =
                    List<String>.from(log['expected_pills'] ?? []);
                final timestamp = DateTime.parse(log['timestamp'] as String);
                final timeDiff = log['time_difference'] ?? 'N/A';
                final ocrText = log['ocr_text'] ?? '';
                final rawText = log['raw_ocr_text'] ?? '';

                return Card(
                  color: isCorrect ? Colors.green.shade50 : Colors.red.shade50,
                  margin: EdgeInsets.symmetric(
                    vertical: size.height * 0.005,
                    horizontal: size.width * 0.02,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isCorrect ? Colors.green : Colors.red,
                      width: 2,
                    ),
                  ),
                  child: ExpansionTile(
                    leading: Icon(
                      isCorrect ? Icons.check_circle : Icons.warning,
                      color: isCorrect ? Colors.green : Colors.red,
                    ),
                    title: Text(
                      detectedPills.isNotEmpty
                          ? detectedPills.join(', ')
                          : 'No Detection',
                      style: TextStyle(
                        fontSize: size.width * 0.045,
                        fontWeight: FontWeight.bold,
                        color: isCorrect
                            ? Colors.green.shade800
                            : Colors.red.shade800,
                      ),
                    ),
                    subtitle: Text(
                      DateFormat('MMM dd, yyyy - HH:mm').format(timestamp),
                      style: TextStyle(
                        fontSize: size.width * 0.035,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLogDetail(
                                'Status:', log['status'] ?? 'Unknown'),
                            _buildLogDetail('Time Difference:', timeDiff),
                            _buildLogDetail(
                                'Expected Pills:', expectedPills.join(', ')),
                            _buildLogDetail(
                                'Detected Pills:', detectedPills.join(', ')),
                            _buildLogDetail('Processed OCR:', ocrText),
                            _buildLogDetail('Raw OCR:', rawText),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildLogDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade800,
          ),
          children: [
            TextSpan(
              text: '$label ',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            TextSpan(text: value)
          ],
        ),
      ),
    );
  }

// Updated notification function
  Future<void> showVerificationLogNotification(Map<String, dynamic> log) async {
    final bool isCorrect = log['verification_result'] ?? false;
    final detected = List<String>.from(log['detected_pills'] ?? []);
    final expected = List<String>.from(log['expected_pills'] ?? []);

    final title = isCorrect ? 'Correct Medication' : 'Wrong Medication!';
    final body = isCorrect
        ? 'You took ${detected.join(', ')} correctly'
        : _buildNotificationMessage(detected, expected);

    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'log_notifications',
          'Log Notifications',
          channelDescription: 'Notifications for medication logs',
          importance: Importance.max,
          priority: Priority.high,
          color: isCorrect ? Colors.green : Colors.red,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  String _buildNotificationMessage(
      List<String> detected, List<String> expected) {
    final extraPills =
        detected.where((pill) => !expected.contains(pill)).toList();
    final missingPills =
        expected.where((pill) => !detected.contains(pill)).toList();

    final buffer = StringBuffer();
    if (extraPills.isNotEmpty) {
      buffer.write('Unexpected: ${extraPills.join(', ')}. ');
    }
    if (missingPills.isNotEmpty) {
      buffer.write('Missing: ${missingPills.join(', ')}. ');
    }
    if (buffer.isEmpty) buffer.write('Medication verification failed');

    return buffer.toString();
  }

  Widget _buildSectionTitle(String title, Size size) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: size.height * 0.015),
      child: Text(
        title,
        style: TextStyle(
          fontSize: size.width * 0.055,
          fontWeight: FontWeight.bold,
          color: AppColor.primary,
        ),
      ),
    );
  }
}

class FadeIn extends StatelessWidget {
  final Widget child;

  const FadeIn({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      builder: (_, double value, Widget? child) =>
          Opacity(opacity: value, child: child),
      child: child,
    );
  }
}

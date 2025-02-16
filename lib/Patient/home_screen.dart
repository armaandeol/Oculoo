import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:oculoo02/presentation/widgets/bottom_nav_bar.dart';
import 'package:oculoo02/core/configs/theme/app_color.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// Timezone packages for scheduled notifications.
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
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
    _startDate = DateTime(2025, 2, 15);
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
    final bool isCorrect = log['is_correct'] ?? false;
    final String medicine = log['medication'] ?? 'Medicine';
    final String dosage = log['dosage'] ?? '';
    final String statusText = isCorrect ? 'correctly' : 'incorrectly';
    final String title = 'Medication Log Added';
    final String body = 'You took $dosage of $medicine $statusText.';

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
        onPressed: () => Navigator.pushNamed(context, '/add_medication'),
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
            if (docs.isEmpty) {
              return Padding(
                padding: EdgeInsets.symmetric(vertical: size.height * 0.02),
                child: Center(child: Text('No medication reminders found.')),
              );
            }
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              itemBuilder: (ctx, i) {
                final med = docs[i].data() as Map<String, dynamic>;
                final nextTime =
                    computeNextScheduledTime(med, _selectedDate!) ??
                        DateTime(_selectedDate!.year, _selectedDate!.month,
                            _selectedDate!.day, 0, 0);
                return Dismissible(
                  key: Key(docs[i].id),
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
                  child: _buildMedicationItem(med, nextTime, size),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildMedicationItem(
      Map<String, dynamic> med, DateTime nextTime, Size size) {
    bool isToday = isSameDay(_selectedDate!, DateTime.now());
    String timeInfo = "";
    if (isToday) {
      DateTime now = DateTime.now();
      if (nextTime.isAfter(now)) {
        Duration diff = nextTime.difference(now);
        timeInfo = "in ${formatDuration(diff)}";
      } else {
        timeInfo = "at ${DateFormat.Hm().format(nextTime)}";
      }
    } else {
      timeInfo = "at ${DateFormat.Hm().format(nextTime)}";
    }
    Color cardColor = _getCardColor(med['frequency'] as String? ?? "Daily");

    return FadeIn(
      child: Card(
        color: cardColor,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        margin: EdgeInsets.symmetric(
            vertical: size.height * 0.005, horizontal: size.width * 0.02),
        child: ExpansionTile(
          leading: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(25),
            ),
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
                "Next: $timeInfo",
                style: TextStyle(
                  fontSize: size.width * 0.035,
                  color: Colors.grey.shade700,
                ),
              ),
              Text(
                "Dosage: ${med['dosage']}${med['unit']}",
                style: TextStyle(fontSize: size.width * 0.035),
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // "Mark as Taken" button.
              IconButton(
                icon: Icon(Icons.check_circle, color: Colors.green),
                onPressed: () async {
                  // Create a unique notification ID (using createdAt or fallback).
                  int notificationId = med['createdAt'].toString().hashCode;
                  // Cancel any pending notification.
                  await flutterLocalNotificationsPlugin.cancel(notificationId);

                  // TODO: Update your medication log in Firestore as needed.

                  // Schedule the next reminder (if any) based on computed time.
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
              // Delete button.
              IconButton(
                icon: Icon(Icons.delete, color: Colors.red),
                onPressed: () async {
                  try {
                    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
                    // Ensure you use the document ID from your snapshot here.
                    await FirebaseFirestore.instance
                        .collection('patient')
                        .doc(uid)
                        .collection('Medications')
                        .doc(med[
                            'docId']) // You might need to pass the document ID.
                        .delete();

                    // Cancel any pending notifications
                    await flutterLocalNotificationsPlugin
                        .cancel(med['createdAt'].toString().hashCode);
                  } catch (e) {
                    print('Error deleting medication: $e');
                  }
                },
              ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Frequency: ${med['frequency']}",
                    style: TextStyle(fontSize: size.width * 0.04),
                  ),
                  if (med['frequency'] == "Weekly" ||
                      med['frequency'] == "Custom")
                    Text(
                      "Days: ${(med['days'] as List<dynamic>).join(', ')}",
                      style: TextStyle(fontSize: size.width * 0.04),
                    ),
                  Text(
                    "Scheduled Times: ${(med['times'] as List<dynamic>).join(', ')}",
                    style: TextStyle(fontSize: size.width * 0.04),
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
              .orderBy('taken_at', descending: true)
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
                final isCorrect = log['is_correct'] ?? false;

                return _buildLogCard(
                  context: context,
                  medicine: log['medication'] ?? 'Unknown Medicine',
                  status: log['status'] ?? 'No status',
                  time: log['taken_at'] ?? 'No time',
                  isCorrect: isCorrect,
                  timeDifference: log['time_difference'] ?? '',
                  dosage: log['dosage'] ?? '',
                  size: size,
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildLogCard({
    required BuildContext context,
    required String medicine,
    required String status,
    required String time,
    required bool isCorrect,
    required String dosage,
    required Size size,
    required String timeDifference,
  }) {
    return Card(
      color: isCorrect ? Colors.green.shade50 : Colors.red.shade50,
      margin: EdgeInsets.symmetric(
        vertical: size.height * 0.005,
        horizontal: size.width * 0.02,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isCorrect ? Colors.green.shade100 : Colors.red.shade100,
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Icon(
              isCorrect ? Icons.check_circle : Icons.error,
              color: isCorrect ? Colors.green : Colors.red,
              size: 32,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        medicine,
                        style: TextStyle(
                          fontSize: size.width * 0.045,
                          fontWeight: FontWeight.bold,
                          color: isCorrect
                              ? Colors.green.shade800
                              : Colors.red.shade800,
                          decoration:
                              !isCorrect ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      Text(
                        DateFormat('HH:mm').format(DateTime.parse(time)),
                        style: TextStyle(
                          fontSize: size.width * 0.035,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Status: $status',
                    style: TextStyle(
                      fontSize: size.width * 0.035,
                      color: isCorrect
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                    ),
                  ),
                  if (timeDifference.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        'Time Difference: $timeDifference',
                        style: TextStyle(
                          fontSize: size.width * 0.035,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  if (dosage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        'Dosage: $dosage',
                        style: TextStyle(
                          fontSize: size.width * 0.035,
                          color: Colors.grey.shade700,
                        ),
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

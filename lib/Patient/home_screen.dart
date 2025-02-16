import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:oculoo02/presentation/widgets/bottom_nav_bar.dart';
import 'package:oculoo02/core/configs/theme/app_color.dart';
import 'package:intl/intl.dart';

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

  @override
  void initState() {
    super.initState();
    // For testing with sample data, set _startDate to a date in the medication's range.
    // e.g., if your sample med starts on "2025-02-15", then:
    _startDate = DateTime(2025, 2, 15);
    _selectedDate = _startDate;
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
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
    // If the selected day is today, pick the first time after now (if any)
    if (isSameDay(selectedDate, DateTime.now())) {
      DateTime now = DateTime.now();
      for (var dt in scheduledTimes) {
        if (dt.isAfter(now)) return dt;
      }
      // If all times are past, return the earliest (for display purposes)
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

  /// Medication Section with redesigned cards.
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
            // For simplicity, we won’t re-sort the medications here.
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

  /// Redesigned, expandable medication card.
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
              // Mark as Taken button
              IconButton(
                icon: Icon(Icons.check_circle, color: Colors.green),
                onPressed: () {
                  // TODO: Implement "mark as taken" functionality.
                },
              ),
              // Delete button (optional redundancy, since swipe also deletes)
              IconButton(
                icon: Icon(Icons.delete, color: Colors.red),
                onPressed: () async {
                  // Delete the medication reminder.
                  // (You might want to confirm with the user before deletion.)
                  // For now, we directly delete:
                  // Find the document and delete:
                  final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
                  // Note: In a real scenario, consider passing the document reference.
                  await FirebaseFirestore.instance
                      .collection('patient')
                      .doc(uid)
                      .collection('Medications')
                      .doc(med['createdAt']
                          .toString()) // or another unique field/document id
                      .delete();
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
                  // Add additional details here if desired.
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

// ... Keep all imports and other code above the same ...

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
                      // Added time display
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
                  if (timeDifference != null) // Added time difference display
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

// ... Keep the rest of the code below the same ...

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

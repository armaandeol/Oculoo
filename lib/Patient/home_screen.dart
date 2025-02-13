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
    // For testing, you can set this to a date that matches your dummy data.
    _startDate = DateTime.now();
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

  /// Medications Section that now filters based on the selected date.
  Widget _buildMedicationSection(String uid, Size size) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Medications Reminders', size),
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
            final selectedDate = _selectedDate ?? DateTime.now();

            // Updated filtering logic:
            final filteredDocs = docs.where((doc) {
              final med = doc.data() as Map<String, dynamic>;
              final frequency = med['frequency'];
              // For Daily reminders, check date range only.
              if (frequency == "Daily") {
                try {
                  final medStart = DateTime.parse(med['start_date']);
                  final medEnd = DateTime.parse(med['end_date']);
                  return !selectedDate.isBefore(medStart) &&
                      !selectedDate.isAfter(medEnd);
                } catch (e) {
                  return false;
                }
              } else {
                // For Weekly and Custom, first check the date range.
                try {
                  final medStart = DateTime.parse(med['start_date']);
                  final medEnd = DateTime.parse(med['end_date']);
                  if (selectedDate.isBefore(medStart) ||
                      selectedDate.isAfter(medEnd)) {
                    return false;
                  }
                } catch (e) {
                  return false;
                }
                if (frequency == "Weekly") {
                  final selectedFullDay =
                      DateFormat('EEEE').format(selectedDate);
                  final List days = med['days'];
                  return days.contains(selectedFullDay);
                } else if (frequency == "Custom") {
                  final selectedAbbrDay = DateFormat('E').format(selectedDate);
                  final List days = med['days'];
                  return days.contains(selectedAbbrDay);
                }
              }
              return false;
            }).toList();

            if (filteredDocs.isEmpty) {
              return Padding(
                padding: EdgeInsets.symmetric(vertical: size.height * 0.02),
                child: Text(
                  "No medications scheduled for this day.",
                  style: TextStyle(fontSize: size.width * 0.045),
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredDocs.length,
              itemBuilder: (ctx, i) {
                final med = filteredDocs[i].data() as Map<String, dynamic>;
                return Dismissible(
                  key: Key(filteredDocs[i].id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: EdgeInsets.only(right: size.width * 0.05),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) => filteredDocs[i].reference.delete(),
                  child: _buildMedicationItem(med, size),
                );
              },
            );
          },
        ),
      ],
    );
  }

  /// Minimalistic medication card displaying Pill Name, Time(s), and Unit.
  Widget _buildMedicationItem(Map<String, dynamic> med, Size size) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: size.height * 0.005),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: size.width * 0.04,
          vertical: size.height * 0.01,
        ),
        title: Text(
          med['pillName'] ?? 'Unknown Pill',
          style: TextStyle(
            fontSize: size.width * 0.045,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Time: ${(med['times'] as List).join(', ')}",
              style: TextStyle(fontSize: size.width * 0.035),
            ),
            Text(
              "Unit: ${med['unit']}",
              style: TextStyle(fontSize: size.width * 0.035),
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
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snapshot.data?.docs ?? [];
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              itemBuilder: (ctx, i) {
                final log = docs[i].data() as Map<String, dynamic>;
                return Dismissible(
                  key: Key(docs[i].id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: EdgeInsets.only(right: size.width * 0.05),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) => docs[i].reference.delete(),
                  child: _buildLogItem(log, size),
                );
              },
            );
          },
        ),
      ],
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

  Widget _buildLogItem(Map<String, dynamic> log, Size size) {
    final summary = log['summary'] as List<dynamic>? ?? [];
    String medicine = 'Unknown Medicine';
    String dosage = 'Unknown Dosage';
    String unit = '';
    String time = 'Unknown Time';
    String date = 'Unknown Date';

    if (summary.isNotEmpty) {
      medicine = summary[0]['text'] ?? 'Unknown Medicine';
      if (summary.length > 1) dosage = summary[1]['text'] ?? 'Unknown Dosage';
      if (summary.length > 2) unit = summary[2]['text'] ?? '';
      if (summary.length > 3) time = summary[3]['text'] ?? 'Unknown Time';
      if (summary.length > 4) date = summary[4]['text'] ?? 'Unknown Date';
    }

    return Container(
      margin: EdgeInsets.symmetric(vertical: size.height * 0.005),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade100, Colors.green.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: size.width * 0.04,
          vertical: size.height * 0.01,
        ),
        title: Text(
          medicine,
          style: TextStyle(
            fontSize: size.width * 0.045,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          "$dosage$unit\n"
          "$time • $date",
          style: TextStyle(fontSize: size.width * 0.035),
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

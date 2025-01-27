import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:oculoo02/presentation/widgets/bottom_nav_bar.dart'; // Ensure correct import path
import 'package:oculoo02/core/configs/theme/app_color.dart';
import 'package:intl/intl.dart'; // For date formatting

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final int numberOfDays = 12; // Display next 12 dates
  late DateTime _startDate;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _startDate = DateTime.now();
    _selectedDate = _startDate;
  }

  String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 17) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  List<DateTime> _generateDates() {
    return List.generate(
      numberOfDays,
      (index) => _startDate.add(Duration(days: index)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final uid = currentUser?.uid ?? '';
    final height = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: AppColor.background,
      bottomNavigationBar: const BottomNavBarCustome(),
      body: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          margin: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColor.background,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: height * 0.065),

              // Greeting Text with Animation
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                child: Text(
                  getGreeting(),
                  key: ValueKey<String>(getGreeting()),
                  style: const TextStyle(
                    fontSize: 24,
                    color: AppColor.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(height: height * 0.01),

              // User's Name with Fade Animation
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('patient')
                    .doc(uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  }
                  if (snapshot.hasError) {
                    return const Text(
                      'Error fetching user data',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColor.primary,
                      ),
                    );
                  }
                  if (!snapshot.hasData || !snapshot.data!.exists) {
                    return const Text(
                      'No user data found',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColor.primary,
                      ),
                    );
                  }

                  final userData = snapshot.data!.data() as Map<String, dynamic>;
                  final userName = userData['name'] ?? 'User';

                  return FadeIn(
                    child: Text(
                      userName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColor.primary,
                      ),
                    ),
                  );
                },
              ),
              SizedBox(height: height * 0.02),

              // Horizontally Scrollable Date Row with Gradient and Shadows
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: numberOfDays,
                  itemBuilder: (context, index) {
                    final date = _startDate.add(Duration(days: index));
                    final dayName = DateFormat.E().format(date);
                    final dayNumber = DateFormat.d().format(date);
                    final isSelected = _selectedDate != null && isSameDay(date, _selectedDate!);

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedDate = date;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 70,
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: isSelected
                              ? LinearGradient(
                                  colors: [AppColor.primary, Colors.blueAccent],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : LinearGradient(
                                  colors: [Colors.grey.withOpacity(0.3), Colors.grey.withOpacity(0.1)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: isSelected ? AppColor.primary.withOpacity(0.5) : Colors.grey.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              dayName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? Colors.white : Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              dayNumber,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: height * 0.02),

              // Medications Reminders Section
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                ),
                child: const Text(
                  "Medications Reminders",
                  style: TextStyle(
                    fontSize: 24, // Increased font size
                    fontWeight: FontWeight.bold,
                    color: AppColor.primary,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('patient')
                    .doc(uid)
                    .collection('Medications')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  }
                  if (snapshot.hasError) {
                    return const Text(
                      'Error fetching medications',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.red,
                      ),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Text(
                      'No medication reminders found.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                    );
                  }

                  final medications = snapshot.data!.docs;

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: medications.length,
                    itemBuilder: (context, index) {
                      final med = medications[index].data() as Map<String, dynamic>;
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blue.shade100, Colors.blue.shade50],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ListTile(
                          title: Text(
                            med['medicine'] ?? 'Unnamed Medicine',
                            style: const TextStyle(
                              fontSize: 18, // Increased font size
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            "Dosage: ${med['dosage']} ${med['unit']}\n"
                            "Times: ${med['times'].join(', ')}\n"
                            "Frequency: ${med['frequency']}\n"
                            "Days: ${med['days']}",
                            style: const TextStyle(
                              fontSize: 16, // Increased font size
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              // Optionally implement delete functionality
                            },
                          ),
                        ),
                      );
                    },
                  );
                },
              ),

              // Medicine Logs Section
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                ),
                child: const Text(
                  "Medicine Logs",
                  style: TextStyle(
                    fontSize: 24, // Increased font size
                    fontWeight: FontWeight.bold,
                    color: AppColor.primary,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('patient')
                    .doc(uid)
                    .collection('Logs')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  }
                  if (snapshot.hasError) {
                    return const Text(
                      'Error fetching logs',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.red,
                      ),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Text(
                      'No logs found.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                    );
                  }

                  final logs = snapshot.data!.docs;

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final log = logs[index].data() as Map<String, dynamic>;
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.green.shade100, Colors.green.shade50],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ListTile(
                          title: Text(
                            log['summary'] ?? 'No Summary',
                            style: const TextStyle(
                              fontSize: 18, // Increased font size
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            "Medicine: ${log['medicine']}\n"
                            "Dosage: ${log['dosage']} ${log['unit']}\n"
                            "Time: ${log['time']}\n"
                            "Date: ${log['date']}",
                            style: const TextStyle(
                              fontSize: 16, // Increased font size
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// FadeIn Animation Widget
class FadeIn extends StatelessWidget {
  final Widget child;

  const FadeIn({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      builder: (context, double value, child) {
        return Opacity(
          opacity: value,
          child: child,
        );
      },
      child: child,
    );
  }
}
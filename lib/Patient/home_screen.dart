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
  // Number of dates to display in the scrollable row
  final int numberOfDays = 12; // Display next 12 dates
  late DateTime _startDate;
  DateTime? _selectedDate; // Track the selected date

  @override
  void initState() {
    super.initState();
    _startDate = DateTime.now();
    _selectedDate = _startDate; // Automatically select today's date
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

  // Method to check if two dates are the same day
  bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  // Function to generate the list of next 12 dates
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
      backgroundColor: AppColor.background, // Use AppColor.background for the background
      bottomNavigationBar: const BottomNavBarCustome(), // Positioned at the bottom
      body: SingleChildScrollView( // Make the content scrollable
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          margin: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColor.background,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, // Align children to the start
            children: [
              SizedBox(
                height: height * 0.065,
              ),

              // Greeting Text
              Text(
                getGreeting(),
                style: const TextStyle(
                  fontSize: 24,
                  color: AppColor.primary, // Set color to AppColor.primary
                ),
              ),
              SizedBox(
                height: height * 0.01,
              ),

              // User's Name below the greeting
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

                  final userData =
                      snapshot.data!.data() as Map<String, dynamic>;
                  final userName = userData['name'] ?? 'User';

                  return Text(
                    userName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColor.primary,
                    ),
                  );
                },
              ),
              SizedBox(
                height: height * 0.02,
              ),

              // Horizontally Scrollable Date Row
              SizedBox(
                height: 80, // Adjust the height as needed
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: numberOfDays,
                  itemBuilder: (context, index) {
                    final date = _startDate.add(Duration(days: index));
                    final dayName = DateFormat.E().format(date); // Mon, Tue, etc.
                    final dayNumber = DateFormat.d().format(date); // 1, 2, etc.
                    final isSelected = _selectedDate != null && isSameDay(date, _selectedDate!);

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedDate = date;
                          // Handle any additional logic for the selected date
                        });
                      },
                      child: Container(
                        width: 60, // Adjust the width as needed
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColor.primary : Colors.grey.withOpacity(0.3), // Blue for selected, grey otherwise
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              dayName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? Colors.white : Colors.black54, // White text for selected, grey for others
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              dayNumber,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : Colors.black87, // White text for selected, dark grey for others
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(
                height: height * 0.02,
              ),

              // Medications Reminders Section
              const SizedBox(height: 20),
              const Text(
                "Medications Reminders",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColor.primary,
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
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        child: ListTile(
                          title: Text(med['medicine'] ?? 'Unnamed Medicine'),
                          subtitle: Text(
                            "Dosage: ${med['dosage']} ${med['unit']}\n"
                            "Times: ${med['times'].join(', ')}\n"
                            "Frequency: ${med['frequency']}\n"
                            "Days: ${med['days']}",
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
              // Add this section under the Medications Reminders section
              const SizedBox(height: 20),
              const Text(
                "Medicine Logs",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColor.primary,
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
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        child: ListTile(
                          title: Text(log['summary'] ?? 'No Summary'),
                          subtitle: Text(
                            "Medicine: ${log['medicine']}\n"
                            "Dosage: ${log['dosage']} ${log['unit']}\n"
                            "Time: ${log['time']}\n"
                            "Date: ${log['date']}",
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              // Recent Reminders section to be handled later
              // -------------------------------------
            ],
          ),
        ),
      ),
    );
  }
}
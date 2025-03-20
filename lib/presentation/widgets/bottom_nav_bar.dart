import 'package:flutter/material.dart';
import 'package:oculoo02/Patient/pages/add_medications.dart';
import 'package:oculoo02/Patient/home_screen.dart';
import 'package:oculoo02/Patient/pages/profile_page.dart';

class BottomNavBarCustome extends StatelessWidget {
  const BottomNavBarCustome({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    return Container(
      width: width,
      height: height * 0.1,
      margin: EdgeInsets.symmetric(horizontal: width * 0.05),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(300),
      ),
      child: Row(
        children: [
          // Home Button
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => HomePage()),
                );
              },
              child: const Icon(
                Icons.home,
                color: Colors.white,
              ),
            ),
          ),
          // Add Medication Button
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PillReminderPage()),
                );
              },
              child: const Icon(
                Icons.medical_services_outlined,
                color: Colors.white,
              ),
            ),
          ),
          // Profile Button
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ProfilePage()),
                );
              },
              child: const Icon(
                Icons.account_circle_outlined,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

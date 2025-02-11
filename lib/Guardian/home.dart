import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:oculoo02/presentation/auth/sign_in.dart';

class GuardianHomePage extends StatefulWidget {
  const GuardianHomePage({Key? key}) : super(key: key);

  @override
  _GuardianHomePageState createState() => _GuardianHomePageState();
}

class _GuardianHomePageState extends State<GuardianHomePage> {
  List<String> _patientIds = [];

  @override
  void initState() {
    super.initState();
    _loadLinkedPatients();
  }

  /// Loads the linked patient UIDs from the guardian's listing subcollection.
  Future<void> _loadLinkedPatients() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("No user is logged in.");
      return;
    }
    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('guardian')
          .doc(user.uid)
          .collection('listing')
          .get();

      List<String> patientIds = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        // Expecting each document to have a 'uid' field that stores the patient's UID.
        if (data is Map<String, dynamic> && data.containsKey('uid')) {
          patientIds.add(data['uid'].toString());
        }
      }
      setState(() {
        _patientIds = patientIds;
      });
    } catch (e) {
      print("Error loading linked patients: $e");
    }
  }

  /// Builds the Patients section which displays patient names fetched from the 'patient' collection.
  Widget _buildPatientsSection(Size size) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Patients",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        _patientIds.isEmpty
            ? const Text("No patients found.")
            : Column(
                children: _patientIds
                    .map((patientId) => _buildPatientListItem(patientId, size))
                    .toList(),
              ),
      ],
    );
  }

  /// Builds a list item for a patient by fetching the patient document using the UID.
  Widget _buildPatientListItem(String patientId, Size size) {
    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance.collection('patient').doc(patientId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const ListTile(
            title: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return ListTile(
            title: Text('Error loading patient',
                style: TextStyle(color: Colors.red)),
          );
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return ListTile(
            title: Text('No patient found for UID: $patientId'),
          );
        }
        final patientData = snapshot.data!.data() as Map<String, dynamic>;
        final String patientName = patientData['name'] ?? 'Unknown Patient';
        return ListTile(
          leading: const Icon(Icons.person_outline),
          title: Text(
            patientName,
            style: TextStyle(fontSize: size.width * 0.045),
          ),
        );
      },
    );
  }

  /// Signs out the current user and navigates to the Sign In screen.
  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      print("User signed out successfully.");
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => SignIn()),
      );
    } catch (e) {
      print("Error signing out: $e");
    }
  }

  // Optionally, you can keep your other buttons (debug, add, etc.) here.
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      appBar: AppBar(title: const Text("Guardian Home Page")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Patients section that displays patient names.
            _buildPatientsSection(size),
            const SizedBox(height: 20),
            // Logout button (optional)
            ElevatedButton(
              onPressed: _logout,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text("Logout"),
            ),
          ],
        ),
      ),
    );
  }
}

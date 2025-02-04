import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:oculoo02/presentation/auth/sign_in.dart';

class GuardianHomePage extends StatelessWidget {
  const GuardianHomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      // Handle user not logged in
      return Scaffold(
        appBar: AppBar(
          title: const Text('Guardian Home'),
        ),
        body: const Center(
          child: Text(
            'User not authenticated.',
            style: TextStyle(fontSize: 18, color: Colors.red),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Guardian Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            tooltip: 'Sign Out',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              // Navigate to the sign-in screen after signing out
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => SignIn()),
              );
            },
          )
        ],
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('Guardians')
            .doc(currentUser.uid)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Guardian data not found.'));
          }

          final guardianData = snapshot.data!.data() as Map<String, dynamic>;
          final guardianName = guardianData['name'] ?? 'Guardian';

          return Center(
            child: Text(
              'Hello, $guardianName!',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          );
        },
      ),
    );
  }
}

void main() {
  runApp(const MaterialApp(
    home: GuardianHomePage(),
  ));
}

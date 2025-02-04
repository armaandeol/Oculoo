import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:oculoo02/presentation/auth/sign_in.dart';
import 'package:oculoo02/Patient/home_screen.dart';
import 'package:oculoo02/Guardian/home.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Check authentication state
        if (snapshot.connectionState == ConnectionState.active) {
          final User? user = snapshot.data;

          // If no user is signed in, show the SignIn screen.
          if (user == null) {
            return SignIn();
          } else {
            // For debugging or checking the persisted token:
            _printIdToken(user);

            // Determine the user's role from Firestore
            return FutureBuilder<String>(
              future: _getUserRole(user.uid),
              builder: (context, roleSnapshot) {
                if (roleSnapshot.connectionState == ConnectionState.done) {
                  if (roleSnapshot.hasData) {
                    switch (roleSnapshot.data) {
                      case 'patient':
                        return const HomePage();
                      case 'guardian':
                        return GuardianHomePage();
                      default:
                        return _buildErrorScreen(context);
                    }
                  }
                  return _buildErrorScreen(context);
                }
                return _buildLoadingScreen();
              },
            );
          }
        }
        return _buildLoadingScreen();
      },
    );
  }

  // Optional: Print the ID token for debugging purposes.
  Future<void> _printIdToken(User user) async {
    try {
      // This will retrieve the current ID token. Firebase will automatically refresh it if expired.
      final idToken = await user.getIdToken();
      debugPrint("User ID Token: $idToken");
    } catch (e) {
      debugPrint("Error fetching ID token: $e");
    }
  }

  Future<String> _getUserRole(String uid) async {
    // Check patient collection first.
    final patientDoc =
        await FirebaseFirestore.instance.collection('patient').doc(uid).get();

    if (patientDoc.exists) return 'patient';

    // If not in patient, check guardian collection.
    final guardianDoc =
        await FirebaseFirestore.instance.collection('guardian').doc(uid).get();

    if (guardianDoc.exists) return 'guardian';

    throw Exception('User role not found');
  }

  Widget _buildLoadingScreen() {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildErrorScreen(BuildContext context) {
    // In case of an error, sign out the user and display the SignIn screen.
    FirebaseAuth.instance.signOut();
    return SignIn();
  }
}

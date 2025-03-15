import 'package:flutter/material.dart';
import 'package:oculoo02/presentation/auth/sign_up.dart';
import 'package:oculoo02/presentation/widgets/basic_app_button.dart';
import 'package:oculoo02/core/configs/theme/app_color.dart';
import 'package:oculoo02/presentation/widgets/textfield.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:oculoo02/Patient/home_screen.dart';
import 'package:oculoo02/Guardian/home.dart';

class SignIn extends StatelessWidget {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  // Helper function to determine the user role
  Future<String> _getUserRole(String uid) async {
    // Check patient collection first
    final patientDoc =
        await FirebaseFirestore.instance.collection('patient').doc(uid).get();
    if (patientDoc.exists) return 'patient';

    // If not patient, check guardian collection
    final guardianDoc =
        await FirebaseFirestore.instance.collection('guardian').doc(uid).get();
    if (guardianDoc.exists) return 'guardian';

    return 'unknown';
  }

  // Email validation function
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  void login(BuildContext context) async {
    String email = emailController.text.trim();
    String password = passwordController.text.trim();

    // Enhanced validation
    if (email.isEmpty) {
      _showErrorMessage(context, "Email field cannot be empty");
      return;
    }

    if (!_isValidEmail(email)) {
      _showErrorMessage(context, "Please enter a valid email address");
      return;
    }

    if (password.isEmpty) {
      _showErrorMessage(context, "Password field cannot be empty");
      return;
    }

    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      if (userCredential.user != null) {
        // Get user role from Firestore
        String role = await _getUserRole(userCredential.user!.uid);

        // Remove all previous routes
        Navigator.popUntil(context, (route) => route.isFirst);

        // Redirect based on the role
        if (role == 'patient') {
          Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const HomePage()));
          print("Patient");
        } else if (role == 'guardian') {
          Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => GuardianHomePage()));
          print("Guardian");
        } else {
          // Handle unknown role
          _showErrorMessage(
              context, "User role unknown. Please contact support.");
        }
      }
    } on FirebaseAuthException catch (ex) {
      // Handle specific Firebase Auth errors
      switch (ex.code) {
        case 'user-not-found':
          _showErrorMessage(context, "No account found with this email");
          break;
        case 'wrong-password':
          _showErrorMessage(context, "Incorrect password");
          break;
        case 'invalid-email':
          _showErrorMessage(context, "Invalid email format");
          break;
        case 'user-disabled':
          _showErrorMessage(context, "This account has been disabled");
          break;
        default:
          _showErrorMessage(context, "Login failed: ${ex.message}");
      }
    } catch (e) {
      _showErrorMessage(context, "An unexpected error occurred");
    }
  }

  void _showErrorMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipOval(
              child: Image.asset(
                'assets/images/face_id2.gif',
                width: 120,
                height: 120,
                fit: BoxFit.cover,
              ),
            ),
            Textfield(lbl: "Email", controller: emailController),
            Textfield(
                lbl: "Password",
                controller: passwordController,
                icon: Icons.visibility_off,
                obscureText: true),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
              child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    "Forgot Password?",
                    style: TextStyle(color: AppColor.grey),
                  )),
            ),
            BasicAppButton(
              onPressed: () {
                login(context);
              },
              child: Text(
                "Sign In",
                style: TextStyle(color: AppColor.primary),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Don't have an account ?",
                  style: TextStyle(
                    color: AppColor.grey,
                  ),
                ),
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SignUp()),
                    );
                  },
                  child: Text(
                    "Sign Up",
                    style: TextStyle(
                        color: AppColor.secondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 16),
                  ),
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}

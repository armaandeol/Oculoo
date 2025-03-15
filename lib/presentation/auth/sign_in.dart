// sign_in.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:oculoo02/Guardian/home.dart';
import 'package:oculoo02/Patient/home_screen.dart';
import 'package:oculoo02/core/configs/theme/app_color.dart';
import 'package:oculoo02/presentation/auth/sign_up.dart';
import 'package:oculoo02/presentation/widgets/basic_app_button.dart';
import 'package:oculoo02/presentation/widgets/textfield.dart';

class SignIn extends StatefulWidget {
  const SignIn({super.key});

  @override
  State<SignIn> createState() => _SignInState();
}

class _SignInState extends State<SignIn> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _obscurePassword = true;

  Future<String> _getUserRole(String uid) async {
    final patientDoc =
        await FirebaseFirestore.instance.collection('patient').doc(uid).get();
    if (patientDoc.exists) return 'patient';
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
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      if (userCredential.user != null) {
        final role = await _getUserRole(userCredential.user!.uid);
        Navigator.popUntil(context, (route) => route.isFirst);

        if (role == 'patient') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomePage()),
          );
        } else if (role == 'guardian') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => GuardianHomePage()),
          );
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
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
              const SizedBox(height: 30),
              Textfield(
                lbl: "Email",
                controller: emailController,
              ),
              const SizedBox(height: 15),
              Textfield(
                lbl: "Password",
                controller: passwordController,
                obscureText: _obscurePassword,
                icon:
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                onIconPressed: () => setState(() {
                  _obscurePassword = !_obscurePassword;
                }),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    "Forgot Password?",
                    style: TextStyle(color: AppColor.grey),
                  ),
                ),
              ),
              const SizedBox(height: 25),
              BasicAppButton(
                onPressed: login,
                child: Text(
                  "Sign In",
                  style: TextStyle(color: AppColor.primary),
                ),
              ),
              const SizedBox(height: 25),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: TextStyle(color: AppColor.grey),
                    ),
                    InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SignUp()),
                      ),
                      child: Text(
                        "Sign Up",
                        style: TextStyle(
                          color: AppColor.secondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

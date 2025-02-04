import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:oculoo02/presentation/auth/sign_in.dart';
import 'package:oculoo02/presentation/widgets/isPatient.dart';
import 'package:oculoo02/core/configs/theme/app_color.dart';
import 'package:oculoo02/presentation/widgets/textfield.dart';
import 'package:oculoo02/Patient/home_screen.dart';
import 'package:oculoo02/Guardian/home.dart'; // Import Guardian home

class SignUp extends StatefulWidget {
  const SignUp({Key? key}) : super(key: key);

  @override
  State<SignUp> createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController cpasswordController = TextEditingController();
  bool _isGuardian = false;

  Future<void> createAccount(BuildContext context) async {
    String name = nameController.text.trim();
    String email = emailController.text.trim();
    String password = passwordController.text.trim();
    String cpassword = cpasswordController.text.trim();

    // Check for empty fields
    if (name.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        cpassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all the details")),
      );
      return;
    }

    // Check if passwords match
    if (password != cpassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords do not match")),
      );
      return;
    }

    try {
      // Create the user account via Firebase Authentication
      UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      String uid = userCredential.user!.uid;
      // Determine role based on toggle
      String role = _isGuardian ? 'guardian' : 'patient';

      // Save user details in Firestore under the appropriate collection
      await FirebaseFirestore.instance.collection(role).doc(uid).set({
        'name': name,
        'email': email,
        'role': role,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Account created successfully!")),
      );

      // Clear the navigation stack and redirect based on user role
      Navigator.popUntil(context, (route) => route.isFirst);
      if (role == 'patient') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      } else if (role == 'guardian') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => GuardianHomePage()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = "An error occurred. Please try again.";
      if (e.code == 'weak-password') {
        errorMessage = "The password provided is too weak.";
      } else if (e.code == 'email-already-in-use') {
        errorMessage = "The account already exists for that email.";
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("An unexpected error occurred: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // Logo or Image
              ClipOval(
                child: Image.asset(
                  'assets/images/face_id1.gif',
                  width: 120,
                  height: 120,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              const Text(
                "Create Account",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 20),

              // Input Fields
              Textfield(lbl: "Full Name", controller: nameController),
              const SizedBox(height: 15),
              Textfield(lbl: "Email", controller: emailController),
              const SizedBox(height: 15),
              Textfield(
                lbl: "Password",
                controller: passwordController,
                obscureText: true,
                icon: Icons.visibility_off,
              ),
              const SizedBox(height: 15),
              Textfield(
                lbl: "Confirm Password",
                controller: cpasswordController,
                obscureText: true,
                icon: Icons.visibility_off,
              ),
              const SizedBox(height: 25),
              IsGuardian(
                onChanged: (value) {
                  setState(() {
                    _isGuardian = value; // Update the toggle state
                  });
                },
              ),

              // Sign Up Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => createAccount(context),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    backgroundColor:
                        Colors.blue, // Customize button color if needed
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    "Sign Up",
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 15),

              // Already have an account? Sign In
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => SignIn()),
                  );
                },
                child: const Text(
                  "Already have an account? Sign In",
                  style: TextStyle(color: Colors.blue),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

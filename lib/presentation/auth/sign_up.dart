import 'package:flutter/material.dart';
import 'package:oculoo02/presentation/auth/sign_in.dart';
import 'package:oculoo02/presentation/widgets/basic_app_button.dart';
import 'package:oculoo02/presentation/widgets/isPatient.dart';
import 'package:oculoo02/core/configs/theme/app_color.dart';
import 'package:oculoo02/presentation/widgets/textfield.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:oculoo02/Patient/home_screen.dart';

class SignUp extends StatelessWidget {
  SignUp({Key? key}) : super(key: key);

  TextEditingController nameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController cpasswordController = TextEditingController();

  void createAccount(BuildContext context) async {
    String name = nameController.text.trim();
    String email = emailController.text.trim();
    String password = passwordController.text.trim();
    String cpassword = cpasswordController.text.trim();

    
    

    // Check empty fields
    if (name.isEmpty || email.isEmpty || password.isEmpty || cpassword.isEmpty) {
      print("Please fill in all the details");
      return;
    }

    // Check password match
    if (password != cpassword) {
      print("Password does not match");
      return;
    }

    try {
      print("Creating user...");
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      String uid = userCredential.user!.uid;
      String role = 'patient';

      print("Uploading user data to Firestore...");
      await FirebaseFirestore.instance.collection(role).doc(uid).set({
        'name': name,
        'email': email,
        'role': role,
      });

      print("User created successfully, navigating to HomePage.");
      if (userCredential.user != null) {
        // Navigate to HomePage
        Navigator.popUntil(context, (route) => route.isFirst);
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => HomePage()));
      }
    } on FirebaseAuthException catch (e) {
      // Print specific FirebaseAuthExceptions
      print("FirebaseAuthException: ${e.code}");
    } catch (e) {
      // Print unknown errors
      print("Unknown error: $e");
    }

    // Additional Steps to Verify (Outside Code):
    // 1. Check Firebase console > Project Settings > Android package name & SHA-1 fingerprint.
    // 2. Confirm Firestore rules allow reads/writes for authenticated users.
    // 3. Ensure internet connection and no proxy blocking requests.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipOval(
                child: Image.asset(
                  'assets/images/face_id1.gif',
                  width: 120,
                  height: 120,
                  fit: BoxFit.cover,
                ),
              ),
              // Example: role toggle or 'IsGuardian' widget could go here
              Textfield(lbl: "Full Name", controller: nameController),
              Textfield(lbl: "Email", controller: emailController),
              Textfield(
                lbl: "Password",
                controller: passwordController,
                obscureText: true,
                icon: Icons.visibility_off,
              ),
              Textfield(
                lbl: "Confirm Password",
                controller: cpasswordController,
                obscureText: true,
                icon: Icons.visibility_off,
              ),
              ElevatedButton(
                onPressed: () => createAccount(context),
                child: const Text("Sign Up"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

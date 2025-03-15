import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:oculoo02/presentation/auth/sign_in.dart';
import 'package:oculoo02/presentation/widgets/isPatient.dart';
import 'package:oculoo02/core/configs/theme/app_color.dart';
import 'package:oculoo02/presentation/widgets/textfield.dart';
import 'package:oculoo02/Patient/home_screen.dart';
import 'package:oculoo02/Guardian/home.dart';

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
  bool _isLoading = false;

  // Validation functions
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  bool _isValidName(String name) {
    // Check if name contains any numeric values
    final containsNumbers = RegExp(r'[0-9]').hasMatch(name);
    return !containsNumbers && name.trim().isNotEmpty;
  }

  // Check if email already exists in Firestore
  Future<bool> _emailAlreadyExists(String email) async {
    try {
      // Check both patient and guardian collections
      final QuerySnapshot patientQuery = await FirebaseFirestore.instance
          .collection('patient')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (patientQuery.docs.isNotEmpty) {
        return true;
      }

      final QuerySnapshot guardianQuery = await FirebaseFirestore.instance
          .collection('guardian')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      return guardianQuery.docs.isNotEmpty;
    } catch (e) {
      print('Error checking email existence: $e');
      return false;
    }
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  Future<void> createAccount(BuildContext context) async {
    setState(() {
      _isLoading = true;
    });

    String name = nameController.text.trim();
    String email = emailController.text.trim();
    String password = passwordController.text.trim();
    String cpassword = cpasswordController.text.trim();

    // Enhanced validation
    // Check for empty fields
    if (name.isEmpty) {
      _showErrorMessage("Name field cannot be empty");
      setState(() => _isLoading = false);
      return;
    }

    if (email.isEmpty) {
      _showErrorMessage("Email field cannot be empty");
      setState(() => _isLoading = false);
      return;
    }

    if (password.isEmpty) {
      _showErrorMessage("Password field cannot be empty");
      setState(() => _isLoading = false);
      return;
    }

    if (cpassword.isEmpty) {
      _showErrorMessage("Please confirm your password");
      setState(() => _isLoading = false);
      return;
    }

    // Validate name (no numbers allowed)
    if (!_isValidName(name)) {
      _showErrorMessage("Name should not contain numeric values");
      setState(() => _isLoading = false);
      return;
    }

    // Validate email format
    if (!_isValidEmail(email)) {
      _showErrorMessage("Please enter a valid email address");
      setState(() => _isLoading = false);
      return;
    }

    // Check if passwords match
    if (password != cpassword) {
      _showErrorMessage("Passwords do not match");
      setState(() => _isLoading = false);
      return;
    }

    // Check if password is strong enough
    if (password.length < 6) {
      _showErrorMessage("Password should be at least 6 characters");
      setState(() => _isLoading = false);
      return;
    }

    // Check if email already exists in Firestore
    bool emailExists = await _emailAlreadyExists(email);
    if (emailExists) {
      _showErrorMessage(
          "Email is already in use. Please use a different email.");
      setState(() => _isLoading = false);
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
        const SnackBar(
          content: Text("Account created successfully!"),
          backgroundColor: Colors.green,
        ),
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
      } else if (e.code == 'invalid-email') {
        errorMessage = "The email address is not valid.";
      }
      _showErrorMessage(errorMessage);
    } catch (e) {
      _showErrorMessage("An unexpected error occurred: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
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
                  onPressed: _isLoading ? null : () => createAccount(context),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    backgroundColor:
                        _isGuardian ? AppColor.secondary : Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isLoading
                      ? CircularProgressIndicator(color: Colors.white)
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isGuardian
                                  ? Icons.shield_outlined
                                  : Icons.person,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _isGuardian
                                  ? "Creating Account as Guardian"
                                  : "Creating Account as Patient",
                              style: const TextStyle(
                                  fontSize: 16, color: Colors.white),
                            ),
                          ],
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

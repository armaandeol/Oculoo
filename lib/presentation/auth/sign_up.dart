import 'package:flutter/material.dart';
import 'package:oculoo02/presentation/auth/sign_in.dart';
import 'package:oculoo02/presentation/widgets/basic_app_button.dart';
import 'package:oculoo02/presentation/widgets/isdoctor.dart';
import 'package:oculoo02/core/configs/theme/app_color.dart';
import 'package:oculoo02/presentation/widgets/textfield.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:oculoo02/Patient/home_screen.dart';


class SignUp extends StatelessWidget {
  
  TextEditingController nameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController cpasswordController = TextEditingController();


  void createAccount(BuildContext context) async {
    String email = emailController.text.trim();
    String password = passwordController.text.trim();
    String cpassword = cpasswordController.text.trim();

    if(email == '' || password == '' || cpassword == '') {
      print("Please fill in all the details");
    }
    else if (password != cpassword) {
      print("password does not match");
    }
    else{
      try{
        UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password);
        print("User created");
        if(userCredential.user != null) {
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => HomeScreen()));
        }
      } on FirebaseAuthException catch(ex){
        print(ex.code.toString());
      }

      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password);
      print("User created"); 
    }
  }

  // const SignUp({super.key});

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
                'assets/images/face_id1.gif',
                width: 120,
                height: 120,
                fit: BoxFit.cover,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
              child: IsGuardian(),
            ),
            Textfield(lbl: "Full Name",controller: nameController),
            Textfield(lbl: "Email",controller: emailController),
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
            BasicAppButton(
              onPressed: () {
                createAccount(context);
                // Navigator.push(
                //   context,
                //   MaterialPageRoute(builder: (context) => SignIn()),
                // );
              },
              child: Text(
                "Sign Up",
                style: TextStyle(color: AppColor.primary),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Already have an Account ?",
                  style: TextStyle(
                    color: AppColor.grey,
                  ),
                ),
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SignIn()),
                    );
                  },
                  child: Text(
                    "Login",
                    style: TextStyle(
                      color: AppColor.secondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}







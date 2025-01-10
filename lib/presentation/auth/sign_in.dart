import 'package:flutter/material.dart';
import 'package:oculoo02/presentation/auth/sign_up.dart';
import 'package:oculoo02/presentation/widgets/basic_app_button.dart';
import 'package:oculoo02/presentation/widgets/isdoctor.dart';
import 'package:oculoo02/core/configs/theme/app_color.dart';
import 'package:oculoo02/presentation/widgets/textfield.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:oculoo02/Patient/home_screen.dart';



class SignIn extends StatelessWidget{

  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();

  void login(BuildContext context) async {

    String email = emailController.text.trim();
    String password = passwordController.text.trim(); 

    if(email == '' || password == ''){
      print("Please fill in all the details");
    }
    else {
      try{
        UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email, 
          password: password
        );
        if(userCredential.user != null) {

          Navigator.popUntil(context, (route) => route.isFirst);

          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => HomeScreen()));
          print("Logged in");
        }
      }on FirebaseAuthException catch(ex){
        print(ex.code.toString());
      }
      
    }
  }
  // const SignIn({super.key});

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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
              child: IsGuardian(
                Guardian: "Are you a Guardian",
              ),
            ),
            
            Textfield(lbl: "Email",controller:emailController),
            Textfield(
              lbl: "Password",
              controller: passwordController,
              icon: Icons.visibility_off, 
              obscureText: true
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
              child: Align(alignment: Alignment.centerRight, child: Text("forgot Password?",style: TextStyle(color: AppColor.grey),)),
            ),
            BasicAppButton(
              onPressed: () {
                login(context);
                // Navigator.push(
                //   context,
                //   MaterialPageRoute(builder: (context) => SignUp()),
                // );
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
                    fontSize: 16
                  ),
                ),
                )
              ],
            )
          ],
        ),
      )
    );
  }
}
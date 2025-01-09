import 'package:flutter/material.dart';
import 'package:oculoo02/presentation/auth/sign_up.dart';
import 'package:oculoo02/presentation/widgets/basic_app_button.dart';
import 'package:oculoo02/presentation/widgets/isdoctor.dart';
import 'package:oculoo02/core/configs/theme/app_color.dart';
import 'package:oculoo02/presentation/widgets/textfield.dart';


class SignIn extends StatelessWidget{
  const SignIn({super.key});

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
            
            Textfield(lbl: "Email"),
            Textfield(lbl: "Password",icon: Icons.visibility_off, obscureText: true
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
              child: Align(alignment: Alignment.centerRight, child: Text("forgot Password?",style: TextStyle(color: AppColor.grey),)),
            ),
            BasicAppButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SignUp()),
                );
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
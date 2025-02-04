import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:oculoo02/Guardian/home.dart';
import 'package:oculoo02/Patient/home_screen.dart';
import 'package:oculoo02/presentation/auth/sign_in.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'Guardian/home.dart';
import 'auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Oculoo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
      // home: SignIn()
      // // home:(
      // //   FirebaseAuth.instance.currentUser != null ? HomePage() :
      // //   OnboardScreen()
      // //   )
    );
  }
}

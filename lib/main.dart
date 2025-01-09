// import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:oculoo02/presentation/landing/pages/onboard_screen.dart';


void main() {
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
      home: Scaffold(
        backgroundColor: Colors.white,
        body: OnboardScreen(),
      ),
    );
  }
}

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:oculoo02/Guardian/home.dart';
import 'package:oculoo02/Patient/home_screen.dart';
import 'package:oculoo02/presentation/auth/sign_in.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'Guardian/home.dart';
import 'auth.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  tz.initializeTimeZones();
  await FlutterLocalNotificationsPlugin().initialize(
    InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ),
    onDidReceiveNotificationResponse: (response) {
      final payload = response.payload;
      if (payload != null) {
        final data = jsonDecode(payload);
        // Handle notification tap with payload data
      }
    },
  );
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
      home: AuthWrapper(),
      // home: SignIn()
      // // home:(
      // //   FirebaseAuth.instance.currentUser != null ? HomePage() :
      // //   OnboardScreen()
      // //   )
    );
  }
}

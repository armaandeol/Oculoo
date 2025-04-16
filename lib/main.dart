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
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Create a global notification channel
const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'medicine_notifications',
  'Medicine Notifications',
  description: 'This channel is used for medicine related notifications.',
  importance: Importance.high,
  playSound: true,
);

// Global FlutterLocalNotificationsPlugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// This is called when app is in background
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('Handling a background message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // Set up FCM background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  // Initialize local notifications
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
      
  // Set FCM foreground notification presentation options
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );
  
  tz.initializeTimeZones();
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

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';

// Define a top-level function to handle background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Handling a background message: ${message.messageId}");
}

class FirebaseMessagingService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Initialize messaging service
  Future<void> init() async {
    try {
      // Register background handler
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);

      // Request permission for iOS/Web
      NotificationSettings settings =
          await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      print('User granted permission: ${settings.authorizationStatus}');

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('Got a message whilst in the foreground!');
        print('Message data: ${message.data}');

        if (message.notification != null) {
          print(
              'Message also contained a notification: ${message.notification}');
          print('Title: ${message.notification!.title}');
          print('Body: ${message.notification!.body}');
        }
      });

      // Get token and store in Firestore
      await updateFCMToken();

      // Set up token refresh listener
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        print('FCM Token refreshed: $newToken');
        updateFCMToken();
      });
    } catch (e) {
      print('Error initializing Firebase Messaging: $e');
    }
  }

  // Get and store FCM token
  Future<void> updateFCMToken() async {
    try {
      User? user = _auth.currentUser;
      if (user == null) return;

      String? token = await _firebaseMessaging.getToken();
      if (token == null) return;

      print('FCM Token: $token');

      // Determine if user is a patient or guardian
      bool isPatient = false;
      bool isGuardian = false;

      // Check if user has a patient document
      DocumentSnapshot patientDoc =
          await _firestore.collection('patient').doc(user.uid).get();
      if (patientDoc.exists) {
        isPatient = true;
      }

      // Check if user has a guardian document
      DocumentSnapshot guardianDoc =
          await _firestore.collection('guardian').doc(user.uid).get();
      if (guardianDoc.exists) {
        isGuardian = true;
      }

      // Common user data
      Map<String, dynamic> userData = {
        'fcmToken': token,
        'platform': Platform.isAndroid ? 'android' : 'ios',
        'lastTokenUpdate': FieldValue.serverTimestamp(),
        'displayName': user.displayName ?? 'User',
      };

      // Store token in users collection (used by Cloud Function)
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(userData, SetOptions(merge: true));

      // Also store token in user's role-specific collection
      if (isPatient) {
        await _firestore.collection('patient').doc(user.uid).update({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
      }

      if (isGuardian) {
        await _firestore.collection('guardian').doc(user.uid).update({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
      }

      print(
          'FCM token saved successfully to users collection and role collections');
    } catch (e) {
      print('Error updating FCM token: $e');
    }
  }

  // Subscribe to topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      print('Subscribed to topic: $topic');
    } catch (e) {
      print('Error subscribing to topic: $e');
    }
  }

  // Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      print('Unsubscribed from topic: $topic');
    } catch (e) {
      print('Error unsubscribing from topic: $e');
    }
  }
}

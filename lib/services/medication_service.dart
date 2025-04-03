import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/medication_log.dart';

class MedicationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Log a medication taken by the patient
  Future<void> logMedication({
    required String medicationName,
    required bool taken,
    String? imageUrl,
  }) async {
    try {
      // Get current user
      User? user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      // Create a medication log
      MedicationLog log = MedicationLog(
        patientUid: user.uid,
        medicationName: medicationName,
        timestamp: DateTime.now(),
        taken: taken,
        imageUrl: imageUrl,
      );

      // First, save to medication_logs collection
      await _firestore.collection('medication_logs').add(log.toMap());
      print('Medication log saved successfully');

      // Get user details for notifications
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(user.uid).get();
      String patientName = user.displayName ?? 'Patient';

      // If user document exists, get name from there
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        patientName = userData['name'] ?? patientName;
      }

      // Add to notifications_queue to trigger Cloud Function
      await _firestore.collection('notifications_queue').add({
        'type': 'medication_taken',
        'patientUid': user.uid,
        'patientName': patientName,
        'medicationName': medicationName,
        'timestamp': FieldValue.serverTimestamp(),
        'imageUrl': imageUrl,
        'processed': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('Notification queued for processing');

      // Also save to patient's medications collection for display in the UI
      await _firestore
          .collection('patient')
          .doc(user.uid)
          .collection('Medications')
          .add({
        'pillName': medicationName,
        'imageUrl': imageUrl,
        'takenAt': FieldValue.serverTimestamp(),
        'taken': taken,
      });
    } catch (e) {
      print('Error logging medication: $e');
      throw e;
    }
  }

  // Get medication logs for a patient
  Stream<List<MedicationLog>> getMedicationLogs(String patientUid) {
    return _firestore
        .collection('medication_logs')
        .where('patientUid', isEqualTo: patientUid)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => MedicationLog.fromMap(doc.data()))
          .toList();
    });
  }

  // Get medications for the current patient
  Stream<List<MedicationLog>> getCurrentPatientMedicationLogs() {
    User? user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }
    return getMedicationLogs(user.uid);
  }
}

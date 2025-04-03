import 'package:cloud_firestore/cloud_firestore.dart';

class MedicationLog {
  final String patientUid;
  final String medicationName;
  final DateTime timestamp;
  final bool taken;
  final String? imageUrl;

  MedicationLog({
    required this.patientUid,
    required this.medicationName,
    required this.timestamp,
    required this.taken,
    this.imageUrl,
  });

  // Convert from MedicationLog to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'patientUid': patientUid,
      'medicationName': medicationName,
      'timestamp': timestamp,
      'taken': taken,
      'imageUrl': imageUrl,
    };
  }

  // Convert from Firestore Map to MedicationLog
  factory MedicationLog.fromMap(Map<String, dynamic> map) {
    return MedicationLog(
      patientUid: map['patientUid'] ?? '',
      medicationName: map['medicationName'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      taken: map['taken'] ?? false,
      imageUrl: map['imageUrl'],
    );
  }
}

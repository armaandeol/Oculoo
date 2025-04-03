# Oculoo Medication Tracking System

This application allows patients to track their medications and notifies guardians when medications are taken.

## Cloud Function Deployment Instructions

The app uses Firebase Cloud Functions to send notifications to guardians when a patient takes medication. Follow these steps to deploy the Cloud Function:

### Prerequisites

1. Install Firebase CLI
```bash
npm install -g firebase-tools
```

2. Log in to Firebase
```bash
firebase login
```

3. Initialize Firebase in your project directory
```bash
firebase init
```
- Select Functions when prompted
- Choose your Firebase project
- Select JavaScript as the language
- Say yes to ESLint
- Say yes to installing dependencies

### Deploying the Cloud Function

1. Copy the Cloud Function code from `firebase_functions_template.js` to your `functions/index.js` file.

2. Deploy the function using the Firebase CLI
```bash
firebase deploy --only functions
```

### Configuration Notes

- The Cloud Function listens for new documents in the `notifications_queue` collection.
- When a patient takes medication, the app creates a document in this collection.
- The Cloud Function then:
  1. Finds all guardians linked to the patient
  2. Creates a notification in the `guardian_notifications` collection for each guardian
  3. Sends a push notification to each guardian's device using FCM

## Debugging Notifications

If guardians are not receiving notifications when patients take medicine, follow these steps to troubleshoot:

### 1. Check Firebase Auth & FCM Token

1. Make sure both patient and guardian are properly authenticated with Firebase Auth
2. Verify FCM tokens are being stored correctly:
   ```
   Check the 'users/{userId}' document for an 'fcmToken' field
   ```
3. For Android devices, ensure Google Play Services is up-to-date

### 2. Verify Patient-Guardian Linkage

1. Check if the patient has linked guardians:
   ```
   In Firestore: 'patient/{patientUid}/linkages/' should contain documents with guardianId
   Each document should have 'status': 'accepted'
   ```
2. If no linkages exist, guardians won't receive notifications

### 3. Verify Notification Queue Documents

1. After a patient logs medication, check the `notifications_queue` collection:
   ```
   Should contain a document with:
   - patientUid: [patient's ID]
   - medicationName: [name of medication]
   - processed: false
   ```
2. Wait a few moments and check if the document is updated with `processed: true`
3. If it stays as `processed: false`, the Cloud Function may not be running

### 4. Check Firebase Functions Logs

1. In Firebase Console, go to Functions > Logs
2. Look for logs from the `notifyGuardian` function
3. Check for errors in finding guardians or sending notifications

### 5. Test Notification Components Individually

1. **Test FCM Token Storage**: 
   - Add a debug print of the FCM token in the app
   - Verify it matches what's in Firestore

2. **Test Medication Logging**:
   - Log a medication and verify it appears in `medication_logs` collection
   - Verify a document is created in `notifications_queue`

3. **Test Guardian UI**:
   - Manually add a document to `guardian_notifications` collection:
   ```
   {
     guardianUid: [guardian's ID],
     patientName: "Test Patient", 
     medicationName: "Test Medicine",
     timestamp: [server timestamp],
     type: "medication_taken",
     read: false
   }
   ```
   - Check if it appears in the guardian's notification screen

### Common Issues

1. **Missing FCM Token**: 
   - Fix: Sign out and sign in again to refresh the FCM token
   - Add restart instructions in the app

2. **Incorrect Collection Paths**: 
   - Cloud Function might be looking in wrong collections
   - Verify collection names and document structures

3. **Firebase Permission Issues**:
   - Check Firebase security rules
   - Ensure patients and guardians have read/write permissions to necessary collections

4. **Device-Specific Issues**:
   - iOS: Background notifications require extra setup
   - Some Android devices have battery optimization that blocks notifications

## App Usage

### Patient Side
1. Log in as a patient
2. Navigate to the "Log Medication" screen
3. Enter the medication name
4. Take a photo of the medication (optional)
5. Submit the medication log

### Guardian Side
1. Log in as a guardian
2. You'll receive a notification when your patient takes medication
3. View the notification details by clicking on the notification
4. You can mark notifications as read by tapping the checkmark icon

## Notification Flow

1. Patient logs medication in the app
2. App creates a document in the `notifications_queue` collection
3. Cloud Function is triggered and processes the notification
4. Cloud Function creates entries in `guardian_notifications` collection
5. Cloud Function sends FCM push notifications to guardians
6. Guardian app displays the notifications

## Development

This project is built with Flutter and Firebase.

- `lib/models/medication_log.dart`: Data model for medication logs
- `lib/services/medication_service.dart`: Service for logging medications
- `lib/services/firebase_messaging_service.dart`: Handles FCM token registration
- `lib/Patient/pages/medication_screen.dart`: UI for logging medications
- `lib/Guardian/notifications_screen.dart`: UI for viewing notifications

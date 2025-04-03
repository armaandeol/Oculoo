// This is a template for a Firebase Cloud Function that would send notifications to guardians
// This would be deployed to Firebase Cloud Functions

const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

/**
 * Cloud Function that is triggered when a new medication log is added
 * This function notifies all guardians linked to a patient when medication is taken
 */
exports.notifyGuardian = functions.firestore
  .document('notifications_queue/{docId}')
  .onCreate(async (snapshot, context) => {
    const medicationData = snapshot.data();
    
    // Skip if already processed
    if (medicationData.processed === true) {
      return null;
    }
    
    try {
      // Get patient info
      const patientId = medicationData.patientUid;
      const patientName = medicationData.patientName || 'Patient';
      const medicationName = medicationData.medicationName || 'medication';
      const imageUrl = medicationData.imageUrl;
      
      console.log(`Processing medication notification for patient: ${patientId}, medication: ${medicationName}`);
      
      // Find patient's guardians from linkages collection
      let linkagesSnapshot;
      try {
        linkagesSnapshot = await admin.firestore()
          .collection('patient')
          .doc(patientId)
          .collection('linkages')
          .where('status', '==', 'accepted')
          .get();
          
        console.log(`Found ${linkagesSnapshot.size} guardians in patient linkages`);
      } catch (linkageError) {
        console.error('Error fetching linkages:', linkageError);
        linkagesSnapshot = { empty: true, size: 0, docs: [] };
      }
      
      // If no linkages found, try the legacy approach
      if (linkagesSnapshot.empty) {
        console.log('No linkages found, trying users collection for guardians array');
        try {
          // Try fetching from users collection (legacy approach)
          const patientDoc = await admin.firestore()
            .collection('users')
            .doc(patientId)
            .get();
            
          if (patientDoc.exists && patientDoc.data().guardians && patientDoc.data().guardians.length > 0) {
            const guardianIds = patientDoc.data().guardians;
            console.log(`Found ${guardianIds.length} guardians in users collection`);
            
            const promises = [];
            
            // Process each guardian
            for (const guardianId of guardianIds) {
              promises.push(processGuardian(guardianId, patientId, patientName, medicationName, imageUrl));
            }
            
            // Mark notification as processed
            promises.push(
              snapshot.ref.update({
                processed: true,
                processedAt: admin.firestore.FieldValue.serverTimestamp(),
                result: 'Notification sent to guardians (legacy method)'
              })
            );
            
            // Wait for all promises to resolve
            const results = await Promise.all(promises);
            console.log(`Processed medication notification (legacy). Results: ${JSON.stringify(results)}`);
            
            return null;
          }
          
          // No guardians found in either collection
          return snapshot.ref.update({
            processed: true,
            processedAt: admin.firestore.FieldValue.serverTimestamp(),
            result: 'No guardians found in any collection'
          });
        } catch (userError) {
          console.error('Error with legacy guardians approach:', userError);
          return snapshot.ref.update({
            processed: true,
            processedAt: admin.firestore.FieldValue.serverTimestamp(),
            error: `No guardians found: ${userError.message}`
          });
        }
      }
      
      const promises = [];
      
      // Process each guardian from linkages
      for (const linkageDoc of linkagesSnapshot.docs) {
        const guardianId = linkageDoc.id;
        promises.push(processGuardian(guardianId, patientId, patientName, medicationName, imageUrl));
      }
      
      // Mark notification as processed
      promises.push(
        snapshot.ref.update({
          processed: true,
          processedAt: admin.firestore.FieldValue.serverTimestamp(),
          result: 'Notification sent to guardians'
        })
      );
      
      // Wait for all promises to resolve
      const results = await Promise.all(promises);
      console.log(`Processed medication notification. Results: ${JSON.stringify(results)}`);
      
      return null;
    } catch (error) {
      console.error('Error processing medication notification:', error);
      
      // Update the document to avoid retries
      await snapshot.ref.update({
        processed: true,
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
        error: error.message
      });
      
      return null;
    }
  });

/**
 * Helper function to process a guardian notification
 */
async function processGuardian(guardianId, patientId, patientName, medicationName, imageUrl) {
  console.log(`Processing guardian: ${guardianId}`);
  
  try {
    // Store notification in Firestore for guardian's UI
    await admin.firestore()
      .collection('guardian_notifications')
      .add({
        guardianUid: guardianId,
        patientUid: patientId,
        patientName: patientName,
        medicationName: medicationName,
        type: 'medication_taken',
        imageUrl: imageUrl,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        read: false
      });
    
    console.log(`Created notification document for guardian ${guardianId}`);
    
    // Try multiple places to find the FCM token
    let fcmToken = null;
    
    // First try users collection
    const userDoc = await admin.firestore()
      .collection('users')
      .doc(guardianId)
      .get();
    
    if (userDoc.exists && userDoc.data().fcmToken) {
      fcmToken = userDoc.data().fcmToken;
      console.log(`Found FCM token in users collection for guardian ${guardianId}`);
    } else {
      // Try guardian collection
      const guardianDoc = await admin.firestore()
        .collection('guardian')
        .doc(guardianId)
        .get();
      
      if (guardianDoc.exists && guardianDoc.data().fcmToken) {
        fcmToken = guardianDoc.data().fcmToken;
        console.log(`Found FCM token in guardian collection for guardian ${guardianId}`);
      } else {
        console.log(`No FCM token found for guardian ${guardianId} in any collection`);
        return { guardianId, success: false, error: 'No FCM token found' };
      }
    }
    
    if (fcmToken) {
      // Send FCM notification
      const payload = {
        notification: {
          title: "Medication Taken",
          body: `${patientName} has taken ${medicationName}`,
          clickAction: 'FLUTTER_NOTIFICATION_CLICK',
        },
        data: {
          type: 'medication_taken',
          patientUid: patientId,
          patientName: patientName,
          medicationName: medicationName,
          imageUrl: imageUrl || '',
          timestamp: Date.now().toString()
        },
      };
      
      const response = await admin.messaging().sendToDevice(fcmToken, payload);
      console.log(`FCM response for guardian ${guardianId}:`, response);
      
      // Log success/failures for analytics
      const successCount = response.successCount || 0;
      const failureCount = response.failureCount || 0;
      
      if (failureCount > 0 && response.results && response.results[0].error) {
        console.error(`Error sending to guardian ${guardianId}:`, response.results[0].error);
        return { guardianId, success: false, error: response.results[0].error };
      }
      
      return { guardianId, success: successCount > 0 };
    }
  } catch (error) {
    console.error(`Error processing guardian ${guardianId}:`, error);
    return { guardianId, success: false, error: error.message };
  }
}

/**
 * Cleanup function that runs daily to remove old processed notifications
 * This prevents the notifications_queue collection from growing too large
 */
exports.cleanupProcessedNotifications = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async (context) => {
    const cutoff = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() - 7 * 24 * 60 * 60 * 1000) // 7 days ago
    );
    
    const snapshot = await admin.firestore()
      .collection('notifications_queue')
      .where('processed', '==', true)
      .where('processedAt', '<', cutoff)
      .get();
    
    const deletePromises = [];
    snapshot.forEach(doc => {
      deletePromises.push(doc.ref.delete());
    });
    
    await Promise.all(deletePromises);
    console.log(`Deleted ${deletePromises.length} old processed notifications`);
    
    return null;
  }); 
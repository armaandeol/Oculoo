import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({Key? key}) : super(key: key);

  @override
  _NotificationsPageState createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _setupFCM();
  }
  
  Future<void> _setupFCM() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    // Request notification permissions
    NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true, 
      sound: true,
    );
    
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');
      
      // Get the token
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        // Save the token to Firestore
        await _saveTokenToFirestore(token);
        
        // Listen for token refreshes
        FirebaseMessaging.instance.onTokenRefresh.listen(_saveTokenToFirestore);
      }
    }
  }
  
  Future<void> _saveTokenToFirestore(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    // Save the FCM token to the guardian's document
    await FirebaseFirestore.instance
      .collection('guardian')
      .doc(user.uid)
      .set({
        'fcmToken': token,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    
    print('FCM Token saved: $token');
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Color(0xFF6C5CE7),
      ),
      body: user == null
          ? Center(child: Text('Please sign in to view notifications'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('guardian')
                  .doc(user.uid)
                  .collection('notifications')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final notifications = snapshot.data?.docs ?? [];

                if (notifications.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_none,
                            size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No notifications yet',
                            style: TextStyle(fontSize: 18, color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final doc = notifications[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final timestamp = (data['timestamp'] as Timestamp).toDate();
                    final dateString =
                        DateFormat('MMM dd, yyyy HH:mm').format(timestamp);

                    if (data['type'] == 'medicine_taken') {
                      return Card(
                        margin: const EdgeInsets.all(8.0),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Color(0xFF6C5CE7).withOpacity(0.1),
                            child: Icon(Icons.medical_services,
                                color: Color(0xFF6C5CE7)),
                          ),
                          title: Text(
                              '${data['patientName']} took their medicine'),
                          subtitle: Text(dateString),
                          trailing: IconButton(
                            icon: Icon(Icons.check_circle_outline),
                            onPressed: () async {
                              await doc.reference.update({'read': true});
                            },
                          ),
                          onTap: () {
                            // Show the medicine image in a dialog
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text('Medicine Verification'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Image.network(data['imageUrl']),
                                    SizedBox(height: 16),
                                    Text(
                                        '${data['patientName']} took their medicine at $dateString'),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      doc.reference.update({'read': true});
                                    },
                                    child: Text('Mark as Read'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      );
                    }

                    // Existing linkage request card
                    return Card(
                      elevation: 4,
                      margin: EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor:
                                      Color(0xFF6C5CE7).withOpacity(0.1),
                                  child: Icon(Icons.person,
                                      color: Color(0xFF6C5CE7)),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        data['patientName'] ??
                                            'Unknown Patient',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        'Request received on $dateString',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Patient ${data['patientName']} wants you to be their guardian. Do you accept?',
                              style: TextStyle(fontSize: 16),
                            ),
                            SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton.icon(
                                  icon: Icon(Icons.close, color: Colors.red),
                                  label: Text('Decline'),
                                  onPressed: _isProcessing
                                      ? null
                                      : () => _respondToRequest(doc.id, false),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: Colors.red),
                                  ),
                                ),
                                SizedBox(width: 12),
                                ElevatedButton.icon(
                                  icon: Icon(Icons.check),
                                  label: Text('Accept'),
                                  onPressed: _isProcessing
                                      ? null
                                      : () => _respondToRequest(doc.id, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Color(0xFF6C5CE7),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  Future<void> _respondToRequest(String requestId, bool accept) async {
    setState(() => _isProcessing = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get the request document
      final requestDoc = await FirebaseFirestore.instance
          .collection('linkages')
          .doc(requestId)
          .get();

      if (!requestDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Request no longer exists')),
        );
        setState(() => _isProcessing = false);
        return;
      }

      final requestData = requestDoc.data()!;
      final patientId = requestData['patientUID'];

      if (accept) {
        // Update the linkage status
        await FirebaseFirestore.instance
            .collection('linkages')
            .doc(requestId)
            .update({
          'status': 'accepted',
          'acceptedAt': FieldValue.serverTimestamp(),
        });

        // Add patient to guardian's patients list with more details
        await FirebaseFirestore.instance
            .collection('guardian')
            .doc(user.uid)
            .collection('listing')
            .add({
          'uid': patientId,
          'timestamp': FieldValue.serverTimestamp(),
          'name': requestData['patientName'],
          'status': 'active',
        });

        // Update patient's linkage status from pending to accepted
        await FirebaseFirestore.instance
            .collection('patient')
            .doc(patientId)
            .collection('linkages')
            .doc(user.uid) // Guardian's UID is the document ID
            .update({
          'status': 'accepted',
          'acceptedAt': FieldValue.serverTimestamp(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Request accepted. Patient added to your list.')),
        );

        // Pop back to previous screen after a brief delay
        Future.delayed(Duration(seconds: 1), () {
          Navigator.pop(
              context, true); // Return true to indicate a change was made
        });
      } else {
        // Decline the request
        await FirebaseFirestore.instance
            .collection('linkages')
            .doc(requestId)
            .update({
          'status': 'declined',
          'declinedAt': FieldValue.serverTimestamp(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Request declined')),
        );

        // Pop back after declining too
        Future.delayed(Duration(seconds: 1), () {
          Navigator.pop(context, true);
        });
      }
    } catch (e) {
      print("Error processing request: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
      setState(() => _isProcessing = false);
    }
  }
}

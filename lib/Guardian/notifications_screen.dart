import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationsScreen extends StatefulWidget {
  final String guardianUid;

  const NotificationsScreen({Key? key, required this.guardianUid})
      : super(key: key);

  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Verify FCM token on notification screen open
    _verifyFcmToken();
  }

  Future<void> _verifyFcmToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Check if token exists in users collection
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists || !userDoc.data()!.containsKey('fcmToken')) {
        print(
            'FCM token missing in users collection. Requesting from service...');
        // We should trigger token refresh through a service, but for now just log it
      } else {
        print('FCM token verified in users collection');
      }
    } catch (e) {
      print('Error verifying FCM token: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notifications'),
        backgroundColor: Color(0xFF6C5CE7),
      ),
      body: _buildNotificationsList(),
    );
  }

  Widget _buildNotificationsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('guardian_notifications')
          .where('guardianUid', isEqualTo: widget.guardianUid)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        // Handle error state
        if (snapshot.hasError) {
          return _buildErrorState(
              'Error loading notifications: ${snapshot.error}');
        }

        // Handle loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        final notifications = snapshot.data?.docs ?? [];

        // Handle empty state
        if (notifications.isEmpty) {
          return _buildEmptyState();
        }

        // Display notifications
        return _buildNotificationsListView(notifications);
      },
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red),
            SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {});
              },
              child: Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          SizedBox(height: 8),
          Text(
            'When a patient takes medication, you\'ll see it here',
            style: TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsListView(
      List<QueryDocumentSnapshot> notifications) {
    return ListView.builder(
      itemCount: notifications.length,
      itemBuilder: (context, index) {
        final notification =
            notifications[index].data() as Map<String, dynamic>;
        final timestamp = notification['timestamp'] as Timestamp?;
        final String dateString = timestamp != null
            ? DateFormat('MMM dd, yyyy HH:mm').format(timestamp.toDate())
            : 'Unknown time';

        if (notification['type'] == 'medication_taken') {
          return _buildMedicationNotificationCard(
            notification: notification,
            dateString: dateString,
            notificationId: notifications[index].id,
          );
        }

        // Default notification card
        return Card(
          margin: const EdgeInsets.all(8.0),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Color(0xFF6C5CE7).withOpacity(0.1),
              child: Icon(Icons.notifications, color: Color(0xFF6C5CE7)),
            ),
            title: Text(notification['title'] ?? 'Notification'),
            subtitle: Text(dateString),
            trailing: IconButton(
              icon: Icon(Icons.check_circle_outline),
              onPressed: () => _markAsRead(notifications[index].id),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMedicationNotificationCard({
    required Map<String, dynamic> notification,
    required String dateString,
    required String notificationId,
  }) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        leading: CircleAvatar(
          backgroundColor: Color(0xFF6C5CE7).withOpacity(0.1),
          child: Icon(Icons.medication, color: Color(0xFF6C5CE7)),
        ),
        title: Text(
          '${notification['patientName']} took ${notification['medicationName']}',
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Text(dateString),
            if (notification['read'] == true)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  'Read',
                  style: TextStyle(
                    color: Colors.green,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(
            notification['read'] == true
                ? Icons.check_circle
                : Icons.check_circle_outline,
            color: notification['read'] == true ? Colors.green : Colors.grey,
          ),
          onPressed: () => _markAsRead(notificationId),
        ),
        onTap: () {
          if (notification['imageUrl'] != null) {
            _showNotificationDetails(
              notificationId: notificationId,
              notification: notification,
              dateString: dateString,
            );
          }
        },
      ),
    );
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await _firestore
          .collection('guardian_notifications')
          .doc(notificationId)
          .update({'read': true});
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  void _showNotificationDetails({
    required String notificationId,
    required Map<String, dynamic> notification,
    required String dateString,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Medication Verification'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              notification['imageUrl'] != null &&
                      notification['imageUrl'].toString().isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        notification['imageUrl'],
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 200,
                            color: Colors.grey.shade300,
                            child: Center(
                              child: Icon(Icons.error_outline, size: 48),
                            ),
                          );
                        },
                      ),
                    )
                  : Container(
                      height: 100,
                      color: Colors.grey.shade200,
                      child: Center(
                        child: Icon(Icons.medication, size: 48),
                      ),
                    ),
              SizedBox(height: 16),
              Text(
                '${notification['patientName']} took ${notification['medicationName']} at $dateString',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _markAsRead(notificationId);
            },
            child: Text('Mark as Read'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text('Close'),
          ),
        ],
      ),
    );
  }
}

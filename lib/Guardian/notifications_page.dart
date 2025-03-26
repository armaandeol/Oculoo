import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({Key? key}) : super(key: key);

  @override
  _NotificationsPageState createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Linkage Requests'),
        backgroundColor: Color(0xFF6C5CE7),
      ),
      body: user == null
          ? Center(child: Text('Please sign in to view requests'))
          : StreamBuilder<QuerySnapshot>(
              // Modified query to avoid requiring a composite index
              stream: FirebaseFirestore.instance
                  .collection('linkages')
                  .where('guardianUID', isEqualTo: user.uid)
                  .where('status', isEqualTo: 'pending')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_off,
                            size: 80, color: Colors.grey[400]),
                        SizedBox(height: 16),
                        Text(
                          'No pending requests',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Sort the documents by timestamp client-side
                final docs = snapshot.data!.docs;
                docs.sort((a, b) {
                  final aTime = a['timestamp'] as Timestamp?;
                  final bTime = b['timestamp'] as Timestamp?;
                  if (aTime == null) return 1;
                  if (bTime == null) return -1;
                  // Sort descending (newest first)
                  return bTime.compareTo(aTime);
                });

                return ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;

                    final timestamp = data['timestamp'] as Timestamp?;
                    final dateString = timestamp != null
                        ? DateFormat.yMMMd().add_jm().format(timestamp.toDate())
                        : 'Unknown time';

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

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:oculoo02/core/configs/theme/app_color.dart';
import 'package:oculoo02/presentation/auth/sign_in.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _guardianUidController;
  int _totalReminders = 0;
  bool _isLoading = false;

  // Guardian state variables
  String? _guardianId;
  String? _guardianName;
  String? _guardianStatus; // null, 'pending', or 'linked'
  bool _isLoadingGuardian = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _guardianUidController = TextEditingController();
    _loadUserData();
    _fetchTotalReminders();
    _checkGuardianStatus(); // Check guardian status when page loads
  }

  // Fetch total reminders from Firestore
  Future<void> _fetchTotalReminders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() => _isLoading = true);
      try {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('patient')
            .doc(user.uid)
            .collection('Medications')
            .get();

        setState(() {
          _totalReminders = querySnapshot.docs.length;
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching reminders: $e')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('patient')
          .doc(user.uid)
          .get();

      setState(() {
        _nameController.text = doc['name'] ?? '';
        _emailController.text = user.email ?? '';
      });
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('patient')
          .doc(user.uid)
          .update({
        'name': _nameController.text,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => SignIn()),
      );
    } catch (e) {
      print("Logout error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logout failed: ${e.toString()}'),
          backgroundColor: Colors.white24,
        ),
      );
    }
  }

  // Send request to guardian - first check if user exists
  Future<void> _sendGuardianRequest() async {
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    final guardianUid = _guardianUidController.text.trim();

    if (user == null || guardianUid.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Validate guardian UID
      final guardianDoc = await FirebaseFirestore.instance
          .collection('guardian')
          .doc(guardianUid)
          .get();

      if (!guardianDoc.exists || guardianDoc['role'] != 'guardian') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid guardian UID')),
        );
        setState(() => _isLoading = false);
        return;
      }

      // Check if there's already a pending request
      final pendingSnapshot = await FirebaseFirestore.instance
          .collection('linkages')
          .where('patientUID', isEqualTo: user.uid)
          .where('guardianUID', isEqualTo: guardianUid)
          .where('status', isEqualTo: 'pending')
          .get();

      if (pendingSnapshot.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('A request is already pending for this guardian')),
        );
        setState(() => _isLoading = false);
        return;
      }

      // Get patient name
      final patientDoc = await FirebaseFirestore.instance
          .collection('patient')
          .doc(user.uid)
          .get();
      final patientName = patientDoc['name'] ?? 'Patient';

      // Create linkage request in root collection
      final linkageData = {
        'patientUID': user.uid,
        'guardianUID': guardianUid,
        'initiator': 'patient',
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
        'patientName': patientName,
        'guardianName': guardianDoc['name'],
      };

      // Add to main linkages collection
      await FirebaseFirestore.instance.collection('linkages').add(linkageData);

      // Add linkage to patient's collection as well
      await FirebaseFirestore.instance
          .collection('patient')
          .doc(user.uid)
          .collection('linkages')
          .doc(
              guardianUid) // Use guardian UID as document ID for easy reference
          .set({
        ...linkageData,
        'timestamp': FieldValue.serverTimestamp(), // Refresh timestamp
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request sent to guardian')),
      );

      // Update UI
      setState(() {
        _guardianId = guardianUid;
        _guardianName = guardianDoc['name'] ?? 'Guardian';
        _guardianStatus = 'pending';
        _isLoading = false;
      });
    } catch (e) {
      print("Error sending guardian request: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending request: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  // Check if the patient has a guardian linked or a pending request
  Future<void> _checkGuardianStatus() async {
    setState(() => _isLoadingGuardian = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // First check the main linkages collection for the most up-to-date status
      try {
        final linkageSnapshot = await FirebaseFirestore.instance
            .collection('linkages')
            .where('patientUID', isEqualTo: user.uid)
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get();

        // If there's an active linkage in the main collection
        if (linkageSnapshot.docs.isNotEmpty) {
          final mainLinkage = linkageSnapshot.docs.first.data();
          final guardianId = mainLinkage['guardianUID'];
          final status = mainLinkage['status'];

          // If it's accepted or pending, update patient's collection and UI
          if (status == 'accepted' || status == 'pending') {
            // Get guardian name
            final guardianDoc = await FirebaseFirestore.instance
                .collection('guardian')
                .doc(guardianId)
                .get();

            final guardianName =
                guardianDoc.exists ? guardianDoc['name'] : 'Unknown Guardian';

            // Update the patient's linkages collection to match main collection
            await FirebaseFirestore.instance
                .collection('patient')
                .doc(user.uid)
                .collection('linkages')
                .doc(guardianId)
                .set({
              'patientUID': user.uid,
              'guardianUID': guardianId,
              'status': status,
              'timestamp': FieldValue.serverTimestamp(),
              'guardianName': guardianName,
            }, SetOptions(merge: true));

            // Update UI
            setState(() {
              _guardianId = guardianId;
              _guardianName = guardianName;
              _guardianStatus = status;
              _isLoadingGuardian = false;
            });
            return;
          }
        }
      } catch (e) {
        // Handle specific Firestore index error - continue to fallback
        print("Query requires index, using fallback method: $e");
        // Don't show error to user, just use fallback method
      }

      // If no active linkage in main collection or if index error occurred,
      // check patient's collection as fallback
      final patientLinkagesSnapshot = await FirebaseFirestore.instance
          .collection('patient')
          .doc(user.uid)
          .collection('linkages')
          .get();

      if (patientLinkagesSnapshot.docs.isNotEmpty) {
        // Find most recent active linkage (accepted or pending)
        DocumentSnapshot? activeLink;
        for (var doc in patientLinkagesSnapshot.docs) {
          final status = doc.data()['status'];
          if (status == 'accepted' || status == 'pending') {
            if (activeLink == null ||
                (doc.data()['timestamp'] != null &&
                    (activeLink.data() as Map<String, dynamic>)['timestamp'] !=
                        null &&
                    doc.data()['timestamp'].toDate().isAfter(
                        (activeLink.data() as Map<String, dynamic>)['timestamp']
                            .toDate()))) {
              activeLink = doc;
            }
          }
        }

        if (activeLink != null) {
          final linkage = activeLink.data() as Map<String, dynamic>;
          setState(() {
            _guardianId = linkage['guardianUID'];
            _guardianName = linkage['guardianName'] ?? 'Guardian';
            _guardianStatus = linkage['status'];
            _isLoadingGuardian = false;
          });
          return;
        }
      }

      // No active linkage found anywhere
      setState(() {
        _guardianId = null;
        _guardianName = null;
        _guardianStatus = null;
        _isLoadingGuardian = false;
      });
    } catch (e) {
      print("Error checking guardian status: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Error loading guardian information. Please try again later.')),
      );
      setState(() => _isLoadingGuardian = false);
    }
  }

  // Remove guardian linkage
  Future<void> _removeGuardian() async {
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || _guardianId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Get linkage document from main collection
      final linkageSnapshot = await FirebaseFirestore.instance
          .collection('linkages')
          .where('patientUID', isEqualTo: user.uid)
          .where('guardianUID', isEqualTo: _guardianId)
          .get();

      if (linkageSnapshot.docs.isNotEmpty) {
        // Delete linkage from main collection
        for (var doc in linkageSnapshot.docs) {
          await doc.reference.delete();
        }
      }

      // Also remove from patient's collection
      await FirebaseFirestore.instance
          .collection('patient')
          .doc(user.uid)
          .collection('linkages')
          .doc(_guardianId)
          .delete();

      // Remove patient's entry from guardian's listing collection
      final guardianListingSnapshot = await FirebaseFirestore.instance
          .collection('guardian')
          .doc(_guardianId)
          .collection('listing')
          .where('uid', isEqualTo: user.uid)
          .get();

      if (guardianListingSnapshot.docs.isNotEmpty) {
        // Delete all matching entries
        for (var doc in guardianListingSnapshot.docs) {
          await doc.reference.delete();
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Guardian removed successfully')),
      );

      // Update UI
      setState(() {
        _guardianId = null;
        _guardianName = null;
        _guardianStatus = null;
        _isLoading = false;
      });
    } catch (e) {
      print("Error removing guardian: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error removing guardian: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  // Show dialog to add a guardian
  void _showAddGuardianDialog() {
    _guardianUidController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Guardian'),
        content: TextField(
          controller: _guardianUidController,
          decoration: InputDecoration(
            labelText: 'Guardian UID',
            hintText: 'Enter the guardian\'s UID',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _sendGuardianRequest();
            },
            child: Text('Send Request'),
          ),
        ],
      ),
    );
  }

  // Show dialog to confirm guardian removal
  void _showRemoveGuardianDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove Guardian'),
        content: Text('Are you sure you want to remove your guardian?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('No'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _removeGuardian();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Yes'),
          ),
        ],
      ),
    );
  }

  // Helper to build guardian UI section
  Widget _buildGuardianSection() {
    if (_isLoadingGuardian) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_guardianStatus == null) {
      // No guardian linked
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: const Icon(Icons.person_add, size: 40, color: Colors.blue),
          title: const Text('No guardian linked'),
          subtitle:
              const Text('Add a guardian to help manage your medications'),
          trailing: IconButton(
            icon: const Icon(Icons.add_circle, color: Colors.blue, size: 36),
            onPressed: _showAddGuardianDialog,
          ),
        ),
      );
    } else if (_guardianStatus == 'pending') {
      // Pending guardian request
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: const Icon(Icons.pending, size: 40, color: Colors.orange),
          title: Text('Guardian Request Pending'),
          subtitle:
              Text('Request sent to $_guardianName. Waiting for approval.'),
          trailing: IconButton(
            icon: const Icon(Icons.cancel, color: Colors.red, size: 36),
            onPressed: _showRemoveGuardianDialog,
            tooltip: 'Cancel Request',
          ),
        ),
      );
    } else {
      // Guardian linked
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: const Icon(Icons.person, size: 40, color: Colors.green),
          title: Text('Guardian: $_guardianName'),
          subtitle:
              const Text('Your guardian can view your medication schedule'),
          trailing: ElevatedButton(
            onPressed: _showRemoveGuardianDialog,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Total Reminders Button
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading:
                            const Icon(Icons.notifications_active, size: 40),
                        title: const Text('Total Reminders'),
                        subtitle: Text(
                          '$_totalReminders reminders',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        onTap: () {
                          // Optionally navigate to reminders page or show a dialog
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(
                                    'You have $_totalReminders reminders')),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Guardian Section Details
                    _buildGuardianSection(),
                    const SizedBox(height: 20),

                    // Profile Picture and Details
                    CircleAvatar(
                      radius: 50,
                      child: Icon(Icons.person, size: 50),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email),
                      ),
                      readOnly: true,
                      enabled: false,
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: _updateProfile,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 40, vertical: 15),
                      ),
                      child: const Text('Save Changes'),
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.medical_services),
                      title: const Text('Medical History'),
                      onTap: () =>
                          Navigator.pushNamed(context, '/medical_history'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.notifications),
                      title: const Text('Notification Settings'),
                      onTap: () => Navigator.pushNamed(
                          context, '/notification_settings'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _guardianUidController.dispose();
    super.dispose();
  }
}

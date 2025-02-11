import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
// Import your sign in page if needed.
import 'package:oculoo02/presentation/auth/sign_in.dart';

/// =======================================
/// Guardian Home Page: Lists linked patients.
/// =======================================
class GuardianHomePage extends StatefulWidget {
  const GuardianHomePage({Key? key}) : super(key: key);

  @override
  _GuardianHomePageState createState() => _GuardianHomePageState();
}

class _GuardianHomePageState extends State<GuardianHomePage> {
  List<String> _patientIds = [];

  @override
  void initState() {
    super.initState();
    _loadLinkedPatients();
  }

  /// Loads linked patient UIDs from the guardian’s listing subcollection.
  Future<void> _loadLinkedPatients() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("No user is logged in.");
      return;
    }
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('guardian')
          .doc(user.uid)
          .collection('listing')
          .get();

      final ids = snapshot.docs
          .map((doc) => (doc.data() as Map<String, dynamic>)['uid']?.toString())
          .where((uid) => uid != null)
          .cast<String>()
          .toList();
      setState(() => _patientIds = ids);
    } catch (e) {
      print("Error loading linked patients: $e");
    }
  }

  /// Builds a clickable patient list item.
  Widget _buildPatientListItem(String patientId, Size size) {
    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance.collection('patient').doc(patientId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const ListTile(
            title: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return ListTile(
            title: Text('Error loading patient',
                style: TextStyle(color: Colors.red)),
          );
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return ListTile(
            title: Text('No patient found for UID: $patientId'),
          );
        }
        final patientData = snapshot.data!.data() as Map<String, dynamic>? ??
            <String, dynamic>{};
        final patientName = patientData['name'] ?? 'Unknown Patient';

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          elevation: 3,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: const Icon(Icons.person, color: Colors.indigo),
            title: Text(
              patientName,
              style: TextStyle(
                fontSize: size.width * 0.045,
                fontWeight: FontWeight.w600,
              ),
            ),
            // On tap, navigate to the patient detail page.
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PatientDetailPage(
                    patientId: patientId,
                    patientName: patientName,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// Builds the patients section.
  Widget _buildPatientsSection(Size size) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Patients",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.indigo[700],
          ),
        ),
        const SizedBox(height: 10),
        _patientIds.isEmpty
            ? const Center(child: Text("No patients found."))
            : Column(
                children: _patientIds
                    .map((id) => _buildPatientListItem(id, size))
                    .toList(),
              ),
      ],
    );
  }

  /// Signs out the current user and navigates to the Sign In screen.
  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      // Redirect to the Sign In page after signing out.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => SignIn()),
      );
      print("User signed out successfully.");
    } catch (e) {
      print("Error signing out: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Guardian Dashboard"),
        backgroundColor: Colors.indigo,
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLinkedPatients,
            tooltip: "Refresh",
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: "Logout",
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: _buildPatientsSection(size),
      ),
    );
  }
}

/// ======================================================
/// Patient Detail Page: Shows a particular patient’s
/// medication reminders and logs (with a date selector).
/// ======================================================
class PatientDetailPage extends StatefulWidget {
  final String patientId;
  final String patientName;
  const PatientDetailPage({
    Key? key,
    required this.patientId,
    required this.patientName,
  }) : super(key: key);

  @override
  _PatientDetailPageState createState() => _PatientDetailPageState();
}

class _PatientDetailPageState extends State<PatientDetailPage>
    with SingleTickerProviderStateMixin {
  // For a date selector (optional)
  final int initialDays = 14;
  late DateTime _startDate;
  DateTime? _selectedDate;
  final ScrollController _dateScrollController = ScrollController();

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _startDate = DateTime.now();
    _selectedDate = _startDate;
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
  }

  void _scrollToSelected() {
    final index = _selectedDate!.difference(_startDate).inDays;
    final screenWidth = MediaQuery.of(context).size.width;
    final itemWidth = screenWidth * 0.22;
    final offset = (itemWidth * index) - (screenWidth / 2 - itemWidth / 2);
    _dateScrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<DateTime> _generateDates() =>
      List.generate(initialDays, (i) => _startDate.add(Duration(days: i)));

  String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  Widget _buildHeader(Size size) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          getGreeting(),
          style: TextStyle(
            fontSize: size.width * 0.06,
            fontWeight: FontWeight.bold,
            color: Colors.indigo,
          ),
        ),
        Text(
          widget.patientName,
          style: TextStyle(
            fontSize: size.width * 0.055,
            fontWeight: FontWeight.w600,
            color: Colors.indigo,
          ),
        ),
      ],
    );
  }

  Widget _buildDateSelector(Size size) {
    return SizedBox(
      height: size.height * 0.12,
      child: ListView.builder(
        controller: _dateScrollController,
        scrollDirection: Axis.horizontal,
        itemCount: initialDays,
        itemBuilder: (ctx, i) {
          final date = _startDate.add(Duration(days: i));
          final isSelected = isSameDay(date, _selectedDate!);
          return GestureDetector(
            onTap: () => setState(() {
              _selectedDate = date;
              _scrollToSelected();
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: size.width * 0.22,
              margin: EdgeInsets.symmetric(horizontal: size.width * 0.015),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? LinearGradient(
                        colors: [Colors.indigo, Colors.blue.shade400])
                    : LinearGradient(
                        colors: [Colors.grey.shade200, Colors.grey.shade100]),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: isSelected
                        ? Colors.indigo.withOpacity(0.3)
                        : Colors.grey.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat.E().format(date),
                    style: TextStyle(
                      fontSize: size.width * 0.035,
                      color: isSelected ? Colors.white : Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: size.height * 0.005),
                  Text(
                    DateFormat.d().format(date),
                    style: TextStyle(
                      fontSize: size.width * 0.045,
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Medication Reminders Section.
  Widget _buildMedicationSection(Size size) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('patient')
          .doc(widget.patientId)
          .collection('Medications')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text("No medication reminders found."),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final med = docs[i].data() as Map<String, dynamic>;
            return Card(
              margin: EdgeInsets.symmetric(vertical: size.height * 0.005),
              elevation: 3,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: size.width * 0.04,
                  vertical: size.height * 0.01,
                ),
                title: Text(
                  med['medicine'] ?? 'Unknown Medicine',
                  style: TextStyle(
                    fontSize: size.width * 0.045,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  "Dosage: ${med['dosage'] ?? 'N/A'}${med['unit'] ?? ''}\n"
                  "Times: ${(med['times'] as List<dynamic>?)?.join(', ') ?? ''}\n"
                  "Frequency: ${med['frequency'] ?? 'N/A'}",
                  style: TextStyle(fontSize: size.width * 0.035),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Medicine Logs Section.
  Widget _buildLogSection(Size size) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('patient')
          .doc(widget.patientId)
          .collection('Logs')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text("No medicine logs found."),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final log = docs[i].data() as Map<String, dynamic>;
            final summary = log['summary'] as List<dynamic>? ?? [];
            String medicine = 'Unknown Medicine';
            String dosage = 'Unknown Dosage';
            String unit = '';
            String time = 'Unknown Time';
            String date = 'Unknown Date';

            if (summary.isNotEmpty) {
              medicine = summary[0]['text'] ?? 'Unknown Medicine';
              if (summary.length > 1) {
                dosage = summary[1]['text'] ?? 'Unknown Dosage';
              }
              if (summary.length > 2) {
                unit = summary[2]['text'] ?? '';
              }
              if (summary.length > 3) {
                time = summary[3]['text'] ?? 'Unknown Time';
              }
              if (summary.length > 4) {
                date = summary[4]['text'] ?? 'Unknown Date';
              }
            }
            return Card(
              margin: EdgeInsets.symmetric(vertical: size.height * 0.005),
              elevation: 3,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: size.width * 0.04,
                  vertical: size.height * 0.01,
                ),
                title: Text(
                  medicine,
                  style: TextStyle(
                    fontSize: size.width * 0.045,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  "$dosage$unit\n$time • $date",
                  style: TextStyle(fontSize: size.width * 0.035),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSectionTitle(String title, Size size) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: size.height * 0.015),
      child: Text(
        title,
        style: TextStyle(
          fontSize: size.width * 0.055,
          fontWeight: FontWeight.bold,
          color: Colors.indigo,
        ),
      ),
    );
  }

  /// Signs out the current user and navigates to the Sign In screen.
  Future<void> _exit() async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => SignIn()),
      );
      print("User signed out successfully.");
    } catch (e) {
      print("Error signing out: $e");
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _dateScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.patientName),
        backgroundColor: Colors.indigo,
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: _exit,
            tooltip: "Exit",
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: size.width * 0.04,
              vertical: size.height * 0.02,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(size),
                SizedBox(height: size.height * 0.02),
                _buildDateSelector(size),
                SizedBox(height: size.height * 0.03),
                TabBar(
                  controller: _tabController,
                  labelColor: Colors.indigo,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Colors.indigo,
                  tabs: const [
                    Tab(text: "Medications"),
                    Tab(text: "Logs"),
                  ],
                ),
                SizedBox(
                  height: size.height * 0.6,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Medications tab
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle('Medications Reminders', size),
                          _buildMedicationSection(size),
                        ],
                      ),
                      // Logs tab
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle('Medicine Logs', size),
                          _buildLogSection(size),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

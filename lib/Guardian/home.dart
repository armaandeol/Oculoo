import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:oculoo02/presentation/auth/sign_in.dart';

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

  Future<void> _loadLinkedPatients() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

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
      print("Error loading patients: $e");
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE1F5FE), Color(0xFFF3E5F5)],
          ),
        ),
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Linked Patients',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF311B92),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: _patientIds.isEmpty
                          ? Center(
                              child: Text(
                                'No patients linked yet',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 18,
                                ),
                              ),
                            )
                          : _buildPatientList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('Guardian Dashboard'),
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF5E35B1), Color(0xFF9575CD)],
            stops: [0.2, 0.8],
          ),
        ),
      ),
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: _loadLinkedPatients,
        ),
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.white),
          onPressed: _logout,
        ),
      ],
    );
  }

  Widget _buildPatientList() {
    return ListView.separated(
      physics: const ClampingScrollPhysics(),
      itemCount: _patientIds.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) => _PatientCard(patientId: _patientIds[i]),
    );
  }
}

class _PatientCard extends StatelessWidget {
  final String patientId;

  const _PatientCard({required this.patientId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance.collection('patient').doc(patientId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final name = data['name'] ?? 'Unknown Patient';

        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PatientDetailPage(
                  patientId: patientId,
                  patientName: name,
                ),
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Colors.white, Color(0xFFEDE7F6)]),
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1C4E9),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(Icons.person_outline,
                        color: Color(0xFF4527A0), size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF311B92),
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: Color(0xFF673AB7)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

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
  late DateTime _selectedDate = DateTime.now();
  late TabController _tabController;
  final ScrollController _dateController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Widget _buildDatePicker() {
    final dates =
        List.generate(14, (i) => DateTime.now().add(Duration(days: i)));

    return SizedBox(
      height: 100,
      child: ListView.builder(
        controller: _dateController,
        scrollDirection: Axis.horizontal,
        itemCount: dates.length,
        itemBuilder: (ctx, i) {
          final date = dates[i];
          final isSelected = _selectedDate.day == date.day;

          return GestureDetector(
            onTap: () => setState(() => _selectedDate = date),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 8),
              width: 80,
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(
                        colors: [Color(0xFF7E57C2), Color(0xFFB39DDB)])
                    : LinearGradient(
                        colors: [Colors.grey.shade100, Colors.grey.shade50]),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  if (isSelected)
                    BoxShadow(
                      color: Colors.purple.shade200,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat.E().format(date),
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat.d().format(date),
                    style: TextStyle(
                      fontSize: 22,
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

  Widget _buildMedicationList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('patient')
          .doc(widget.patientId)
          .collection('Medications')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());

        return ListView.separated(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(top: 16),
          itemCount: snapshot.data!.docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (ctx, i) {
            final med = snapshot.data!.docs[i].data() as Map<String, dynamic>;

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ListTile(
                leading:
                    Icon(Icons.medication, color: Colors.deepPurple.shade700),
                title: Text(
                  med['medicine'] ?? 'Unknown',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF311B92)),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text('Dosage: ${med['dosage']} ${med['unit']}',
                        style: TextStyle(color: Colors.grey.shade600)),
                    Text('Times: ${(med['times'] as List).join(', ')}',
                        style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLogList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('patient')
          .doc(widget.patientId)
          .collection('Logs')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());

        return ListView.separated(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(top: 16),
          itemCount: snapshot.data!.docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (ctx, i) {
            final log = snapshot.data!.docs[i].data() as Map<String, dynamic>;
            final summary = log['summary'] as List<dynamic>? ?? [];

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2)),
                ],
              ),
              child: ListTile(
                leading: Icon(Icons.history, color: Colors.green.shade700),
                title: Text(
                  summary.isNotEmpty ? summary[0]['text'] : 'Unknown',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1B5E20)),
                ),
                subtitle: summary.length > 1
                    ? Text('${summary[1]['text']} ${summary[2]['text']}',
                        style: TextStyle(color: Colors.grey.shade600))
                    : null,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.patientName),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF5E35B1), Color(0xFF9575CD)],
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE1F5FE), Color(0xFFF3E5F5)],
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hello, Guardian',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Viewing records for:',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                  Text(
                    widget.patientName,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF311B92)),
                  ),
                ],
              ),
            ),
            _buildDatePicker(),
            const SizedBox(height: 16),
            Expanded(
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2)),
                      ],
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: UnderlineTabIndicator(
                        borderSide:
                            BorderSide(width: 2, color: Color(0xFF5E35B1)),
                        insets: EdgeInsets.symmetric(horizontal: 16),
                      ),
                      labelColor: Color(0xFF5E35B1),
                      unselectedLabelColor: Colors.grey.shade600,
                      labelStyle: TextStyle(fontWeight: FontWeight.w600),
                      unselectedLabelStyle:
                          TextStyle(fontWeight: FontWeight.normal),
                      tabs: const [
                        Tab(text: 'Medications'),
                        Tab(text: 'Logs'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: _buildMedicationList(),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: _buildLogList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

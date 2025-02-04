import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:oculoo02/core/configs/theme/app_color.dart';
import 'package:intl/intl.dart';
import 'package:oculoo02/presentation/widgets/bottom_nav_bar.dart';

class GuardianHomePage extends StatefulWidget {
  const GuardianHomePage({Key? key}) : super(key: key);

  @override
  _GuardianHomePageState createState() => _GuardianHomePageState();
}

class _GuardianHomePageState extends State<GuardianHomePage> {
  final int initialDays = 14;
  late DateTime _startDate;
  DateTime? _selectedDate;
  final ScrollController _dateScrollController = ScrollController();
  List<String> _patientIds = [];
  String? _selectedPatientId;

  @override
  void initState() {
    super.initState();
    _startDate = DateTime.now();
    _selectedDate = _startDate;
    _loadLinkedPatients();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
  }

  void _loadLinkedPatients() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('guardians')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        setState(() {
          _patientIds = List<String>.from(doc.data()!['patients'] ?? []);
          if (_patientIds.isNotEmpty) {
            _selectedPatientId = _patientIds.first;
          }
        });
      }
    }
  }

  void _scrollToSelected() {
    if (_selectedDate == null) return;
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

  String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<DateTime> _generateDates() =>
      List.generate(initialDays, (i) => _startDate.add(Duration(days: i)));

  Widget _buildPatientSelector(Size size) {
    return Container(
      height: size.height * 0.06,
      decoration: BoxDecoration(
        color: AppColor.secondary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedPatientId,
          icon: Icon(Icons.arrow_drop_down, color: AppColor.secondary),
          items: _patientIds.map((id) {
            return DropdownMenuItem<String>(
              value: id,
              child: FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('patient')
                    .doc(id)
                    .get(),
                builder: (context, snapshot) {
                  final name = snapshot.data?.get('name') ?? 'Patient';
                  return Text(
                    name,
                    style: TextStyle(
                      fontSize: size.width * 0.04,
                      color: AppColor.secondary,
                    ),
                  );
                },
              ),
            );
          }).toList(),
          onChanged: (value) => setState(() => _selectedPatientId = value),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColor.background,
      bottomNavigationBar: const BottomNavBarCustome(),
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: size.width * 0.04,
              vertical: size.height * 0.02,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(size),
                SizedBox(height: size.height * 0.02),
                if (_patientIds.isNotEmpty) _buildPatientSelector(size),
                SizedBox(height: size.height * 0.02),
                _buildDateSelector(size),
                SizedBox(height: size.height * 0.03),
                if (_selectedPatientId != null) _buildPatientDataSection(size),
                if (_patientIds.isEmpty)
                  Center(
                    child: Padding(
                      padding: EdgeInsets.all(size.height * 0.04),
                      child: Text(
                        'No patients linked to your account',
                        style: TextStyle(
                          fontSize: size.width * 0.045,
                          color: AppColor.secondary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Size size) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: size.height * 0.02),
      child: Text(
        getGreeting(),
        style: TextStyle(
          fontSize: size.width * 0.08,
          fontWeight: FontWeight.bold,
          color: AppColor.secondary,
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, Size size) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: size.height * 0.01),
      child: Text(
        title,
        style: TextStyle(
          fontSize: size.width * 0.05,
          fontWeight: FontWeight.bold,
          color: AppColor.secondary,
        ),
      ),
    );
  }

  Widget _buildDateSelector(Size size) {
    final dates = _generateDates();
    return SizedBox(
      height: size.height * 0.1,
      child: ListView.builder(
        controller: _dateScrollController,
        scrollDirection: Axis.horizontal,
        itemCount: dates.length,
        itemBuilder: (context, index) {
          final date = dates[index];
          final isSelected = isSameDay(date, _selectedDate!);
          return GestureDetector(
            onTap: () => setState(() => _selectedDate = date),
            child: Container(
              width: size.width * 0.22,
              margin: EdgeInsets.symmetric(horizontal: size.width * 0.01),
              decoration: BoxDecoration(
                color: isSelected ? AppColor.secondary : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColor.secondary),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat.E().format(date),
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppColor.secondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    DateFormat.d().format(date),
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppColor.secondary,
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

  Widget _buildPatientDataSection(Size size) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Medication Schedule', size),
        _buildMedicationStream(size),
        SizedBox(height: size.height * 0.03),
        _buildSectionTitle('Recent Logs', size),
        _buildLogStream(size),
      ],
    );
  }

  Widget _buildMedicationStream(Size size) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('patient')
          .doc(_selectedPatientId)
          .collection('Medications')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return _buildLoadingIndicator();
        return _buildMedicationList(snapshot.data!.docs, size);
      },
    );
  }

  Widget _buildLogStream(Size size) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('patient')
          .doc(_selectedPatientId)
          .collection('Logs')
          .orderBy('timestamp', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return _buildLoadingIndicator();
        return _buildLogList(snapshot.data!.docs, size);
      },
    );
  }

  Widget _buildMedicationList(List<QueryDocumentSnapshot> docs, Size size) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: docs.length,
      itemBuilder: (ctx, i) {
        final med = docs[i].data() as Map<String, dynamic>;
        return _buildMedicationItem(med, size);
      },
    );
  }

  Widget _buildLogList(List<QueryDocumentSnapshot> docs, Size size) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: docs.length,
      itemBuilder: (ctx, i) {
        final log = docs[i].data() as Map<String, dynamic>;
        return _buildLogItem(log, size);
      },
    );
  }

  Widget _buildLoadingIndicator() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildLogItem(Map<String, dynamic> log, Size size) {
    return ListTile(
      title: Text(log['title'] ?? 'No Title'),
      subtitle:
          Text(DateFormat.yMMMd().add_jm().format(log['timestamp'].toDate())),
    );
  }

  Widget _buildMedicationItem(Map<String, dynamic> med, Size size) {
    return ListTile(
      title: Text(med['name'] ?? 'No Name'),
      subtitle: Text('Dosage: ${med['dosage'] ?? 'N/A'}'),
    );
  }
}

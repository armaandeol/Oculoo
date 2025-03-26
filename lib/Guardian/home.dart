import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:oculoo02/Guardian/notifications_page.dart';
import 'package:oculoo02/presentation/auth/sign_in.dart';

class AppColors {
  static const Color primary = Color(0xFF6C5CE7);
  static const Color secondary = Color(0xFFA8A5E6);
  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color error = Color(0xFFE57373);
  static const Color textPrimary = Color(0xFF2D3436);
  static const Color textSecondary = Color(0xFF636E72);
}

class GuardianHomePage extends StatefulWidget {
  const GuardianHomePage({Key? key}) : super(key: key);

  @override
  _GuardianHomePageState createState() => _GuardianHomePageState();
}

class _GuardianHomePageState extends State<GuardianHomePage> {
  List<String> _patientIds = [];
  bool _isLoading = true;
  // Add a badge counter for notifications
  int _notificationCount = 0;

  @override
  void initState() {
    super.initState();
    _loadLinkedPatients();
    _checkNotifications(); // Add this to check notifications on init
  }

  // Add this method to check for pending notifications
  Future<void> _checkNotifications() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('linkages')
          .where('guardianUID', isEqualTo: user.uid)
          .where('status', isEqualTo: 'pending')
          .get();

      setState(() {
        _notificationCount = snapshot.docs.length;
      });
    } catch (e) {
      print("Error checking notifications: $e");
    }
  }

  Future<void> _loadLinkedPatients() async {
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('guardian')
          .doc(user.uid)
          .collection('listing')
          .orderBy('timestamp', descending: true) // Sort by newest first
          .get();

      final ids = snapshot.docs
          .map((doc) => (doc.data() as Map<String, dynamic>)['uid']?.toString())
          .where((uid) => uid != null)
          .cast<String>()
          .toList();

      setState(() {
        _patientIds = ids;
        _isLoading = false;
      });

      // Check notifications after loading patients
      _checkNotifications();
    } catch (e) {
      print("Error loading patients: $e");
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
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          _isLoading
              ? SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()))
              : _patientIds.isEmpty
                  ? _buildEmptyState()
                  : _buildPatientList(),
        ],
      ),
      // Add a floating action button with a bell icon
      floatingActionButton: Stack(
        children: [
          FloatingActionButton(
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => NotificationsPage())).then((result) {
              // Refresh the patient list if returned value is true
              if (result == true) {
                _loadLinkedPatients();
              } else {
                _checkNotifications();
              }
            }),
            backgroundColor: AppColors.primary,
            child: Icon(Icons.notifications, color: Colors.white),
            tooltip: 'Notifications',
          ),
          if (_notificationCount > 0)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                constraints: BoxConstraints(
                  minWidth: 18,
                  minHeight: 18,
                ),
                child: Center(
                  child: Text(
                    _notificationCount.toString(),
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Add an empty state widget
  Widget _buildEmptyState() {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_off, size: 64, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text('No patients linked yet',
                style: TextStyle(fontSize: 18, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Text(
              'Accept patient requests in notifications',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: Icon(Icons.notifications_active),
              label: Text('Check Notifications'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => NotificationsPage()))
                  .then((_) => _loadLinkedPatients()),
            ),
          ],
        ),
      ),
    );
  }

  // Build the patient list
  Widget _buildPatientList() {
    return SliverPadding(
      padding: const EdgeInsets.all(16.0),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index == 0) {
              // Header
              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Row(
                  children: [
                    Icon(Icons.people, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text(
                      'Your Patients',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              );
            }
            return _PatientCard(patientId: _patientIds[index - 1]);
          },
          childCount: _patientIds.length + 1, // +1 for the header
        ),
      ),
    );
  }

  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 200,
      flexibleSpace: FlexibleSpaceBar(
        title: Text('Guardian Dashboard',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildUserInfo(),
                  const SizedBox(height: 20),
                  Text('${_patientIds.length} Patients Linked',
                      style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),
          ),
        ),
      ),
      pinned: true,
      actions: [
        IconButton(
          icon: Icon(Icons.notifications, color: Colors.white),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => NotificationsPage()),
          ).then((_) => _checkNotifications()),
          tooltip: 'View Requests',
        ),
        IconButton(
          icon: Icon(Icons.refresh, color: Colors.white),
          onPressed: _loadLinkedPatients,
        ),
        _buildLogoutButton(),
      ],
    );
  }

  Widget _buildUserInfo() {
    final user = FirebaseAuth.instance.currentUser;
    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundImage:
              user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
          child: user?.photoURL == null
              ? Icon(Icons.person, color: Colors.white)
              : null,
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user?.displayName ?? 'Guardian',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            Text(user?.email ?? '',
                style: TextStyle(color: Colors.white70, fontSize: 14)),
          ],
        ),
      ],
    );
  }

  Widget _buildLogoutButton() {
    return PopupMenuButton(
      icon: Icon(Icons.more_vert, color: Colors.white),
      itemBuilder: (context) => [
        PopupMenuItem(
          child: ListTile(
            leading: Icon(Icons.logout, color: AppColors.textPrimary),
            title: Text('Logout'),
            onTap: _logout,
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          // If it's the first item and we have notifications, show notification card
          if (index == 0 && _notificationCount > 0) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                color: AppColors.primary.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                  side: BorderSide(color: AppColors.primary, width: 1),
                ),
                child: InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => NotificationsPage()),
                  ).then((_) => _checkNotifications()),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.notifications_active,
                              color: Colors.white),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'New Requests',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                              Text(
                                'You have $_notificationCount new patient connection requests',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios, color: AppColors.primary),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }

          // If it's the header for the patient list
          if (index == (_notificationCount > 0 ? 1 : 0)) {
            return Padding(
              padding:
                  const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0),
              child: Text(
                'Your Patients',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            );
          }

          // Adjust the index for the patient list
          final adjustedIndex = index - (_notificationCount > 0 ? 2 : 1);

          if (adjustedIndex < 0) return SizedBox.shrink();
          if (adjustedIndex >= _patientIds.length) return SizedBox.shrink();

          // Return patient cards
          return Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: _PatientCard(patientId: _patientIds[adjustedIndex]),
          );
        },
        childCount: (_patientIds.isEmpty ? 1 : _patientIds.length + 1) +
            (_notificationCount > 0 ? 1 : 0),
      ),
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
        final lastMedication = data['lastMedication'] ?? 'N/A';

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 2,
          child: InkWell(
            borderRadius: BorderRadius.circular(15),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PatientDetailPage(
                  patientId: patientId,
                  patientName: name,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.person_outline, color: AppColors.primary),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary)),
                        const SizedBox(height: 4),
                        Text('Last medication: $lastMedication',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: AppColors.textSecondary),
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildDatePicker() {
    final dates =
        List.generate(7, (i) => DateTime.now().add(Duration(days: i - 3)));

    return SizedBox(
      height: 100,
      child: ListView.builder(
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
              width: 60,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat.E().format(date),
                    style: TextStyle(
                      color:
                          isSelected ? Colors.white : AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat.d().format(date),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : AppColors.textPrimary,
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
    // Get the day name of the selected date
    final selectedDayName = DateFormat('EEEE').format(_selectedDate);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('patient')
          .doc(widget.patientId)
          .collection('Medications')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        // Filter medications based on the selected day
        final allMeds = snapshot.data!.docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .toList();

        // Filter medications for the selected day
        final filteredMeds = allMeds.where((med) {
          // If no days specified, show medication every day
          if (med['days'] == null) return true;

          // Check if the medication is scheduled for the selected day
          final List<dynamic> days = med['days'] as List<dynamic>;
          return days.contains(selectedDayName);
        }).toList();

        if (filteredMeds.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.medication_outlined,
                    size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No medications for ${DateFormat('EEEE').format(_selectedDate)}',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: filteredMeds.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (ctx, i) {
            final med = filteredMeds[i];

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.medication, color: AppColors.primary),
                ),
                title: Text(med['pillName'] ?? 'Unknown',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text('${med['dosage'] ?? ""} ${med['unit'] ?? ""}',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                    if (med['times'] != null)
                      Text('Time: ${(med['times'] as List).join(', ')}',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                    // if (med['days'] != null)
                    //   Text('Days: ${(med['days'] as List).join(', ')}',
                    //       style: TextStyle(
                    //           fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
                trailing: Builder(
                  builder: (context) {
                    // Get medication times from the data
                    final List<dynamic>? timesList = med['times'];

                    if (timesList == null || timesList.isEmpty) {
                      return Chip(
                        label: Text('No times',
                            style:
                                TextStyle(color: Colors.white, fontSize: 12)),
                        backgroundColor: Colors.grey,
                      );
                    }

                    // Check if the selected date is today
                    final now = DateTime.now();
                    final isToday = _selectedDate.year == now.year &&
                        _selectedDate.month == now.month &&
                        _selectedDate.day == now.day;

                    // If not today, we show all times without "missed" or "in X minutes" status
                    if (!isToday) {
                      return Chip(
                        label: Text('${timesList.length} times',
                            style:
                                TextStyle(color: Colors.white, fontSize: 12)),
                        backgroundColor: AppColors.primary,
                      );
                    }

                    // For today, show the next medication time
                    final today = DateTime(now.year, now.month, now.day);

                    // Parse times (assuming format like "08:00")
                    List<DateTime> timesAsDateTime = [];
                    for (String time in timesList.cast<String>()) {
                      try {
                        final parts = time.split(':');
                        if (parts.length == 2) {
                          final hour = int.tryParse(parts[0]) ?? 0;
                          final minute = int.tryParse(parts[1]) ?? 0;
                          timesAsDateTime.add(today
                              .add(Duration(hours: hour, minutes: minute)));
                        }
                      } catch (e) {
                        print('Error parsing time $time: $e');
                      }
                    }

                    // Sort times
                    timesAsDateTime.sort();

                    // Find the next time (first time greater than now)
                    DateTime? nextTime;
                    for (final time in timesAsDateTime) {
                      if (time.isAfter(now)) {
                        nextTime = time;
                        break;
                      }
                    }

                    // If no next time today, use the first time (for tomorrow)
                    nextTime ??= timesAsDateTime.isNotEmpty
                        ? timesAsDateTime.first.add(Duration(days: 1))
                        : null;

                    if (nextTime == null) {
                      return Chip(
                        label: Text('No times',
                            style:
                                TextStyle(color: Colors.white, fontSize: 12)),
                        backgroundColor: Colors.grey,
                      );
                    }

                    // Calculate difference in minutes
                    final diff = nextTime.difference(now);
                    final minutes = diff.inMinutes;

                    // Format the difference text
                    String timeText;
                    Color chipColor;

                    if (minutes < 0) {
                      timeText = 'Missed';
                      chipColor = Colors.red;
                    } else if (minutes < 60) {
                      timeText = 'In ${minutes}m';
                      chipColor =
                          minutes < 30 ? Colors.orange : AppColors.primary;
                    } else if (minutes < 24 * 60) {
                      final hours = (minutes / 60).floor();
                      timeText = 'In ${hours}h';
                      chipColor = AppColors.primary;
                    } else {
                      final days = (minutes / (24 * 60)).floor();
                      timeText = 'In ${days}d';
                      chipColor = AppColors.primary;
                    }

                    return Chip(
                      label: Text(timeText,
                          style: TextStyle(color: Colors.white, fontSize: 12)),
                      backgroundColor: chipColor,
                    );
                  },
                ),
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
        backgroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline, color: Colors.white),
            onPressed: () {}, // Add patient info dialog
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDatePicker(),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: AppColors.primary.withOpacity(0.1),
                    ),
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.textSecondary,
                    tabs: const [
                      Tab(text: 'Medications'),
                      Tab(text: 'Health Logs'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: _buildMedicationList(),
                ),
                _buildHealthLogs(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthLogs() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('patient')
          .doc(widget.patientId)
          .collection('Logs')
          .orderBy('timestamp', descending: true) // Newest first
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No health logs found',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  'Health data will appear here when the patient records it',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        // Filter logs for selected date
        final filteredLogs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['timestamp'] == null) return false;

          final timestamp = (data['timestamp'] as Timestamp).toDate();
          return timestamp.year == _selectedDate.year &&
              timestamp.month == _selectedDate.month &&
              timestamp.day == _selectedDate.day;
        }).toList();

        if (filteredLogs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_today, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No logs for ${DateFormat.yMMMd().format(_selectedDate)}',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: filteredLogs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (ctx, i) {
            final log = filteredLogs[i].data() as Map<String, dynamic>;
            final timestamp = (log['timestamp'] as Timestamp).toDate();

            // Define log type and icon
            IconData logIcon;
            Color iconColor;
            String logType = log['type'] ?? 'general';

            switch (logType.toLowerCase()) {
              case 'medication':
                logIcon = Icons.medication;
                iconColor = Colors.green.shade700;
                break;
              case 'symptom':
                logIcon = Icons.healing;
                iconColor = Colors.orange;
                break;
              case 'measurement':
                logIcon = Icons.monitor_heart;
                iconColor = Colors.red;
                break;
              default:
                logIcon = Icons.note_alt;
                iconColor = AppColors.primary;
            }

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(logIcon, color: iconColor),
                ),
                title: Text(
                  log['title'] ?? _getLogTitle(log, logType),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      DateFormat.jm().format(timestamp), // Show time only
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (log['notes'] != null)
                      Text(
                        log['notes'],
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
                onTap: () => _showLogDetails(log, timestamp),
              ),
            );
          },
        );
      },
    );
  }

// Helper method to generate a title for the log entry based on its content
  String _getLogTitle(Map<String, dynamic> log, String logType) {
    switch (logType.toLowerCase()) {
      case 'medication':
        return 'Medication taken: ${log['medicine'] ?? 'Unknown'}';
      case 'symptom':
        return 'Symptom recorded: ${log['symptom'] ?? 'Unknown'}';
      case 'measurement':
        if (log['measurement'] != null) {
          return '${log['measurement']}: ${log['value'] ?? ''} ${log['unit'] ?? ''}';
        }
        return 'Health measurement';
      default:
        return 'Health log entry';
    }
  }

// Show a dialog with detailed log information
  void _showLogDetails(Map<String, dynamic> log, DateTime timestamp) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(log['title'] ?? 'Health Log Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Time: ${DateFormat.yMMMd().add_jm().format(timestamp)}',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (log['medicine'] != null) ...[
                Text('Medicine: ${log['medicine']}'),
                const SizedBox(height: 4),
              ],
              if (log['dosage'] != null) ...[
                Text('Dosage: ${log['dosage']} ${log['unit'] ?? ''}'),
                const SizedBox(height: 4),
              ],
              if (log['symptom'] != null) ...[
                Text('Symptom: ${log['symptom']}'),
                const SizedBox(height: 4),
              ],
              if (log['severity'] != null) ...[
                Text('Severity: ${log['severity']}'),
                const SizedBox(height: 4),
              ],
              if (log['measurement'] != null) ...[
                Text('Measurement: ${log['measurement']}'),
                const SizedBox(height: 4),
              ],
              if (log['value'] != null) ...[
                Text('Value: ${log['value']} ${log['unit'] ?? ''}'),
                const SizedBox(height: 4),
              ],
              if (log['notes'] != null) ...[
                const Divider(),
                const SizedBox(height: 8),
                Text('Notes:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(log['notes']),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }
}

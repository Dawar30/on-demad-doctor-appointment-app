import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../features/auth/auth_screen.dart';

// ============================================================
//  DOCTOR DASHBOARD SCREEN
// ============================================================
class DoctorDashboardScreen extends StatefulWidget {
  const DoctorDashboardScreen({super.key});

  @override
  State<DoctorDashboardScreen> createState() => _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends State<DoctorDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final String? _userId = FirebaseAuth.instance.currentUser?.uid;
  String _doctorName = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDoctorName();
  }

  Future<void> _loadDoctorName() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_userId)
        .get();
    if (mounted && doc.exists) {
      setState(() {
        _doctorName = doc.data()?['name'] ?? '';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const RoleSelectionScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF0F4F8),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF1A6B8A)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A6B8A),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Doctor Dashboard',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              _doctorName,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Completed'),
            Tab(text: 'Cancelled'),
          ],
        ),
      ),
      body: _doctorName.isEmpty
          ? const Center(
              child: Text(
                'Doctor name not found',
                style: TextStyle(color: Colors.black38),
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildAppointmentsList('Upcoming'),
                _buildAppointmentsList('Completed'),
                _buildAppointmentsList('Cancelled'),
              ],
            ),
    );
  }

  // ---- Appointments List — sirf is doctor ki ----
  Widget _buildAppointmentsList(String status) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('doctorName', isEqualTo: _doctorName)
          .where('status', isEqualTo: status)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF1A6B8A)),
          );
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Something went wrong'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.calendar_today_outlined,
                    size: 60, color: Colors.black26),
                SizedBox(height: 16),
                Text(
                  'No appointments found',
                  style: TextStyle(color: Colors.black38, fontSize: 15),
                ),
              ],
            ),
          );
        }

        final docs = snapshot.data!.docs;

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final docId = docs[index].id;
            return _DoctorAppointmentCard(
              docId: docId,
              data: data,
              status: status,
            );
          },
        );
      },
    );
  }
}

// ============================================================
//  APPOINTMENT CARD FOR DOCTOR
// ============================================================
class _DoctorAppointmentCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final String status;

  const _DoctorAppointmentCard({
    required this.docId,
    required this.data,
    required this.status,
  });

  Future<void> _updateStatus(BuildContext context, String newStatus) async {
    await FirebaseFirestore.instance
        .collection('appointments')
        .doc(docId)
        .update({'status': newStatus});

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Appointment marked as $newStatus'),
          backgroundColor: const Color(0xFF1A6B8A),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ---- Patient Info ----
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2F1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.person,
                  color: Color(0xFF1A6B8A),
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['doctorName'] ?? 'Patient',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      data['specialty'] ?? '',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),

              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: status == 'Upcoming'
                      ? const Color(0xFFE0F2F1)
                      : status == 'Completed'
                          ? const Color(0xFFE8F5E9)
                          : const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: status == 'Upcoming'
                        ? const Color(0xFF1A6B8A)
                        : status == 'Completed'
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFE53E3E),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(color: Colors.black12, height: 1),
          const SizedBox(height: 12),

          // ---- Date + Time + Type ----
          Row(
            children: [
              _infoItem(
                  Icons.calendar_today_outlined, data['date'] ?? ''),
              const SizedBox(width: 16),
              _infoItem(
                  Icons.access_time_outlined, data['time'] ?? ''),
            ],
          ),
          const SizedBox(height: 6),
          _infoItem(
            data['type'] == 'Telehealth'
                ? Icons.videocam_outlined
                : Icons.location_on_outlined,
            data['type'] ?? '',
          ),

          // ---- Notes ----
          if ((data['notes'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.notes_outlined,
                    size: 14, color: Color(0xFF1A6B8A)),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    data['notes'] ?? '',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 14),

          // ---- Action Buttons ----
          if (status == 'Upcoming')
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _updateStatus(context, 'Cancelled'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE53E3E)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: Color(0xFFE53E3E),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _updateStatus(context, 'Completed'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Mark Complete',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _infoItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF1A6B8A)),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black54,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ============================================================
//  APPOINTMENT MODEL
// ============================================================
class Appointment {
  final String id;
  final String doctorName;
  final String specialty;
  final String date;
  final String time;
  final String type;
  final String status;
  final double? userRating;

  const Appointment({
    required this.id,
    required this.doctorName,
    required this.specialty,
    required this.date,
    required this.time,
    required this.type,
    required this.status,
    this.userRating,
  });

  factory Appointment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Appointment(
      id: doc.id,
      doctorName: data['doctorName'] ?? '',
      specialty: data['specialty'] ?? '',
      date: data['date'] ?? '',
      time: data['time'] ?? '',
      type: data['type'] ?? '',
      status: data['status'] ?? 'Upcoming',
      userRating: (data['userRating'] ?? 0).toDouble(),
    );
  }
}

// ============================================================
//  APPOINTMENTS SCREEN
// ============================================================
class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final String? _userId = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF0F4F8),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My Appointments',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF1A6B8A),
          unselectedLabelColor: Colors.black45,
          indicatorColor: const Color(0xFF1A6B8A),
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
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFirestoreList('Upcoming'),
          _buildFirestoreList('Completed'),
          _buildFirestoreList('Cancelled'),
        ],
      ),
    );
  }

  Widget _buildFirestoreList(String status) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('userId', isEqualTo: _userId)
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

        final appointments = snapshot.data!.docs
            .map((doc) => Appointment.fromFirestore(doc))
            .toList();

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: appointments.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            return _AppointmentCard(appointment: appointments[index]);
          },
        );
      },
    );
  }
}

// ============================================================
//  APPOINTMENT CARD
// ============================================================
class _AppointmentCard extends StatelessWidget {
  final Appointment appointment;

  const _AppointmentCard({required this.appointment});

  Color _statusColor() {
    switch (appointment.status) {
      case 'Upcoming':  return const Color(0xFF1A6B8A);
      case 'Completed': return const Color(0xFF2E7D32);
      case 'Cancelled': return const Color(0xFFE53E3E);
      default:          return Colors.grey;
    }
  }

  Color _statusBgColor() {
    switch (appointment.status) {
      case 'Upcoming':  return const Color(0xFFE0F2F1);
      case 'Completed': return const Color(0xFFE8F5E9);
      case 'Cancelled': return const Color(0xFFFFEBEE);
      default:          return Colors.grey.shade100;
    }
  }

  Future<void> _cancelAppointment(BuildContext context) async {
    await FirebaseFirestore.instance
        .collection('appointments')
        .doc(appointment.id)
        .update({'status': 'Cancelled'});

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Appointment cancelled'),
          backgroundColor: Color(0xFFE53E3E),
        ),
      );
    }
  }

  // ---- Rate Doctor Dialog ----
  void _showRatingDialog(BuildContext context) {
    double _selectedRating = appointment.userRating ?? 0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title
                const Text(
                  'Rate Your Doctor',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  appointment.doctorName,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black45,
                  ),
                ),
                const SizedBox(height: 24),

                // Stars
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return GestureDetector(
                      onTap: () {
                        setDialogState(() {
                          _selectedRating = index + 1.0;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          index < _selectedRating
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: const Color(0xFFF59E0B),
                          size: 40,
                        ),
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 8),

                // Rating Text
                Text(
                  _selectedRating == 0
                      ? 'Tap a star to rate'
                      : _selectedRating == 1
                          ? 'Poor'
                          : _selectedRating == 2
                              ? 'Fair'
                              : _selectedRating == 3
                                  ? 'Good'
                                  : _selectedRating == 4
                                      ? 'Very Good'
                                      : 'Excellent!',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _selectedRating == 0
                        ? Colors.black38
                        : const Color(0xFFF59E0B),
                  ),
                ),

                const SizedBox(height: 24),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _selectedRating == 0
                        ? null
                        : () async {
                            // Save rating to appointment
                            await FirebaseFirestore.instance
                                .collection('appointments')
                                .doc(appointment.id)
                                .update({'userRating': _selectedRating});

                            // Update doctor average rating
                            final doctorQuery = await FirebaseFirestore
                                .instance
                                .collection('doctors')
                                .where('name',
                                    isEqualTo: appointment.doctorName)
                                .get();

                            if (doctorQuery.docs.isNotEmpty) {
                              await doctorQuery.docs.first.reference
                                  .update({'rating': _selectedRating});
                            }

                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Thank you for your rating!'),
                                  backgroundColor: Color(0xFF2E7D32),
                                ),
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A6B8A),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.black12,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Submit Rating',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
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

          // ---- Top Row ----
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2F1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.person,
                  color: Color(0xFF1A6B8A),
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appointment.doctorName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      appointment.specialty,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.black45),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusBgColor(),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  appointment.status,
                  style: TextStyle(
                    color: _statusColor(),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(color: Colors.black12, height: 1),
          const SizedBox(height: 14),

          // ---- Date + Time ----
          Row(
            children: [
              _infoItem(Icons.calendar_today_outlined, appointment.date),
              const SizedBox(width: 16),
              _infoItem(Icons.access_time_outlined, appointment.time),
            ],
          ),
          const SizedBox(height: 8),
          _infoItem(
            appointment.type == 'Telehealth'
                ? Icons.videocam_outlined
                : Icons.location_on_outlined,
            appointment.type,
          ),

          const SizedBox(height: 14),

          // ---- Buttons ----
          if (appointment.status == 'Upcoming')
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _cancelAppointment(context),
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
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A6B8A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Reschedule',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),

          if (appointment.status == 'Completed')
            Column(
              children: [
                // Show stars if already rated
                if ((appointment.userRating ?? 0) > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Your Rating: ',
                          style: TextStyle(
                              fontSize: 13, color: Colors.black45),
                        ),
                        Row(
                          children: List.generate(5, (index) {
                            return Icon(
                              index < (appointment.userRating ?? 0)
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: const Color(0xFFF59E0B),
                              size: 18,
                            );
                          }),
                        ),
                      ],
                    ),
                  ),

                Row(
                  children: [
                    // Rate Doctor Button
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showRatingDialog(context),
                        icon: const Icon(
                          Icons.star_outline,
                          color: Color(0xFFF59E0B),
                          size: 16,
                        ),
                        label: Text(
                          (appointment.userRating ?? 0) > 0
                              ? 'Change Rating'
                              : 'Rate Doctor',
                          style: const TextStyle(
                            color: Color(0xFFF59E0B),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFF59E0B)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Book Again Button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A6B8A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Book Again',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
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

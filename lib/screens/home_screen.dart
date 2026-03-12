import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/event_model.dart';
import '../services/event_service.dart';
import '../services/registration_service.dart';
import 'add_event_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final currentEmail = FirebaseAuth.instance.currentUser?.email ?? '';
    final eventService = EventService();
    final registrationService = RegistrationService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event App'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
            return const Center(
              child: Text('Kullanıcı verisi bulunamadı.'),
            );
          }

          final userData = userSnapshot.data!.data()!;
          final fullName = userData['fullName'] ?? '';
          final email = userData['email'] ?? currentEmail;
          final role = userData['role'] ?? 'user';
          final department = userData['department'] ?? '';
          final userType = userData['userType'] ?? '';
          final faculty = userData['faculty'] ?? '';
          final grade = userData['grade'] ?? '';

          final canCreate = role == 'admin' || role == 'moderator';

          return Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF7E57C2),
                            Color(0xFF5E35B1),
                          ],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Hoş geldin',
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            fullName.isEmpty ? 'Kullanıcı' : fullName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Rol: $role',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Profil Bilgileri',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _InfoRow(title: 'Email', value: email),
                            _InfoRow(title: 'Fakülte', value: faculty),
                            _InfoRow(title: 'Bölüm', value: department),
                            _InfoRow(title: 'Tür', value: userType),
                            _InfoRow(title: 'Sınıf', value: grade),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Etkinlikler',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    StreamBuilder<List<EventModel>>(
                      stream: eventService.getEvents(),
                      builder: (context, eventSnapshot) {
                        if (eventSnapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final events = eventSnapshot.data ?? [];

                        if (events.isEmpty) {
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'Henüz etkinlik yok',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    'İlk etkinliği yetkili bir kullanıcı eklediğinde burada görünecek.',
                                    style: TextStyle(color: Colors.black54),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return Column(
                          children: events.map((event) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _EventCard(
                                event: event,
                                currentUserId: uid,
                                currentUserName: fullName,
                                currentUserEmail: email,
                                registrationService: registrationService,
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
              if (canCreate)
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton.extended(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddEventScreen(role: role),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Etkinlik Ekle'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String title;
  final String value;

  const _InfoRow({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 85,
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventCard extends StatefulWidget {
  final EventModel event;
  final String currentUserId;
  final String currentUserName;
  final String currentUserEmail;
  final RegistrationService registrationService;

  const _EventCard({
    required this.event,
    required this.currentUserId,
    required this.currentUserName,
    required this.currentUserEmail,
    required this.registrationService,
  });

  @override
  State<_EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<_EventCard> {
  bool _joining = false;

  Future<void> _joinEvent() async {
    setState(() => _joining = true);

    try {
      await widget.registrationService.joinEvent(
        eventId: widget.event.id,
        userId: widget.currentUserId,
        userName: widget.currentUserName,
        userEmail: widget.currentUserEmail,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Etkinliğe katıldın.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _joining = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.event.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.event.description,
              style: const TextStyle(
                color: Colors.black87,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Text('Konum: ${widget.event.location}'),
            Text('Tarih: ${widget.event.date}'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFF1EBFF),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Oluşturan rol: ${widget.event.createdByRole}',
                style: const TextStyle(
                  color: Colors.deepPurple,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 14),
            StreamBuilder<bool>(
              stream: widget.registrationService.isJoined(
                eventId: widget.event.id,
                userId: widget.currentUserId,
              ),
              builder: (context, snapshot) {
                final joined = snapshot.data ?? false;

                if (joined) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE9F7EF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Text(
                        'Bu etkinliğe katıldın',
                        style: TextStyle(
                          color: Color(0xFF1E7D4D),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  );
                }

                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _joining ? null : _joinEvent,
                    child: _joining
                        ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Text('Etkinliğe Katıl'),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

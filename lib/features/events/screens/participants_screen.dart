import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/event_model.dart';
import '../services/registration_service.dart';

class ParticipantsScreen extends StatelessWidget {
  final EventModel event;
  final RegistrationService registrationService;

  const ParticipantsScreen({
    super.key,
    required this.event,
    required this.registrationService,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F2ED),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: const Text('Katılımcı Listesi'),
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: registrationService.getRegistrationsForEvent(
            eventId: event.id,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final registrations = [...?snapshot.data?.docs]
              ..sort((a, b) {
                final aChecked = a.data()['checkedIn'] == true ? 1 : 0;
                final bChecked = b.data()['checkedIn'] == true ? 1 : 0;
                return bChecked.compareTo(aChecked);
              });

            final checkedInCount = registrations.where((doc) {
              return doc.data()['checkedIn'] == true;
            }).length;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.95),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${registrations.length} katılımcı • $checkedInCount okutuldu',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (registrations.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Text(
                      'Henüz katılımcı yok.',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else
                  ...registrations.map((doc) {
                    final data = doc.data();
                    final userName = (data['userName'] ?? 'Katılımcı')
                        .toString();
                    final userEmail = (data['userEmail'] ?? '').toString();
                    final checkedIn = data['checkedIn'] == true;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: checkedIn
                              ? const Color(0xFFBBF7D0)
                              : Colors.white.withValues(alpha: 0.95),
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: checkedIn
                                ? const Color(0xFFDCFCE7)
                                : const Color(0xFFE0F2FE),
                            child: Icon(
                              checkedIn
                                  ? Icons.verified_rounded
                                  : Icons.person_outline_rounded,
                              color: checkedIn
                                  ? const Color(0xFF15803D)
                                  : const Color(0xFF0369A1),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  userEmail.isEmpty ? 'E-posta yok' : userEmail,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: checkedIn
                                  ? const Color(0xFFDCFCE7)
                                  : const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              checkedIn ? 'Okutuldu' : 'Bekliyor',
                              style: TextStyle(
                                color: checkedIn
                                    ? const Color(0xFF166534)
                                    : const Color(0xFF475569),
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../qr/screens/qr_ticket_screen.dart';
import '../models/event_model.dart';
import '../services/event_service.dart';
import '../services/registration_service.dart';

class NotificationsScreen extends StatelessWidget {
  final String currentUserId;

  const NotificationsScreen({super.key, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    final registrationService = RegistrationService();
    final eventService = EventService();
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Bildirimler')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: registrationService.getMyRegistrations(userId: currentUserId),
        builder: (context, registrationSnapshot) {
          if (registrationSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final registrations = registrationSnapshot.data?.docs ?? const [];

          return StreamBuilder<List<EventModel>>(
            stream: eventService.getEvents(),
            initialData: const <EventModel>[],
            builder: (context, eventSnapshot) {
              final events = eventSnapshot.data ?? const <EventModel>[];
              final eventById = {for (final event in events) event.id: event};
              final joinedEventIds = <String>{};
              final items = <_NotificationItem>[];

              for (final regDoc in registrations) {
                final reg = regDoc.data();
                final eventId = (reg['eventId'] ?? '').toString();
                if (eventId.isEmpty) {
                  continue;
                }

                joinedEventIds.add(eventId);
                final event = eventById[eventId];
                final eventTitle = event?.title ?? 'Etkinlik';
                final checkedIn = reg['checkedIn'] == true;
                final joinedAt = reg['joinedAt'];
                final joinedAtDate = joinedAt is Timestamp
                    ? joinedAt.toDate()
                    : null;
                final ticketOwnerName = (reg['userName'] ?? 'Kullanıcı')
                    .toString();

                items.add(
                  _NotificationItem(
                    icon: checkedIn
                        ? Icons.verified_rounded
                        : Icons.qr_code_2_rounded,
                    iconColor: checkedIn
                        ? const Color(0xFF0F766E)
                        : const Color(0xFF2563EB),
                    title: checkedIn ? 'Giriş onaylandı' : 'Biletin hazır',
                    message: checkedIn
                        ? '$eventTitle için girişin başarıyla tamamlandı.'
                        : '$eventTitle bileti oluşturuldu. Girişte QR okutabilirsin.',
                    timeLabel: _formatDateTime(joinedAtDate),
                    onTap: checkedIn
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => QrTicketScreen(
                                  eventId: eventId,
                                  eventTitle: eventTitle,
                                  userId: currentUserId,
                                  userName: ticketOwnerName,
                                ),
                              ),
                            );
                          },
                  ),
                );
              }

              for (final event in events.take(10)) {
                if (joinedEventIds.contains(event.id)) {
                  continue;
                }

                items.add(
                  _NotificationItem(
                    icon: Icons.event_available_rounded,
                    iconColor: const Color(0xFF7C3AED),
                    title: 'Yeni etkinlik',
                    message: '${event.title} • ${event.date}',
                    timeLabel: 'Keşfet',
                  ),
                );
              }

              if (items.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Henüz bildirimin yok.',
                      textAlign: TextAlign.center,
                      style: textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                itemCount: items.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final tile = Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: item.iconColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            item.icon,
                            color: item.iconColor,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                item.message,
                                style: const TextStyle(
                                  color: Color(0xFF475569),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                item.timeLabel,
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (item.onTap != null)
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: Color(0xFF94A3B8),
                          ),
                      ],
                    ),
                  );

                  if (item.onTap == null) {
                    return tile;
                  }

                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: item.onTap,
                    child: tile,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _NotificationItem {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final String timeLabel;
  final VoidCallback? onTap;

  const _NotificationItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.timeLabel,
    this.onTap,
  });
}

String _formatDateTime(DateTime? value) {
  if (value == null) {
    return 'Şimdi';
  }

  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(value.day)}.${two(value.month)}.${value.year} ${two(value.hour)}:${two(value.minute)}';
}

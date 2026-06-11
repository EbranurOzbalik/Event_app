import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../events/services/registration_service.dart';

class QrTicketScreen extends StatelessWidget {
  final String eventId;
  final String eventTitle;
  final String userId;
  final String userName;

  const QrTicketScreen({
    super.key,
    required this.eventId,
    required this.eventTitle,
    required this.userId,
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    final registrationService = RegistrationService();
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Stack(
        children: [
          Container(color: const Color(0xFFF5F2ED)),
          Positioned(
            top: -120,
            right: -70,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF0F766E).withValues(alpha: 0.22),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton.filledTonal(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'QR Biletin Hazır',
                    style: textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Girişte görevliye bu kodu okutman yeterli.',
                    style: textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFF6B635A),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<String>(
                    future: registrationService.getOrCreateTicketCode(
                      eventId: eventId,
                      userId: userId,
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final ticketCode =
                          snapshot.data ??
                          registrationService.buildLegacyTicketCode(
                            eventId: eventId,
                            userId: userId,
                          );

                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                          child: Column(
                            children: [
                              Text(
                                eventTitle,
                                textAlign: TextAlign.center,
                                style: textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                userName.isEmpty ? 'Katılımcı' : userName,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFF6B635A),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 18),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: const Color(0xFFE6DFD5),
                                  ),
                                ),
                                child: QrImageView(
                                  data: ticketCode,
                                  size: 230,
                                  eyeStyle: const QrEyeStyle(
                                    eyeShape: QrEyeShape.square,
                                    color: Color(0xFF1F1B17),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEBF6F3),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Bu kod tek kullanımlık check-in için okunur.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Color(0xFF0E6D50),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              SelectableText(
                                ticketCode,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF7A726A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

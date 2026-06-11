import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../events/services/registration_service.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final _registrationService = RegistrationService();
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    detectionTimeoutMs: 450,
  );
  final _manualCodeController = TextEditingController();

  bool _processing = false;
  String? _lastCode;
  DateTime? _lastScanAt;

  Future<void> _handleCode(String rawCode) async {
    if (_processing) return;
    setState(() => _processing = true);

    try {
      await _controller.stop();

      final result = await _registrationService.checkInWithTicketCode(
        ticketCode: rawCode,
      );

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Giriş Onaylandı'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result['userName']?.isEmpty == true
                      ? 'Katılımcı'
                      : result['userName'] ?? 'Katılımcı',
                ),
                const SizedBox(height: 4),
                Text(result['userEmail'] ?? ''),
                const SizedBox(height: 8),
                Text(
                  'Etkinlik ID: ${result['eventId'] ?? '-'}',
                  style: const TextStyle(
                    color: Color(0xFF6E675F),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Tamam'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
      await _safeRestartScanner();
    }
  }

  Future<void> _safeRestartScanner() async {
    if (!mounted) return;
    try {
      await _controller.start();
    } catch (_) {}
  }

  bool _isDuplicateWithinCooldown(String code) {
    final now = DateTime.now();
    final lastCode = _lastCode;
    final lastScanAt = _lastScanAt;

    _lastCode = code;
    _lastScanAt = now;

    if (lastCode == null || lastScanAt == null) {
      return false;
    }

    final elapsedMs = now.difference(lastScanAt).inMilliseconds;
    return lastCode == code && elapsedMs < 1200;
  }

  String? _extractCode(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue?.trim();
      if (raw != null && raw.isNotEmpty) {
        return raw;
      }

      final display = barcode.displayValue?.trim();
      if (display != null && display.isNotEmpty) {
        return display;
      }

      final decodedBytes = barcode.rawDecodedBytes;
      if (decodedBytes case DecodedBarcodeBytes(:final bytes)) {
        final decoded = utf8.decode(bytes, allowMalformed: true).trim();
        if (decoded.isNotEmpty) {
          return decoded;
        }
      }

      if (decodedBytes case DecodedVisionBarcodeBytes(
        :final bytes,
        :final rawBytes,
      )) {
        final payload = bytes ?? rawBytes;
        if (payload.isNotEmpty) {
          final decoded = utf8.decode(payload, allowMalformed: true).trim();
          if (decoded.isNotEmpty) {
            return decoded;
          }
        }
      }
    }

    return null;
  }

  void _onDetect(BarcodeCapture capture) {
    if (_processing) return;

    final code = _extractCode(capture);
    if (code == null) return;
    if (_isDuplicateWithinCooldown(code)) return;

    _handleCode(code);
  }

  Future<void> _openManualCodeSheet() async {
    final pasted = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF7F4EF),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            14,
            16,
            MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bilet Kodunu Yapıştır',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Simülatörde QR yerine ticket kodunu manuel test edebilirsin.',
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _manualCodeController,
                maxLines: 3,
                minLines: 1,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText: 'event_ticket:eventId_userId',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: Color(0xFF0F766E),
                      width: 1.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    final value = _manualCodeController.text.trim();
                    if (value.isEmpty) {
                      return;
                    }
                    Navigator.pop(context, value);
                  },
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Kodu Doğrula'),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted) {
      return;
    }

    if (pasted == null || pasted.trim().isEmpty) {
      return;
    }

    await _handleCode(pasted.trim());
  }

  @override
  void dispose() {
    _manualCodeController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton.filledTonal(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_rounded),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.35),
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Text(
                            'Kamerayı bilet QR koduna hizala',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.filledTonal(
                        onPressed: _processing ? null : _openManualCodeSheet,
                        icon: const Icon(Icons.keyboard_alt_rounded),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.35),
                          foregroundColor: Colors.white,
                        ),
                        tooltip: 'Elle kod gir',
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.9),
                        width: 3,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'Kod okununca check-in otomatik tamamlanır. Simülatörde sağ üstten kodu elle girerek test edebilirsin.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_processing)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.45),
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class PhoneVerificationScreen extends StatefulWidget {
  final String initialPhone;
  final bool alreadyVerified;

  const PhoneVerificationScreen({
    super.key,
    required this.initialPhone,
    required this.alreadyVerified,
  });

  @override
  State<PhoneVerificationScreen> createState() =>
      _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends State<PhoneVerificationScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();

  bool _sendingCode = false;
  bool _verifying = false;
  bool _codeSent = false;
  String? _verificationId;
  int? _resendToken;
  String _requestedPhoneE164 = '';

  @override
  void initState() {
    super.initState();
    _phoneController.text = widget.initialPhone;
    _configurePhoneAuthForDebug();
  }

  Future<void> _configurePhoneAuthForDebug() async {
    if (!kDebugMode) {
      return;
    }

    try {
      await FirebaseAuth.instance.setSettings(
        appVerificationDisabledForTesting: true,
      );
    } catch (_) {
      // No-op: bazı platformlarda bu ayarlar kısmen uygulanabilir.
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  String _toE164(String raw) {
    var value = raw.trim();
    value = value.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    if (value.startsWith('00')) {
      value = '+${value.substring(2)}';
    }

    if (value.startsWith('+')) {
      final digits = value.substring(1).replaceAll(RegExp(r'\D'), '');
      return digits.isEmpty ? '' : '+$digits';
    }

    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return '';
    }

    if (digits.length == 10) {
      return '+90$digits';
    }

    if (digits.length == 11 && digits.startsWith('0')) {
      return '+90${digits.substring(1)}';
    }

    if (digits.startsWith('90') && digits.length >= 11) {
      return '+$digits';
    }

    return '+$digits';
  }

  String _normalizeCode(String raw) {
    return raw.replaceAll(RegExp(r'\D'), '');
  }

  String _mapVerificationError(FirebaseAuthException e) {
    final raw = (e.message ?? '').toUpperCase();
    if (raw.contains('BILLING_NOT_ENABLED')) {
      return 'Gerçek SMS için Firebase projesinde faturalandırma (Blaze) açılmalı.';
    }

    switch (e.code) {
      case 'invalid-phone-number':
        return 'Telefon numarası geçersiz.';
      case 'too-many-requests':
        return 'Çok fazla deneme yapıldı. Biraz sonra tekrar dene.';
      case 'quota-exceeded':
        return 'SMS limiti aşıldı. Daha sonra tekrar dene.';
      case 'network-request-failed':
        return 'Ağ hatası. İnternet bağlantını kontrol et.';
      case 'app-not-authorized':
        return 'Uygulama telefon doğrulama için yetkili değil.';
      case 'captcha-check-failed':
        return 'Güvenlik doğrulaması başarısız. Tekrar dene.';
      case 'session-expired':
        return 'Kod süresi doldu. Tekrar kod iste.';
      case 'invalid-verification-code':
        return 'Doğrulama kodu hatalı.';
      case 'credential-already-in-use':
        return 'Bu telefon numarası başka bir hesapta kullanılıyor.';
      case 'provider-already-linked':
        return 'Telefon doğrulaması zaten bağlı.';
      case 'requires-recent-login':
        return 'Güvenlik için tekrar giriş yapıp yeniden dene.';
      case 'internal-error':
        return 'Doğrulama servisi iç hata verdi. Test numarası veya billing ayarını kontrol et.';
      default:
        return e.message ?? 'Telefon doğrulama sırasında hata oluştu.';
    }
  }

  String _withCode(String message, FirebaseAuthException e) {
    final code = e.code.trim();
    if (code.isEmpty) {
      return message;
    }
    return '$message (kod: $code)';
  }

  Future<void> _sendCode({required bool resend}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    final phoneE164 = _toE164(_phoneController.text);
    final valid = RegExp(r'^\+\d{10,15}$').hasMatch(phoneE164);
    if (!valid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Telefonu ülke koduyla doğru gir.')),
      );
      return;
    }

    setState(() {
      _sendingCode = true;
      if (!resend) {
        _codeSent = false;
        _verificationId = null;
        _codeController.clear();
      }
      _requestedPhoneE164 = phoneE164;
    });

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneE164,
        timeout: const Duration(seconds: 60),
        forceResendingToken: resend ? _resendToken : null,
        verificationCompleted: (credential) async {
          await _applyCredential(credential: credential, phoneE164: phoneE164);
        },
        verificationFailed: (e) {
          if (!mounted) {
            return;
          }

          setState(() => _sendingCode = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_withCode(_mapVerificationError(e), e))),
          );
        },
        codeSent: (verificationId, resendToken) {
          if (!mounted) {
            return;
          }

          setState(() {
            _sendingCode = false;
            _codeSent = true;
            _verificationId = verificationId;
            _resendToken = resendToken;
          });

          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('SMS kodu gönderildi.')));
        },
        codeAutoRetrievalTimeout: (verificationId) {
          _verificationId = verificationId;
        },
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _sendingCode = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_withCode(_mapVerificationError(e), e))),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _sendingCode = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kod gönderilirken hata oluştu: $e')),
      );
    }
  }

  Future<void> _applyCredential({
    required PhoneAuthCredential credential,
    required String phoneE164,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    setState(() => _verifying = true);

    try {
      final hasPhoneProvider = user.providerData.any(
        (provider) => provider.providerId == 'phone',
      );

      if (hasPhoneProvider) {
        await user.updatePhoneNumber(credential);
      } else {
        await user.linkWithCredential(credential);
      }

      await user.reload();

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'phone': phoneE164,
        'phoneE164': phoneE164,
        'phoneVerified': true,
        'phoneVerifiedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Telefon numarası doğrulandı.')),
      );
      Navigator.of(context).pop(true);
    } on FirebaseAuthException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_withCode(_mapVerificationError(e), e))),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Telefon doğrulanırken hata oluştu: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _verifying = false);
      }
    }
  }

  Future<void> _verifyCode() async {
    final verificationId = _verificationId;
    if (verificationId == null || verificationId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Önce kod gönder.')));
      return;
    }

    final smsCode = _normalizeCode(_codeController.text);
    if (smsCode.length < 6) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('6 haneli kodu gir.')));
      return;
    }

    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    await _applyCredential(
      credential: credential,
      phoneE164: _requestedPhoneE164.isNotEmpty
          ? _requestedPhoneE164
          : _toE164(_phoneController.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Telefon Doğrulama')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                kDebugMode
                    ? 'Debug mod açık: test numarası kullanabilirsin. Normal numara da denenebilir.'
                    : (widget.alreadyVerified
                          ? 'Numaran doğrulanmış. Değiştirip yeniden doğrulayabilirsin.'
                          : 'Numaranı doğrulamak için SMS kodu al.'),
                style: const TextStyle(
                  color: Color(0xFF334155),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Telefon',
                hintText: '+905xxxxxxxxx veya 05xxxxxxxxx',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _sendingCode || _verifying
                  ? null
                  : () => _sendCode(resend: false),
              icon: const Icon(Icons.sms_outlined),
              label: _sendingCode
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Kod Gönder'),
            ),
            if (_codeSent) ...[
              const SizedBox(height: 18),
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'SMS Kodu',
                  hintText: '6 haneli kod',
                  prefixIcon: Icon(Icons.verified_user_outlined),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _verifying || _sendingCode
                          ? null
                          : _verifyCode,
                      child: _verifying
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Kodu Doğrula'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: _sendingCode || _verifying
                        ? null
                        : () => _sendCode(resend: true),
                    child: const Text('Tekrar Gönder'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

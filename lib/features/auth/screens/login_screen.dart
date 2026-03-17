import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../services/firestore_service.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _firestoreService = FirestoreService();

  bool _loading = false;
  bool _hidePassword = true;

  Future<UserCredential> _signInWithRetry({
    required String email,
    required String password,
  }) async {
    const maxAttempts = 3;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } on FirebaseAuthException catch (e) {
        final isNetworkError =
            e.code == 'network-request-failed' ||
            e.message?.toLowerCase().contains('network error') == true;

        if (!isNetworkError || attempt == maxAttempts) {
          rethrow;
        }

        await Future<void>.delayed(Duration(milliseconds: 700 * attempt));
      }
    }

    throw FirebaseAuthException(
      code: 'network-request-failed',
      message: 'Ağ bağlantısı sağlanamadı.',
    );
  }

  Future<void> _login() async {
    final email = _email.text.trim();
    final password = _password.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email ve şifre boş olamaz.')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final credential = await _signInWithRetry(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user != null) {
        try {
          await _firestoreService.ensureUserDoc(
            uid: user.uid,
            email: user.email ?? email,
          );
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Giriş başarılı, profil verisi oluşturulamadı. Firestore kurallarını kontrol et.',
                ),
              ),
            );
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      String msg;

      switch (e.code) {
        case 'user-not-found':
          msg = 'Bu email ile kullanıcı bulunamadı.';
          break;
        case 'wrong-password':
        case 'invalid-credential':
        case 'invalid-login-credentials':
          msg = 'Email veya şifre hatalı.';
          break;
        case 'invalid-email':
          msg = 'Email formatı hatalı.';
          break;
        case 'operation-not-allowed':
          msg = 'Email/Password girişi Firebase Console içinde aktif değil.';
          break;
        case 'network-request-failed':
          msg = 'Ağ bağlantısı kurulamadı. İnterneti kontrol edip tekrar dene.';
          break;
        case 'user-disabled':
          msg = 'Bu hesap devre dışı bırakılmış.';
          break;
        case 'too-many-requests':
          msg = 'Çok fazla deneme yapıldı. Biraz sonra tekrar dene.';
          break;
        default:
          msg =
              'Giriş başarısız (${e.code}): ${e.message ?? 'Bilinmeyen hata'}';
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Beklenmeyen hata: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    const borderColor = Color(0xFFD9E2F4);

    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF5C667A)),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.92),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
      ),
      labelStyle: const TextStyle(
        color: Color(0xFF64748B),
        fontWeight: FontWeight.w600,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Stack(
        children: [
          const _AuthBackdrop(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.78),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.95),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0xFF0EA5E9),
                                      Color(0xFF2563EB),
                                    ],
                                  ),
                                ),
                                child: const Icon(
                                  Icons.confirmation_number_outlined,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'EVENT APP',
                                style: textTheme.labelLarge?.copyWith(
                                  color: const Color(0xFF1E293B),
                                  letterSpacing: 0.8,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.68),
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.92),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Merhaba, yeniden',
                                style: textTheme.headlineSmall?.copyWith(
                                  color: const Color(0xFF111827),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Biletlerin ve etkinliklerin tek yerde.',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFF5C667A),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.84),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.95),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF0F172A,
                                ).withValues(alpha: 0.08),
                                blurRadius: 22,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Giriş Yap',
                                style: textTheme.titleLarge?.copyWith(
                                  color: const Color(0xFF111827),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: _email,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                decoration: _fieldDecoration(
                                  label: 'Email',
                                  icon: Icons.alternate_email_rounded,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _password,
                                obscureText: _hidePassword,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _loading ? null : _login(),
                                decoration: _fieldDecoration(
                                  label: 'Şifre',
                                  icon: Icons.lock_outline_rounded,
                                  suffixIcon: IconButton(
                                    onPressed: () {
                                      setState(
                                        () => _hidePassword = !_hidePassword,
                                      );
                                    },
                                    icon: Icon(
                                      _hidePassword
                                          ? Icons.visibility_off_rounded
                                          : Icons.visibility_rounded,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _loading ? null : _login,
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size(
                                      double.infinity,
                                      54,
                                    ),
                                    backgroundColor: const Color(0xFF2563EB),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: _loading
                                      ? const SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text('Giriş Yap'),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Center(
                                child: TextButton(
                                  onPressed: _loading
                                      ? null
                                      : () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  const RegisterScreen(),
                                            ),
                                          );
                                        },
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF2563EB),
                                  ),
                                  child: const Text('Hesabın yok mu? Kayıt ol'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            'Devam ederek kullanım koşullarını kabul etmiş olursun.',
                            style: textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthBackdrop extends StatelessWidget {
  const _AuthBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF8F5F0), Color(0xFFF6FAFF), Color(0xFFFDF4EC)],
            ),
          ),
        ),
        Positioned(
          top: -130,
          left: -80,
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFB7185).withValues(alpha: 0.12),
            ),
          ),
        ),
        Positioned(
          top: 120,
          right: -70,
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0EA5E9).withValues(alpha: 0.14),
            ),
          ),
        ),
        Positioned(
          bottom: -130,
          left: -30,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF22C55E).withValues(alpha: 0.12),
            ),
          ),
        ),
      ],
    );
  }
}

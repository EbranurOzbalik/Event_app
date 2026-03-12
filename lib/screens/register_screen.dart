import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/firestore_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _password2 = TextEditingController();

  final _firestoreService = FirestoreService();

  bool _loading = false;

  Future<void> _register() async {
    final email = _email.text.trim();
    final pass1 = _password.text.trim();
    final pass2 = _password2.text.trim();

    if (email.isEmpty || pass1.isEmpty || pass2.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen tüm alanları doldur.')),
      );
      return;
    }

    if (pass1 != pass2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Şifreler aynı değil.')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final credential =
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: pass1,
      );

      final user = credential.user;

      if (user != null) {
        await _firestoreService.ensureUserDoc(
          uid: user.uid,
          email: user.email ?? email,
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } on FirebaseAuthException catch (e) {
      String msg;

      switch (e.code) {
        case 'email-already-in-use':
          msg = 'Bu email zaten kayıtlı.';
          break;
        case 'weak-password':
          msg = 'Şifre çok zayıf.';
          break;
        case 'invalid-email':
          msg = 'Email formatı hatalı.';
          break;
        case 'operation-not-allowed':
          msg = 'Firebase Console içinde Email/Password aktif değil.';
          break;
        default:
          msg = 'Kayıt başarısız: ${e.message ?? e.code}';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Beklenmeyen hata: $e')),
        );
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
    _password2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kayıt Ol'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Şifre',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password2,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Şifre Tekrar',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _register,
                child: _loading
                    ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text('Kayıt Ol'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
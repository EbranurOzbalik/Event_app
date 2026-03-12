import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  final _faculty = TextEditingController();
  final _department = TextEditingController();
  final _grade = TextEditingController();

  final _firestoreService = FirestoreService();

  String _userType = 'ogrenci';
  bool _loading = false;

  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final fullName = _fullName.text.trim();
    final phone = _phone.text.trim();
    final faculty = _faculty.text.trim();
    final department = _department.text.trim();
    final grade = _grade.text.trim();

    if (fullName.isEmpty ||
        phone.isEmpty ||
        faculty.isEmpty ||
        department.isEmpty ||
        grade.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen tüm alanları doldur.')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      await _firestoreService.completeUserProfile(
        uid: user.uid,
        email: user.email ?? '',
        fullName: fullName,
        phone: phone,
        faculty: faculty,
        department: department,
        grade: grade,
        userType: _userType,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profil kaydedilemedi: $e')),
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
    _fullName.dispose();
    _phone.dispose();
    _faculty.dispose();
    _department.dispose();
    _grade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Profili Tamamla'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              enabled: false,
              controller: TextEditingController(text: email),
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _fullName,
              decoration: const InputDecoration(
                labelText: 'Ad Soyad',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Telefon',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _faculty,
              decoration: const InputDecoration(
                labelText: 'Fakülte',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _department,
              decoration: const InputDecoration(
                labelText: 'Bölüm',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _grade,
              decoration: const InputDecoration(
                labelText: 'Sınıf',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _userType,
              items: const [
                DropdownMenuItem(
                  value: 'ogrenci',
                  child: Text('Öğrenci'),
                ),
                DropdownMenuItem(
                  value: 'mezun',
                  child: Text('Mezun'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _userType = value);
                }
              },
              decoration: const InputDecoration(
                labelText: 'Kullanıcı Türü',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _saveProfile,
                child: _loading
                    ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text('Profili Kaydet'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
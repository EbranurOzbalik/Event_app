import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../services/firestore_service.dart';

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Profil kaydedilemedi: $e')));
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
    final textTheme = Theme.of(context).textTheme;
    final email = FirebaseAuth.instance.currentUser?.email ?? '';

    return Scaffold(
      body: Stack(
        children: [
          Container(color: const Color(0xFFF5F2ED)),
          Positioned(
            left: -70,
            right: -70,
            top: -170,
            child: Container(
              height: 340,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF3F4A66), Color(0xFF5C6A8A)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profilini tamamla',
                    style: textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bunu bir kez doldurman yeterli. Sonrasında etkinliklere direkt geçeceksin.',
                    style: textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                      child: Column(
                        children: [
                          TextFormField(
                            enabled: false,
                            initialValue: email,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _fullName,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Ad Soyad',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _phone,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Telefon',
                              prefixIcon: Icon(Icons.phone_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _faculty,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Fakülte',
                              prefixIcon: Icon(Icons.account_balance_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _department,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Bölüm',
                              prefixIcon: Icon(Icons.menu_book_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _grade,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Sınıf',
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _userType,
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
                              prefixIcon: Icon(Icons.groups_2_outlined),
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
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Profili Kaydet'),
                            ),
                          ),
                        ],
                      ),
                    ),
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

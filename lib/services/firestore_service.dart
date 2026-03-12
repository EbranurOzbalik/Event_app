import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> ensureUserDoc({
    required String uid,
    required String email,
  }) async {
    final ref = _db.collection('users').doc(uid);
    final doc = await ref.get();

    if (!doc.exists) {
      await ref.set({
        'uid': uid,
        'email': email,
        'fullName': '',
        'phone': '',
        'faculty': '',
        'department': '',
        'grade': '',
        'userType': '',
        'role': 'user',
        'profileCompleted': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> completeUserProfile({
    required String uid,
    required String email,
    required String fullName,
    required String phone,
    required String faculty,
    required String department,
    required String grade,
    required String userType,
  }) async {
    await _db.collection('users').doc(uid).set({
      'uid': uid,
      'email': email,
      'fullName': fullName,
      'phone': phone,
      'faculty': faculty,
      'department': department,
      'grade': grade,
      'userType': userType,
      'role': 'user',
      'profileCompleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
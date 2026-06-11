import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;

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
        'phoneVerified': false,
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
    final data = <String, dynamic>{
      'uid': uid,
      'fullName': fullName,
      'phone': phone,
      'phoneVerified': false,
      'faculty': faculty,
      'department': department,
      'grade': grade,
      'userType': userType,
      'profileCompleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (email.isNotEmpty) {
      data['email'] = email;
    }

    await _db.collection('users').doc(uid).set(data, SetOptions(merge: true));
  }
}

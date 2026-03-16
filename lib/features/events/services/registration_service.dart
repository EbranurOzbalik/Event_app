import 'package:cloud_firestore/cloud_firestore.dart';

class RegistrationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String buildRegistrationId({
    required String eventId,
    required String userId,
  }) {
    return '${eventId}_$userId';
  }

  Future<void> joinEvent({
    required String eventId,
    required String userId,
    required String userName,
    required String userEmail,
  }) async {
    final docId = buildRegistrationId(
      eventId: eventId,
      userId: userId,
    );

    final ref = _db.collection('registrations').doc(docId);
    final doc = await ref.get();

    if (doc.exists) {
      throw Exception('Bu etkinliğe zaten katıldın.');
    }

    await ref.set({
      'eventId': eventId,
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'joinedAt': FieldValue.serverTimestamp(),
      'checkedIn': false,
    });
  }

  Stream<bool> isJoined({
    required String eventId,
    required String userId,
  }) {
    final docId = buildRegistrationId(
      eventId: eventId,
      userId: userId,
    );

    return _db
        .collection('registrations')
        .doc(docId)
        .snapshots()
        .map((doc) => doc.exists);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getMyRegistrations({
    required String userId,
  }) {
    return _db
        .collection('registrations')
        .where('userId', isEqualTo: userId)
        .snapshots();
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';

class RegistrationService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  static const String _ticketPrefix = 'event_ticket:';

  String buildRegistrationId({
    required String eventId,
    required String userId,
  }) {
    return '${eventId}_$userId';
  }

  String buildTicketCode({required String eventId, required String userId}) {
    return '$_ticketPrefix${buildRegistrationId(eventId: eventId, userId: userId)}';
  }

  String _extractRegistrationId(String ticketCode) {
    final normalized = ticketCode.trim();

    if (normalized.isEmpty) {
      throw Exception('QR kodu okunamadı.');
    }

    if (normalized.startsWith(_ticketPrefix)) {
      return normalized.substring(_ticketPrefix.length);
    }

    return normalized;
  }

  Future<void> joinEvent({
    required String eventId,
    required String userId,
    required String userName,
    required String userEmail,
  }) async {
    final docId = buildRegistrationId(eventId: eventId, userId: userId);

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

  Stream<bool> isJoined({required String eventId, required String userId}) {
    final docId = buildRegistrationId(eventId: eventId, userId: userId);

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

  Future<Map<String, String>> checkInWithTicketCode({
    required String ticketCode,
  }) async {
    final registrationId = _extractRegistrationId(ticketCode);
    final ref = _db.collection('registrations').doc(registrationId);

    return _db.runTransaction((transaction) async {
      final doc = await transaction.get(ref);

      if (!doc.exists) {
        throw Exception('Geçersiz bilet.');
      }

      final data = doc.data()!;
      final checkedIn = data['checkedIn'] == true;

      if (checkedIn) {
        throw Exception('Bu bilet daha önce okutulmuş.');
      }

      transaction.update(ref, {
        'checkedIn': true,
        'checkedInAt': FieldValue.serverTimestamp(),
      });

      return {
        'registrationId': registrationId,
        'eventId': (data['eventId'] ?? '').toString(),
        'userName': (data['userName'] ?? '').toString(),
        'userEmail': (data['userEmail'] ?? '').toString(),
      };
    });
  }
}

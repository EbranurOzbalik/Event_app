import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event_model.dart';

class EventService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  String _normalizeRole(String value) {
    final role = value.trim().toLowerCase();
    if (role == 'admin' || role == 'administrator' || role == 'yonetici') {
      return 'admin';
    }
    if (role == 'moderator' || role == 'mod') {
      return 'moderator';
    }
    return 'user';
  }

  Stream<List<EventModel>> getEvents() {
    return _db
        .collection('events')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => EventModel.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<void> addEvent({
    required String title,
    required String description,
    required String category,
    required String location,
    required String date,
    String imageUrl = '',
    required String createdBy,
  }) async {
    final userDoc = await _db.collection('users').doc(createdBy).get();
    final userRole = _normalizeRole(
      (userDoc.data()?['role'] ?? 'user').toString(),
    );
    final canCreate = userRole == 'admin' || userRole == 'moderator';

    if (!canCreate) {
      throw Exception('Etkinlik oluşturma yetkin yok.');
    }

    await _db.collection('events').add({
      'title': title,
      'description': description,
      'category': category,
      'location': location,
      'date': date,
      'imageUrl': imageUrl,
      'createdBy': createdBy,
      'createdByRole': userRole,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

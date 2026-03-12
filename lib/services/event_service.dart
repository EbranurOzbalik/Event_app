import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event_model.dart';

class EventService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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
    required String location,
    required String date,
    required String createdBy,
  }) async {
    final userDoc = await _db.collection('users').doc(createdBy).get();
    final userRole = (userDoc.data()?['role'] ?? 'user').toString();
    final canCreate = userRole == 'admin' || userRole == 'moderator';

    if (!canCreate) {
      throw Exception('Etkinlik oluşturma yetkin yok.');
    }

    await _db.collection('events').add({
      'title': title,
      'description': description,
      'location': location,
      'date': date,
      'createdBy': createdBy,
      'createdByRole': userRole,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

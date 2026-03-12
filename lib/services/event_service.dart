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
    required String createdByRole,
  }) async {
    await _db.collection('events').add({
      'title': title,
      'description': description,
      'location': location,
      'date': date,
      'createdBy': createdBy,
      'createdByRole': createdByRole,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
import 'dart:convert';

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

    final decoded = _maybeDecodeUriComponent(normalized);
    final idFromJson = _tryExtractRegistrationIdFromJson(decoded);
    final idFromUri = _tryExtractRegistrationIdFromUri(decoded);

    final candidate = idFromJson ?? idFromUri ?? _stripKnownPrefixes(decoded);
    final registrationId = _stripKnownPrefixes(candidate).trim();

    if (registrationId.isEmpty) {
      throw Exception('QR kodu geçersiz.');
    }

    if (registrationId.contains('/')) {
      throw Exception('QR kodu formatı desteklenmiyor.');
    }

    return registrationId;
  }

  String _maybeDecodeUriComponent(String value) {
    try {
      final decoded = Uri.decodeComponent(value);
      return decoded.trim().isEmpty ? value : decoded.trim();
    } catch (_) {
      return value;
    }
  }

  String _stripKnownPrefixes(String value) {
    var current = value.trim();
    if (current.isEmpty) return current;

    final prefixes = <String>[_ticketPrefix, 'ticket:', 'registration:'];
    var changed = true;

    while (changed && current.isNotEmpty) {
      changed = false;
      for (final prefix in prefixes) {
        if (current.toLowerCase().startsWith(prefix)) {
          current = current.substring(prefix.length).trim();
          changed = true;
        }
      }
    }

    return current;
  }

  String? _tryExtractRegistrationIdFromJson(String value) {
    if (!value.startsWith('{') || !value.endsWith('}')) {
      return null;
    }

    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map) {
        return null;
      }

      const keys = [
        'registrationId',
        'registration_id',
        'regId',
        'ticketCode',
        'ticket_code',
        'code',
      ];

      for (final key in keys) {
        final raw = decoded[key];
        if (raw == null) continue;
        final str = raw.toString().trim();
        if (str.isNotEmpty) {
          return str;
        }
      }
    } catch (_) {}

    return null;
  }

  String? _tryExtractRegistrationIdFromUri(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null) return null;

    const queryKeys = [
      'registrationId',
      'registration_id',
      'regId',
      'ticketCode',
      'ticket_code',
      'ticket',
      'code',
      'id',
    ];

    for (final key in queryKeys) {
      final raw = uri.queryParameters[key];
      if (raw == null) continue;
      final normalized = raw.trim();
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }

    final fragment = uri.fragment.trim();
    if (fragment.isNotEmpty) {
      return fragment;
    }

    final segments = uri.pathSegments;
    if (segments.isNotEmpty) {
      final last = segments.last.trim();
      if (last.isNotEmpty) {
        return last;
      }
    }

    return null;
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

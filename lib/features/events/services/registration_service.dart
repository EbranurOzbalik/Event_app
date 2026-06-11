import 'dart:convert';
import 'dart:math';

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

  String buildLegacyTicketCode({
    required String eventId,
    required String userId,
  }) {
    return '$_ticketPrefix${buildRegistrationId(eventId: eventId, userId: userId)}';
  }

  String _generateTicketToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(18, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  String _buildTicketCode({
    required String registrationId,
    required String ticketToken,
  }) {
    return jsonEncode({
      'registrationId': registrationId,
      'ticketToken': ticketToken,
    });
  }

  _ParsedTicketPayload _parseTicketPayload(String ticketCode) {
    final normalized = ticketCode.trim();

    if (normalized.isEmpty) {
      throw Exception('QR kodu okunamadı.');
    }

    final decoded = _maybeDecodeUriComponent(normalized);
    final jsonPayload = _tryExtractPayloadFromJson(decoded);
    final uriPayload = _tryExtractPayloadFromUri(decoded);

    final registrationCandidate =
        jsonPayload?.registrationId ??
        uriPayload?.registrationId ??
        _stripKnownPrefixes(decoded);
    final registrationId = _stripKnownPrefixes(registrationCandidate).trim();
    final token =
        jsonPayload?.ticketToken?.trim() ??
        uriPayload?.ticketToken?.trim() ??
        '';

    if (registrationId.isEmpty) {
      throw Exception('QR kodu geçersiz.');
    }

    if (registrationId.contains('/')) {
      throw Exception('QR kodu formatı desteklenmiyor.');
    }

    return _ParsedTicketPayload(
      registrationId: registrationId,
      ticketToken: token.isEmpty ? null : token,
    );
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

  _ParsedTicketPayload? _tryExtractPayloadFromJson(String value) {
    if (!value.startsWith('{') || !value.endsWith('}')) {
      return null;
    }

    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map) {
        return null;
      }

      const idKeys = [
        'registrationId',
        'registration_id',
        'regId',
        'ticketCode',
        'ticket_code',
        'code',
      ];

      for (final key in idKeys) {
        final raw = decoded[key];
        if (raw == null) continue;
        final str = raw.toString().trim();
        if (str.isNotEmpty) {
          final rawToken = decoded['ticketToken'] ?? decoded['token'];
          final token = rawToken?.toString().trim();
          return _ParsedTicketPayload(
            registrationId: str,
            ticketToken: token == null || token.isEmpty ? null : token,
          );
        }
      }
    } catch (_) {}

    return null;
  }

  _ParsedTicketPayload? _tryExtractPayloadFromUri(String value) {
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
        final token = uri.queryParameters['ticketToken']?.trim();
        return _ParsedTicketPayload(
          registrationId: normalized,
          ticketToken: token == null || token.isEmpty ? null : token,
        );
      }
    }

    final fragment = uri.fragment.trim();
    if (fragment.isNotEmpty) {
      final token = uri.queryParameters['ticketToken']?.trim();
      return _ParsedTicketPayload(
        registrationId: fragment,
        ticketToken: token == null || token.isEmpty ? null : token,
      );
    }

    final segments = uri.pathSegments;
    if (segments.isNotEmpty) {
      final last = segments.last.trim();
      if (last.isNotEmpty) {
        final token = uri.queryParameters['ticketToken']?.trim();
        return _ParsedTicketPayload(
          registrationId: last,
          ticketToken: token == null || token.isEmpty ? null : token,
        );
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
    final ticketToken = _generateTicketToken();
    final ticketCode = _buildTicketCode(
      registrationId: docId,
      ticketToken: ticketToken,
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
      'ticketToken': ticketToken,
      'ticketCode': ticketCode,
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

  Stream<QuerySnapshot<Map<String, dynamic>>> getRegistrationsForEvent({
    required String eventId,
  }) {
    return _db
        .collection('registrations')
        .where('eventId', isEqualTo: eventId)
        .snapshots();
  }

  Future<String> getOrCreateTicketCode({
    required String eventId,
    required String userId,
  }) async {
    final registrationId = buildRegistrationId(
      eventId: eventId,
      userId: userId,
    );
    final ref = _db.collection('registrations').doc(registrationId);
    final doc = await ref.get();

    if (!doc.exists) {
      return buildLegacyTicketCode(eventId: eventId, userId: userId);
    }

    final data = doc.data()!;
    final existingCode = (data['ticketCode'] ?? '').toString().trim();
    final existingToken = (data['ticketToken'] ?? '').toString().trim();

    if (existingCode.isNotEmpty && existingToken.isNotEmpty) {
      return existingCode;
    }

    final token = existingToken.isNotEmpty
        ? existingToken
        : _generateTicketToken();
    final code = existingCode.isNotEmpty
        ? existingCode
        : _buildTicketCode(registrationId: registrationId, ticketToken: token);

    await ref.set({
      'ticketToken': token,
      'ticketCode': code,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return code;
  }

  Future<Map<String, String>> checkInWithTicketCode({
    required String ticketCode,
  }) async {
    final payload = _parseTicketPayload(ticketCode);
    final registrationId = payload.registrationId;
    final ref = _db.collection('registrations').doc(registrationId);

    return _db.runTransaction((transaction) async {
      final doc = await transaction.get(ref);

      if (!doc.exists) {
        throw Exception('Geçersiz bilet.');
      }

      final data = doc.data()!;
      final checkedIn = data['checkedIn'] == true;
      final storedToken = (data['ticketToken'] ?? '').toString().trim();
      final eventId = (data['eventId'] ?? '').toString();
      final eventRef = _db.collection('events').doc(eventId);
      final eventDoc = eventId.isEmpty ? null : await transaction.get(eventRef);
      final eventData = eventDoc?.data();

      if (storedToken.isNotEmpty && storedToken != payload.ticketToken) {
        throw Exception('Bilet token doğrulanamadı.');
      }

      if (checkedIn) {
        throw Exception('Bu bilet daha önce okutulmuş.');
      }

      transaction.update(ref, {
        'checkedIn': true,
        'checkedInAt': FieldValue.serverTimestamp(),
      });

      return {
        'registrationId': registrationId,
        'eventId': eventId,
        'eventTitle': (eventData?['title'] ?? 'Etkinlik').toString(),
        'eventLocation': (eventData?['location'] ?? '').toString(),
        'eventDate': (eventData?['date'] ?? '').toString(),
        'userName': (data['userName'] ?? '').toString(),
        'userEmail': (data['userEmail'] ?? '').toString(),
      };
    });
  }
}

class _ParsedTicketPayload {
  final String registrationId;
  final String? ticketToken;

  const _ParsedTicketPayload({
    required this.registrationId,
    required this.ticketToken,
  });
}

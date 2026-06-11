import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();
  static const _allUsersTopic = 'all_users';
  static const _androidChannelId = 'event_app_default';

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  bool _localNotificationsReady = false;

  bool _initialized = false;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;

  bool get _isSupportedPlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android;
  }

  Future<void> initialize() async {
    if (_initialized || !_isSupportedPlatform) {
      return;
    }
    _initialized = true;

    await _initializeLocalNotifications();
    await _configureForegroundPresentation();
    await _requestPermission();

    _foregroundSub = FirebaseMessaging.onMessage.listen((message) async {
      await _showForegroundNotification(message);
      debugPrint(
        'FCM foreground message received: ${message.messageId ?? 'no-id'}',
      );
    });

    _authSub = FirebaseAuth.instance.authStateChanges().listen((_) {
      _syncCurrentUserToken();
    });

    _tokenRefreshSub = _messaging.onTokenRefresh.listen((token) async {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null || token.trim().isEmpty) return;
      await _saveToken(uid, token);
    });

    await _syncCurrentUserToken();
  }

  Future<void> _requestPermission() async {
    try {
      await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
    } catch (e) {
      debugPrint('FCM permission request failed: $e');
    }
  }

  Future<void> _initializeLocalNotifications() async {
    if (_localNotificationsReady || !_isSupportedPlatform) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(settings);

    if (defaultTargetPlatform == TargetPlatform.android) {
      const channel = AndroidNotificationChannel(
        _androidChannelId,
        'Etkinlik Bildirimleri',
        description: 'Etkinlik bilet ve duyuru bildirimleri',
        importance: Importance.high,
      );
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.createNotificationChannel(channel);
    }

    _localNotificationsReady = true;
  }

  Future<void> _configureForegroundPresentation() async {
    try {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      debugPrint('FCM foreground presentation setup failed: $e');
    }
  }

  Future<void> _syncCurrentUserToken() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final token = await _messaging.getToken();
      if (token == null || token.trim().isEmpty) {
        return;
      }
      await _saveToken(uid, token);
      await _messaging.subscribeToTopic(_allUsersTopic);
    } catch (e) {
      debugPrint('FCM token sync failed: $e');
    }
  }

  Future<void> _saveToken(String uid, String token) async {
    if (kDebugMode) {
      debugPrint('FCM token synced for $uid: $token');
    }
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'fcmTokens': FieldValue.arrayUnion([token]),
      'lastFcmTokenUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    if (!_localNotificationsReady) return;

    final title = (message.notification?.title ?? message.data['title'] ?? '')
        .trim();
    final body = (message.notification?.body ?? message.data['body'] ?? '')
        .trim();

    if (title.isEmpty && body.isEmpty) return;

    final notificationDetails = NotificationDetails(
      android: const AndroidNotificationDetails(
        _androidChannelId,
        'Etkinlik Bildirimleri',
        channelDescription: 'Etkinlik bilet ve duyuru bildirimleri',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title.isEmpty ? 'Event App' : title,
      body,
      notificationDetails,
      payload: jsonEncode(message.data),
    );
  }

  Future<void> dispose() async {
    await _authSub?.cancel();
    await _tokenRefreshSub?.cancel();
    await _foregroundSub?.cancel();
  }
}

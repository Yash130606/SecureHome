import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] Background message: ${message.messageId}');
}

class PushNotificationService {
  PushNotificationService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static StreamSubscription<String>? _tokenRefreshSub;
  static StreamSubscription<RemoteMessage>? _tapOpenSub;
  static bool _initialized = false;
  static String? _token;

  static String? get currentToken => _token;

  static Future<void> initialize({
    required VoidCallback onNotificationTap,
  }) async {
    if (_initialized) return;
    _initialized = true;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _messaging.setAutoInitEnabled(true);
    await _requestPermission();
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    _token = await _messaging.getToken();
    await _persistToken();

    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen(
      (token) async {
        _token = token;
        await _persistToken();
      },
    );

    _tapOpenSub?.cancel();
    _tapOpenSub = FirebaseMessaging.onMessageOpenedApp.listen((_) {
      onNotificationTap();
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      scheduleMicrotask(onNotificationTap);
    }
  }

  static Future<NotificationSettings> _requestPermission() {
    return _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
  }

  static Future<void> refreshToken() async {
    _token = await _messaging.getToken();
    await _persistToken();
  }

  static Future<void> _persistToken() async {
    final user = FirebaseAuth.instance.currentUser;
    final token = _token;
    if (user == null || token == null || token.isEmpty) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
      {
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  static Future<void> clearToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {
          'fcmToken': FieldValue.delete(),
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    await _messaging.deleteToken();
    _token = null;
  }

  static Future<NotificationSettings> notificationSettings() {
    return _messaging.getNotificationSettings();
  }

  static void dispose() {
    _tokenRefreshSub?.cancel();
    _tapOpenSub?.cancel();
    _tokenRefreshSub = null;
    _tapOpenSub = null;
    _initialized = false;
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_colors.dart';

/// Top-level background message handler required by Firebase Messaging.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM Background] Received message: ${message.messageId}');
}

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Global navigator key or callback for in-app navigation on push tap
  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  Future<void> initialize({
    Function(String itemId)? onSmartMatchNotificationTapped,
  }) async {
    // 1. Request notification permissions (for iOS and Android 13+)
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    debugPrint('[FCM] Permission status: ${settings.authorizationStatus}');

    // 2. Set foreground presentation options
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 3. Register background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 4. Retrieve & save device FCM token
    await updateFcmToken();

    // Listen for token rotation
    _fcm.onTokenRefresh.listen((newToken) async {
      debugPrint('[FCM] Token refreshed: $newToken');
      await _saveTokenToFirestore(newToken);
    });

    // 5. Listen to foreground messages and show custom in-app banner
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[FCM Foreground] Got message: ${message.notification?.title}');
      _showInAppSmartMatchBanner(message, onSmartMatchNotificationTapped);
    });

    // 6. Handle notification click when app is opened from background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[FCM Open] User tapped push notification: ${message.data}');
      final itemId = message.data['matchedItemId'] ?? message.data['itemId'];
      if (itemId != null && onSmartMatchNotificationTapped != null) {
        onSmartMatchNotificationTapped(itemId.toString());
      }
    });

    // 7. Check if app was opened from terminated state via push notification
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      final itemId =
          initialMessage.data['matchedItemId'] ?? initialMessage.data['itemId'];
      if (itemId != null && onSmartMatchNotificationTapped != null) {
        // Small delay to allow router to initialize
        Future.delayed(const Duration(milliseconds: 600), () {
          onSmartMatchNotificationTapped(itemId.toString());
        });
      }
    }
  }

  /// Saves the current user's device FCM token into Firestore for targeted push notifications
  Future<void> updateFcmToken() async {
    try {
      final token = await _fcm.getToken();
      if (token != null) {
        debugPrint('[FCM] Device Token: $token');
        await _saveTokenToFirestore(token);
      }
    } catch (e) {
      debugPrint('[FCM] Error getting FCM token: $e');
    }
  }

  Future<void> _saveTokenToFirestore(String token) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).set({
        'fcmToken': token,
        'email': user.email,
        'displayName': user.displayName,
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('[FCM] Token saved to Firestore for user: ${user.uid}');
    }
  }

  /// Displays an in-app banner if a smart match push notification arrives in foreground
  void _showInAppSmartMatchBanner(
    RemoteMessage message,
    Function(String itemId)? onTapped,
  ) {
    final title = message.notification?.title ?? '✨ Possible Match Found!';
    final body = message.notification?.body ??
        'A matching item was reported nearby within 500m!';
    final itemId = message.data['matchedItemId'] ?? message.data['itemId'];

    messengerKey.currentState?.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 6),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primaryTealDark,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: AppColors.accentAmber,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.black, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        action: itemId != null && onTapped != null
            ? SnackBarAction(
                label: 'VIEW',
                textColor: AppColors.accentAmber,
                onPressed: () => onTapped(itemId.toString()),
              )
            : null,
      ),
    );
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

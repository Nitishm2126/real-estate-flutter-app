import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../firebase_options.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Top-level FCM background handler (required by Firebase Messaging).
// Must be a top-level function — not a class method.
// ──────────────────────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    // Firebase may already be initialized in the background isolate.
  }
  debugPrint('[FCM] Background message received: ${message.messageId}');
  debugPrint('[FCM]   title: ${message.notification?.title}');
  debugPrint('[FCM]   body : ${message.notification?.body}');
  debugPrint('[FCM]   data : ${message.data}');
}

// ──────────────────────────────────────────────────────────────────────────────
// FcmService — Consolidated Firebase Cloud Messaging service.
//
// Responsibilities:
//   1. Register the background handler.
//   2. Request notification permissions (Android 13+).
//   3. Obtain the FCM token dynamically and persist it to Supabase.
//   4. Listen for token refreshes.
//   5. Handle foreground messages (show as local notification).
//   6. Handle notification taps (background + terminated state).
//   7. Provide debug/diagnostic state for the Settings screen.
// ──────────────────────────────────────────────────────────────────────────────
class FcmService {
  // Singleton
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  bool _isInitialized = false;

  /// Public stream for notification-tap deep links (customer IDs / routes).
  final StreamController<String?> notificationTapStream =
      StreamController<String?>.broadcast();

  // ─── Diagnostic state (readable from UI in debug builds) ──────────────
  String? currentToken;
  String? permissionStatus;
  String? lastNotificationTitle;
  String? lastNotificationBody;
  DateTime? lastNotificationTime;

  // ─── Channel constants (shared with NotificationService for FCM local display) ──
  static const String channelId = 'mcp_avadi_followup_reminders';
  static const String channelName = 'Follow-up Reminders';
  static const String channelDesc =
      'Scheduled reminders for customer follow-ups in MCP Avadi CRM';

  // ─── Local notification plugin (for foreground FCM display) ────────────
  final FlutterLocalNotificationsPlugin _localPlugin =
      FlutterLocalNotificationsPlugin();

  // ─── Device ID for Supabase token storage ─────────────────────────────
  String? _deviceId;

  // ═══════════════════════════════════════════════════════════════════════
  //  Initialization
  // ═══════════════════════════════════════════════════════════════════════

  /// Call once after both Firebase.initializeApp() and Supabase.initialize()
  /// have completed.
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('[FCM] Already initialized – skipping.');
      return;
    }
    if (kIsWeb) return;

    debugPrint('[FCM] Initializing FcmService...');

    try {
      // 1. Register the top-level background message handler.
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 2. Request permission (covers Android 13+ POST_NOTIFICATIONS).
      await _requestPermission();

      // 3. Obtain FCM token dynamically.
      await _fetchAndStoreToken();

      // 4. Listen for token refreshes.
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        debugPrint('[FCM] Token refreshed.');
        currentToken = newToken;
        _saveTokenToSupabase(newToken);
      });

      // 5. Foreground message handler.
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);

      // 6. Background notification tap handler.
      FirebaseMessaging.onMessageOpenedApp.listen(_onNotificationTap);

      // 7. Check if the app was launched from a terminated-state notification.
      await _checkTerminatedLaunch();

      _isInitialized = true;
      debugPrint('[FCM] Initialization complete.');
    } catch (e, stack) {
      debugPrint('[FCM] Initialization error: $e');
      debugPrint('[FCM] $stack');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Permission
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _requestPermission() async {
    try {
      final NotificationSettings settings =
          await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
      );

      permissionStatus = settings.authorizationStatus.name;

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('[FCM] Notification permission: AUTHORIZED');
      } else if (settings.authorizationStatus ==
          AuthorizationStatus.provisional) {
        debugPrint('[FCM] Notification permission: PROVISIONAL');
      } else {
        debugPrint(
            '[FCM] Notification permission: DENIED (${settings.authorizationStatus})');
      }
    } catch (e) {
      debugPrint('[FCM] Permission request error: $e');
      permissionStatus = 'error';
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Token
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _fetchAndStoreToken() async {
    try {
      final String? token = await FirebaseMessaging.instance.getToken();
      if (token == null) {
        debugPrint('[FCM] getToken() returned null – unable to register.');
        return;
      }

      currentToken = token;

      // Only log in debug mode – never hardcode or expose in production UI.
      if (kDebugMode) {
        debugPrint('\n=============================================');
        debugPrint('[FCM] DEVICE TOKEN FOR FIREBASE CONSOLE:');
        debugPrint(token);
        debugPrint('=============================================\n');
      }

      await _saveTokenToSupabase(token);
    } catch (e) {
      debugPrint('[FCM] Token retrieval error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Supabase Token Persistence
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _saveTokenToSupabase(String token) async {
    try {
      _deviceId ??= await _getOrCreateDeviceId();

      debugPrint(
          '[FCM] Saving token to Supabase for device: $_deviceId');

      await Supabase.instance.client.from('fcm_tokens').upsert({
        'device_id': _deviceId,
        'token': token,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'device_id');

      debugPrint('[FCM] Token saved successfully.');
    } catch (e) {
      debugPrint('[FCM] Failed to save token to Supabase: $e');
    }
  }

  Future<String> _getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString('device_id');
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await prefs.setString('device_id', deviceId);
      debugPrint('[FCM] Generated new device_id: $deviceId');
    }
    return deviceId;
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Foreground Message Handler
  // ═══════════════════════════════════════════════════════════════════════

  void _onForegroundMessage(RemoteMessage message) {
    debugPrint(
        '[FCM] Foreground message received: ${message.messageId}');
    
    // Strict filtering: Only process if type is 'follow_up'
    if (message.data['type'] != 'follow_up') {
      debugPrint('[FCM] Ignoring message: type is not follow_up (${message.data['type']})');
      return;
    }

    debugPrint('[FCM]   title: ${message.notification?.title}');
    debugPrint('[FCM]   body : ${message.notification?.body}');
    debugPrint('[FCM]   data : ${message.data}');

    // Update diagnostic state
    lastNotificationTitle = message.notification?.title ?? message.data['title'];
    lastNotificationBody = message.notification?.body ?? message.data['body'];
    lastNotificationTime = DateTime.now();

    // Show as a local notification so it appears in the system tray.
    if (message.notification != null) {
      _showFcmAsLocalNotification(message);
    }
  }

  Future<void> _showFcmAsLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    // Determine a stable notification ID
    int id = message.hashCode;
    if (message.data.containsKey('follow_up_id')) {
      id = _generateNotificationId(message.data['follow_up_id']);
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@drawable/ic_notification',
      enableVibration: true,
      playSound: true,
    );

    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails);

    // Build payload from data
    final String? payload = message.data['customer_id'] ??
        message.data['route'] ??
        message.data['id'];

    try {
      await _localPlugin.show(
        id: id,
        title: notification.title,
        body: notification.body,
        notificationDetails: notificationDetails,
        payload: payload,
      );
      debugPrint('[FCM] Foreground notification displayed via local plugin.');
    } catch (e) {
      debugPrint('[FCM] Failed to show foreground notification: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Notification Tap Handlers
  // ═══════════════════════════════════════════════════════════════════════

  void _onNotificationTap(RemoteMessage message) {
    debugPrint(
        '[FCM] Notification tapped (background): ${message.messageId}');
    debugPrint('[FCM]   data: ${message.data}');

    _routeFromData(message.data);
  }

  Future<void> _checkTerminatedLaunch() async {
    try {
      final RemoteMessage? initialMessage =
          await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        debugPrint(
            '[FCM] App launched from terminated notification: ${initialMessage.messageId}');
        // Delay slightly so the widget tree is ready for navigation.
        Future.delayed(const Duration(milliseconds: 500), () {
          _routeFromData(initialMessage.data);
        });
      }
    } catch (e) {
      debugPrint('[FCM] Error checking initial message: $e');
    }
  }

  /// Extract routing info from the notification data payload and push to stream.
  void _routeFromData(Map<String, dynamic> data) {
    // Strict filtering: Only route if type is 'follow_up'
    if (data['type'] != 'follow_up') {
      debugPrint('[FCM] Ignoring notification tap: type is not follow_up (${data['type']})');
      return;
    }

    // Priority: customer_id → route → id
    final String? target =
        data['customer_id'] ?? data['route'] ?? data['id'];
    if (target != null && target.isNotEmpty) {
      notificationTapStream.add(target);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Helpers
  // ═══════════════════════════════════════════════════════════════════════

  /// Converts a UUID string into a stable positive 32-bit notification ID.
  int _generateNotificationId(String uuid) {
    final cleanUuid = uuid.replaceAll('-', '');
    if (cleanUuid.length < 7) return uuid.hashCode.abs();
    final hexStr = cleanUuid.substring(0, 7);
    return int.parse(hexStr, radix: 16);
  }
}

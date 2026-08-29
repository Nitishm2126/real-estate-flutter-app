import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/follow_up.dart';
import '../models/customer.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('[FCM] Handling a background message: ${message.messageId}');
}

/// Singleton service that wraps [FlutterLocalNotificationsPlugin].
///
/// Debug log prefix: [NS]
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  final StreamController<String?> selectNotificationStream =
      StreamController<String?>.broadcast();

  bool _isInitialized = false;

  // ─── Channel constants ────────────────────────────────────────────

  static const String _channelId = 'mcp_avadi_followup_reminders';
  static const String _channelName = 'Follow-up Reminders';
  static const String _channelDesc =
      'Scheduled reminders for customer follow-ups in MCP Avadi CRM';

  // ─── Initialization ───────────────────────────────────────────────

  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('[NS] Already initialized – skipping.');
      return;
    }

    debugPrint('[NS] Initializing NotificationService...');

    // Step 1: Configure timezone database (must happen before any scheduling)
    if (!kIsWeb) {
      await _configureLocalTimeZone();
    }

    // Step 2: Android initialization settings
    //   '@mipmap/launcher_icon' matches the app's launcher icon defined in the manifest.
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);

    // Step 3: Initialize the plugin
    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint(
            '[NS] Notification tapped: id=${response.id}, payload=${response.payload}');
        if (response.payload != null && response.payload!.isNotEmpty) {
          selectNotificationStream.add(response.payload);
        }
      },
      onDidReceiveBackgroundNotificationResponse:
          _onBackgroundNotificationResponse,
    );

    // Step 4: Setup Firebase Messaging (FCM)
    if (!kIsWeb && Platform.isAndroid) {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      
      // Handle foreground FCM messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('[FCM] Foreground message received: ${message.messageId}');
        
        // Show local notification using flutter_local_notifications to make it visible
        if (message.notification != null) {
          _showFcmAsLocalNotification(message);
        }
      });
      
      // Handle when user taps FCM notification in background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('[FCM] Notification tapped in background: ${message.messageId}');
        if (message.data.containsKey('customer_id')) {
          selectNotificationStream.add(message.data['customer_id']);
        }
      });
    }

    // Step 4: Ensure notification channel exists on Android 8+
    if (!kIsWeb && Platform.isAndroid) {
      await _createNotificationChannel();
    }

    _isInitialized = true;
    debugPrint('[NS] Initialization complete.');
  }

  /// Handles notification responses when the app was in the background.
  /// Must be a top-level or static function.
  @pragma('vm:entry-point')
  static void _onBackgroundNotificationResponse(
      NotificationResponse response) {
    debugPrint(
        '[NS] Background notification tapped: id=${response.id}, payload=${response.payload}');
    // Re-add to stream – note: this static callback runs in an isolate;
    // for full navigation support, use selectNotificationStream only for foreground.
  }

  /// Creates the Android notification channel used for all follow-up reminders.
  /// Android 8.0+ (API 26+) requires a channel for every notification.
  Future<void> _createNotificationChannel() async {
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) {
      debugPrint('[NS] Could not resolve Android plugin implementation.');
      return;
    }

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
      showBadge: true,
    );

    await androidPlugin.createNotificationChannel(channel);
    debugPrint('[NOTIFICATION] Channel: CREATED');
  }

  // ─── Timezone ─────────────────────────────────────────────────────

  Future<void> _configureLocalTimeZone() async {
    debugPrint('[NS] Configuring local timezone...');
    // Initialize the tz database with all timezone data
    tz.initializeTimeZones();

    try {
      // Force Asia/Kolkata for India time
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
      debugPrint('[NS] Timezone forced to: Asia/Kolkata');
    } catch (e) {
      debugPrint('[NS] Could not set Asia/Kolkata timezone – fallback to UTC: $e');
    }
  }

  // ─── Permissions ──────────────────────────────────────────────────

  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;

    bool isGranted = true;

    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin == null) return false;

      // Request POST_NOTIFICATIONS permission (Android 13+)
      final bool? notifGranted =
          await androidPlugin.requestNotificationsPermission();
      debugPrint('[NOTIFICATION] Permission: ${notifGranted == true ? "GRANTED" : "DENIED"}');
      if (notifGranted == false) {
        isGranted = false;
      }

      // Check exact alarm permission status
      final bool? canScheduleExact =
          await androidPlugin.canScheduleExactNotifications();
      debugPrint('[NOTIFICATION] Exact alarm: ${canScheduleExact == true ? "AVAILABLE" : "UNAVAILABLE"}');

      if (canScheduleExact == false) {
        debugPrint('[NOTIFICATION] Exact alarm not available – requesting SCHEDULE_EXACT_ALARM...');
        await androidPlugin.requestExactAlarmsPermission();
        final bool? recheck =
            await androidPlugin.canScheduleExactNotifications();
        debugPrint('[NOTIFICATION] Exact alarm after request: $recheck');
        if (recheck == false) {
          isGranted = false;
        }
      }
    }
    
    return isGranted;
  }

  // ─── App-launch check ─────────────────────────────────────────────

  Future<void> checkPendingNotification() async {
    if (kIsWeb) return;

    // Check Local Notification Launch
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details != null &&
        details.didNotificationLaunchApp &&
        details.notificationResponse?.payload != null) {
      debugPrint(
          '[NS] App launched from local notification: payload=${details.notificationResponse!.payload}');
      Future.delayed(const Duration(milliseconds: 500), () {
        selectNotificationStream.add(details.notificationResponse!.payload);
      });
      return; // If launched by local, don't double process
    }
    
    // Check FCM Notification Launch (Terminated state)
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null && initialMessage.data.containsKey('customer_id')) {
      debugPrint(
          '[NS] App launched from FCM notification: customer_id=${initialMessage.data['customer_id']}');
      Future.delayed(const Duration(milliseconds: 500), () {
        selectNotificationStream.add(initialMessage.data['customer_id']);
      });
    }
  }

  // ─── ID generation ────────────────────────────────────────────────
  
  /// Converts a UUID string into a stable positive 32-bit notification ID.
  int _generateNotificationId(String uuid) {
    final cleanUuid = uuid.replaceAll('-', '');
    if (cleanUuid.length < 7) return uuid.hashCode.abs();
    // Use first 7 hex chars → max value 0xFFFFFFF (268,435,455) which fits in 32-bit
    final hexStr = cleanUuid.substring(0, 7);
    return int.parse(hexStr, radix: 16);
  }

  // ─── FCM Local Display ────────────────────────────────────────────

  Future<void> _showFcmAsLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    
    int id = message.hashCode;
    if (message.data.containsKey('follow_up_id')) {
      id = _generateNotificationId(message.data['follow_up_id']);
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
      enableVibration: true,
      playSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(android: androidDetails);

    await _plugin.show(
      id,
      notification.title,
      notification.body,
      notificationDetails,
      payload: message.data['customer_id'],
    );
  }

  // ─── Scheduling ───────────────────────────────────────────────────

  /// Schedules one or two system notifications for [followUp].
  ///
  /// - Cancels any existing notifications for this follow-up ID first
  ///   (to avoid duplicates on reschedule).
  /// - Schedules the exact reminder at [followUp.followUpTime] on [followUp.followUpDate].
  /// - Optionally schedules a 30-min-ahead warning if that time is also in the future.
  /// - Does nothing if the follow-up is completed, has no time, or is in the past.
  Future<void> scheduleFollowUpNotification(
      Customer customer, FollowUp followUp) async {
    if (kIsWeb) return;

    final bool permissionsGranted = await requestPermissions();
    if (!permissionsGranted) {
      debugPrint('[NOTIFICATION] Cannot schedule native notification: permissions denied.');
      return;
    }

    if (followUp.id == null) {
      debugPrint('[NS] scheduleFollowUpNotification: followUp.id is null – skip.');
      return;
    }
    if (followUp.isCompleted) {
      debugPrint(
          '[NS] scheduleFollowUpNotification: followUp ${followUp.id} is completed – skip.');
      return;
    }
    if (followUp.followUpTime == null || followUp.followUpTime!.trim().isEmpty) {
      debugPrint(
          '[NS] scheduleFollowUpNotification: no followUpTime for ${followUp.id} – skip.');
      return;
    }

    // Cancel any previously scheduled notifications for this ID to avoid duplicates
    await cancelNotification(followUp.id!);

    // Parse time string (supports "HH:mm", "H:mm AM/PM", "h:mm a" formats)
    final DateTime? scheduleDate =
        parseScheduleDateTime(followUp.followUpDate, followUp.followUpTime!);

    if (scheduleDate == null) {
      debugPrint(
          '[NS] scheduleFollowUpNotification: could not parse time "${followUp.followUpTime}" – skip.');
      return;
    }

    final DateTime now = DateTime.now();
    if (!scheduleDate.isAfter(now)) {
      debugPrint(
          '[NS] scheduleFollowUpNotification: scheduled time $scheduleDate is in the past – skip.');
      return;
    }

    final int notificationId = _generateNotificationId(followUp.id!);

    // Build notification details using the pre-created channel
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
      enableVibration: true,
      playSound: true,
      // Show the notification even when the screen is off / DND
      fullScreenIntent: false,
    );

    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails);

    final String body = _buildNotificationBody(customer, followUp);

    debugPrint('[NOTIFICATION] Notification ID: $notificationId');
    debugPrint('[NOTIFICATION] Scheduled DateTime: $scheduleDate');
    debugPrint('[NOTIFICATION] Timezone: ${tz.local.name}');

    // ── Exact reminder at the follow-up time ──
    await _scheduleExact(
      id: notificationId,
      title: 'Follow-up Reminder',
      body: body,
      scheduledDate: scheduleDate,
      notificationDetails: notificationDetails,
      payload: customer.id ?? '',
    );

    // ── 30-min early warning ──
    final DateTime earlyDate = scheduleDate.subtract(const Duration(minutes: 30));
    if (earlyDate.isAfter(now)) {
      final String earlyBody =
          'Upcoming follow-up in 30 minutes with ${customer.customerName}';
      debugPrint('[NS]   early warning ID : ${notificationId + 1}');
      debugPrint('[NS]   early warning at : $earlyDate');
      await _scheduleExact(
        id: notificationId + 1,
        title: 'Upcoming Follow-up',
        body: earlyBody,
        scheduledDate: earlyDate,
        notificationDetails: notificationDetails,
        payload: customer.id ?? '',
      );
    }
  }

  Future<void> _scheduleExact({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    required NotificationDetails notificationDetails,
    required String payload,
  }) async {
    try {
      final tz.TZDateTime tzDate = tz.TZDateTime.from(scheduledDate, tz.local);

      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tzDate,
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );

      debugPrint('[NOTIFICATION] Native schedule: SUCCESS');
    } catch (e) {
      debugPrint('[NOTIFICATION] Failed to schedule native notification: $e');
    }
  }

  // ─── Cancellation ─────────────────────────────────────────────────

  Future<void> cancelNotification(String followUpId) async {
    if (kIsWeb) return;
    try {
      final int id = _generateNotificationId(followUpId);
      await _plugin.cancel(id: id);
      await _plugin.cancel(id: id + 1); // early warning
      debugPrint('[NS] Cancelled notifications id=$id and id=${id + 1} for followUpId=$followUpId');
    } catch (e) {
      debugPrint('[NS] Failed to cancel notification for $followUpId: $e');
    }
  }

  Future<void> cancelAllForCustomer(Customer customer) async {
    if (kIsWeb) return;
    debugPrint(
        '[NS] Cancelling all notifications for customer: ${customer.customerName}');
    for (final FollowUp followUp in customer.followUpHistory) {
      if (followUp.id != null) {
        await cancelNotification(followUp.id!);
      }
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────

  /// Parses a time string like "10:30", "10:30 AM", "2:30 PM" and combines
  /// with [date] to produce a [DateTime].
  DateTime? parseScheduleDateTime(DateTime date, String timeStr) {
    try {
      final String cleaned = timeStr.trim();
      // Split on colon and/or whitespace (handles "HH:mm", "H:mm AM", "H:mm PM")
      final List<String> parts = cleaned.split(RegExp(r'[:\s]+'));
      if (parts.length < 2) return null;

      int hour = int.parse(parts[0]);
      final int minute = int.parse(parts[1]);

      if (parts.length >= 3) {
        final String ampm = parts[2].toUpperCase();
        if (ampm == 'PM' && hour < 12) hour += 12;
        if (ampm == 'AM' && hour == 12) hour = 0;
      }

      return DateTime(
        date.year,
        date.month,
        date.day,
        hour,
        minute,
      );
    } catch (e) {
      debugPrint('[NS] parseScheduleDateTime error for "$timeStr": $e');
      return null;
    }
  }

  /// Builds the notification body text.
  String _buildNotificationBody(Customer customer, FollowUp followUp) {
    return 'Follow-up with ${customer.phoneNumber} is due now.';
  }

  // ─── Debug / Test ──────────────────────────────────────────────────

  /// A safe DEBUG-only method to trigger an immediate test notification.
  /// Used solely to determine if basic Android native notification delivery works
  /// independently of the scheduling logic.
  Future<void> showTestNotification() async {
    if (kIsWeb) return;
    debugPrint('[NS] Triggering immediate test notification...');

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
      enableVibration: true,
      playSound: true,
    );

    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails);

    try {
      await _plugin.show(
        id: 999999, // safe debug ID
        title: 'MCP Avadi Test Notification',
        body: 'Native notifications are working correctly.',
        notificationDetails: notificationDetails,
        payload: 'test_payload',
      );
      debugPrint('[NS] Test notification displayed successfully.');
    } catch (e) {
      debugPrint('[NS] Failed to display test notification: $e');
    }
  }
}

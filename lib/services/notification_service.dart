import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/follow_up.dart';
import '../models/customer.dart';

/// Singleton service that wraps [FlutterLocalNotificationsPlugin].
///
/// Handles:
///   - Local notification initialization & channel creation
///   - Timezone configuration (Asia/Kolkata)
///   - Exact follow-up alarm scheduling via [zonedSchedule]
///   - Notification permission requests (POST_NOTIFICATIONS + exact alarms)
///   - Tap handling & deep-link routing via [selectNotificationStream]
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
    //   '@drawable/ic_notification' is a monochrome vector for the status bar.
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@drawable/ic_notification');

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
    debugPrint('[NS] Notification channel "$_channelId" created (Importance.high).');
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
      debugPrint('[NS] POST_NOTIFICATIONS: ${notifGranted == true ? "GRANTED" : "DENIED"}');
      if (notifGranted == false) {
        isGranted = false;
      }

      // Check exact alarm permission status
      final bool? canScheduleExact =
          await androidPlugin.canScheduleExactNotifications();
      debugPrint('[NS] Exact alarm: ${canScheduleExact == true ? "AVAILABLE" : "UNAVAILABLE"}');

      if (canScheduleExact == false) {
        debugPrint('[NS] Requesting SCHEDULE_EXACT_ALARM...');
        await androidPlugin.requestExactAlarmsPermission();
        final bool? recheck =
            await androidPlugin.canScheduleExactNotifications();
        debugPrint('[NS] Exact alarm after request: $recheck');
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
      debugPrint('[NS] Cannot schedule native notification: permissions denied.');
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
    final tz.TZDateTime? scheduleDate =
        parseScheduleDateTime(followUp.followUpDate, followUp.followUpTime!);

    if (scheduleDate == null) {
      debugPrint(
          '[NS] scheduleFollowUpNotification: could not parse time "${followUp.followUpTime}" – skip.');
      return;
    }

    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
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
      icon: '@drawable/ic_notification',
      enableVibration: true,
      playSound: true,
      // Show the notification even when the screen is off / DND
      fullScreenIntent: false,
    );

    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails);

    final String body = _buildNotificationBody(customer, followUp);

    debugPrint('[NS] Notification ID: $notificationId');
    debugPrint('[NS] Requested Date: ${followUp.followUpDate}, Requested Time: ${followUp.followUpTime}');
    debugPrint('[NS] Scheduled TZDateTime: $scheduleDate');
    debugPrint('[NS] Current TZDateTime: $now');
    debugPrint('[NS] Timezone: ${tz.local.name}');

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
    final tz.TZDateTime earlyDate = scheduleDate.subtract(const Duration(minutes: 30));
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

    // Verify scheduling by listing pending notifications
    await debugPendingNotifications();
  }

  Future<void> _scheduleExact({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    required String payload,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );

      debugPrint('[NOTIFY] FOLLOW-UP NOTIFICATION SCHEDULED SUCCESSFULLY (id=$id, at=$scheduledDate)');
    } catch (e, stack) {
      debugPrint('[NS] Failed to schedule native notification: $e');
      debugPrint('[NS] StackTrace: $stack');
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
  /// with [date] to produce a [tz.TZDateTime] in Asia/Kolkata natively.
  tz.TZDateTime? parseScheduleDateTime(DateTime date, String timeStr) {
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

      // Directly build TZDateTime using tz.local (Asia/Kolkata) to avoid device timezone bias.
      return tz.TZDateTime(
        tz.local,
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
    return 'Follow-up with ${customer.customerName} (${customer.phoneNumber}) is due now.';
  }

  // ─── Debug / Test ──────────────────────────────────────────────────

  /// Inspect currently pending notifications scheduled in the OS.
  Future<void> debugPendingNotifications() async {
    if (kIsWeb) return;
    try {
      final List<PendingNotificationRequest> pending = await _plugin.pendingNotificationRequests();
      debugPrint('[NS] --- PENDING NOTIFICATIONS (${pending.length}) ---');
      for (var req in pending) {
        debugPrint('[NS]  - ID: ${req.id}, Title: ${req.title}, Body: ${req.body}');
      }
      debugPrint('[NS] ----------------------------------');
    } catch (e) {
      debugPrint('[NS] Error fetching pending notifications: $e');
    }
  }

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
      icon: '@drawable/ic_notification',
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

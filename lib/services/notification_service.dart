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
    debugPrint('[NS] Notification channel created: $_channelId');
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

  Future<void> requestPermissions() async {
    if (kIsWeb) return;

    debugPrint('[NS] Requesting notification permissions...');

    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin == null) return;

      // Request POST_NOTIFICATIONS permission (Android 13+)
      final bool? notifGranted =
          await androidPlugin.requestNotificationsPermission();
      debugPrint('[NS] POST_NOTIFICATIONS granted: $notifGranted');

      // Check exact alarm permission status
      final bool? canScheduleExact =
          await androidPlugin.canScheduleExactNotifications();
      debugPrint('[NS] canScheduleExactNotifications: $canScheduleExact');

      // On Android 12 (API 31-32), SCHEDULE_EXACT_ALARM may need explicit grant.
      // On Android 13+ (API 33+), USE_EXACT_ALARM in the manifest is sufficient
      // and does NOT require a runtime grant.
      // We only request the runtime permission on API <=32.
      if (canScheduleExact == false) {
        debugPrint(
            '[NS] Exact alarm not available – requesting SCHEDULE_EXACT_ALARM...');
        await androidPlugin.requestExactAlarmsPermission();
        final bool? recheck =
            await androidPlugin.canScheduleExactNotifications();
        debugPrint('[NS] Exact alarm after request: $recheck');
      }
    }
  }

  // ─── App-launch check ─────────────────────────────────────────────

  Future<void> checkPendingNotification() async {
    if (kIsWeb) return;

    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details != null &&
        details.didNotificationLaunchApp &&
        details.notificationResponse?.payload != null) {
      debugPrint(
          '[NS] App launched from notification: payload=${details.notificationResponse!.payload}');
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

    debugPrint('[NS] Scheduling notification:');
    debugPrint('  followUpId : ${followUp.id}');
    debugPrint('  notificationId : $notificationId');
    debugPrint('  customer   : ${customer.customerName}');
    debugPrint('  scheduleDate : $scheduleDate');
    debugPrint('  timezone   : ${tz.local.name}');

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

  /// Internal helper: schedules a single exact notification using [zonedSchedule].
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
      debugPrint('[NS] _scheduleExact id=$id at $tzDate (tz=${tz.local.name})');

      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tzDate,
        notificationDetails: notificationDetails,
        // exactAllowWhileIdle fires the alarm even when the device is in
        // low-power (Doze) mode, but only on APIs where the permission is granted.
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );

      debugPrint('[NS] Notification id=$id scheduled successfully.');
    } catch (e) {
      debugPrint('[NS] Failed to schedule notification id=$id: $e');
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
    final StringBuffer buf = StringBuffer();
    buf.write('Follow up with ${customer.customerName}');
    if (followUp.notes.isNotEmpty) {
      buf.write(': ${followUp.notes}');
    }
    return buf.toString();
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

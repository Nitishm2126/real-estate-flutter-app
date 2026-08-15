import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

import '../models/follow_up.dart';
import '../models/customer.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    if (!kIsWeb) {
      await _configureLocalTimeZone();
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    // Currently Android only setup, can add iOS later if needed
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Here we could handle navigating to a specific screen when the user taps
        debugPrint('Notification clicked with payload: ${response.payload}');
      },
    );

    _isInitialized = true;
  }

  Future<void> _configureLocalTimeZone() async {
    tz.initializeTimeZones();
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
    } catch (e) {
      debugPrint('Could not get local timezone: $e');
    }
  }

  Future<void> requestPermissions() async {
    if (kIsWeb) return;

    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        await androidImplementation.requestNotificationsPermission();
        await androidImplementation.requestExactAlarmsPermission();
      }
    }
  }

  /// Convert a UUID string into a reliable 32-bit integer for notification ID
  int _generateNotificationId(String uuid) {
    // Remove dashes and take the first 7 hex characters to ensure it fits in a 32-bit positive integer
    final cleanUuid = uuid.replaceAll('-', '');
    if (cleanUuid.length < 7) return uuid.hashCode;
    final hexStr = cleanUuid.substring(0, 7);
    return int.parse(hexStr, radix: 16);
  }

  Future<void> scheduleFollowUpNotification(
      Customer customer, FollowUp followUp) async {
    if (kIsWeb) return; // Local notifications not supported on web in this way

    // Only schedule if we have an ID and it's not completed
    if (followUp.id == null || followUp.isCompleted) {
      return;
    }

    // Must have a valid time to schedule
    if (followUp.followUpTime == null || followUp.followUpTime!.isEmpty) {
      return;
    }

    // Parse the time
    try {
      final parts = followUp.followUpTime!.split(RegExp(r'[: ]'));
      if (parts.length >= 2) {
        int hour = int.parse(parts[0]);
        final int minute = int.parse(parts[1]);
        if (parts.length > 2) {
          final ampm = parts[2].toUpperCase();
          if (ampm == 'PM' && hour < 12) hour += 12;
          if (ampm == 'AM' && hour == 12) hour = 0;
        }

        final scheduleDate = DateTime(
          followUp.followUpDate.year,
          followUp.followUpDate.month,
          followUp.followUpDate.day,
          hour,
          minute,
        );

        // Do not schedule in the past
        if (scheduleDate.isBefore(DateTime.now())) {
          return;
        }

        final tz.TZDateTime scheduledTzDate =
            tz.TZDateTime.from(scheduleDate, tz.local);

        final notificationId = _generateNotificationId(followUp.id!);

        const AndroidNotificationDetails androidPlatformChannelSpecifics =
            AndroidNotificationDetails(
          'follow_up_reminders',
          'Follow-up Reminders',
          channelDescription: 'Reminders for customer follow-ups',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/launcher_icon',
        );

        const NotificationDetails platformChannelSpecifics =
            NotificationDetails(android: androidPlatformChannelSpecifics);

        String body = 'Follow-up with ${customer.customerName}';
        if (followUp.notes.isNotEmpty) {
          body += ': ${followUp.notes}';
        }

        await _flutterLocalNotificationsPlugin.zonedSchedule(
          id: notificationId,
          title: 'MCP Avadi - Follow-up Reminder',
          body: body,
          scheduledDate: scheduledTzDate,
          notificationDetails: platformChannelSpecifics,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: customer.id, // Pass customer ID for later navigation
        );

        debugPrint(
            'Scheduled notification $notificationId for $scheduledTzDate');
      }
    } catch (e) {
      debugPrint('Failed to schedule notification: $e');
    }
  }

  Future<void> cancelNotification(String followUpId) async {
    if (kIsWeb) return;
    try {
      final id = _generateNotificationId(followUpId);
      await _flutterLocalNotificationsPlugin.cancel(id: id);
      debugPrint('Canceled notification $id');
    } catch (e) {
      debugPrint('Failed to cancel notification: $e');
    }
  }

  Future<void> cancelAllForCustomer(Customer customer) async {
    if (kIsWeb) return;
    for (final followUp in customer.followUpHistory) {
      if (followUp.id != null) {
        await cancelNotification(followUp.id!);
      }
    }
    // Also cancel the main customer's generated ID if needed, but since we map entirely from history now, it's fine.
  }
}

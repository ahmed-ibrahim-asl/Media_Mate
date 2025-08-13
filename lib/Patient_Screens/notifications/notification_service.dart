import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Singleton service that handles local notifications.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _tzInitialized = false;

  Future<void> init() async {
    if (_initialized) return;

    // Make sure you have a monochrome icon named 'app_icon' in all mipmap-* folders
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const settings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
    );

    await _plugin.initialize(settings);
    await _ensureTimeZone();

    debugPrint('[NotificationService] Initialized');

    // Ask runtime permission now
    final granted = await requestPermissions();
    debugPrint('[NotificationService] Permission granted: $granted');

    // Create high-importance channel on Android
    const channel = AndroidNotificationChannel(
      'meds_reminders',
      'Medication Reminders',
      description: 'Daily reminders to take your medication',
      importance: Importance.high,
    );
    final android =
        _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    await android?.createNotificationChannel(channel);

    _initialized = true;
  }

  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      final android =
          _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
      final bool? granted = await android?.requestNotificationsPermission();
      return granted ?? true;
    }
    final ios =
        _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
    final mac =
        _plugin
            .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin
            >();
    final bool iosOk =
        (await ios?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        )) ??
        true;
    final bool macOk =
        (await mac?.requestPermissions(alert: true, sound: true)) ?? true;
    return iosOk && macOk;
  }

  Future<void> showNow({required String title, required String body}) async {
    await init();
    debugPrint('[NotificationService] showNow: $title / $body');

    const androidDetails = AndroidNotificationDetails(
      'meds_reminders',
      'Medication Reminders',
      channelDescription: 'Daily reminders to take your medication',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );
    const details = NotificationDetails(android: androidDetails);
    await _plugin.show(_randomId(), title, body, details);
  }

  Future<void> scheduleDailyReminderForDoc({
    required String uid,
    required String docId,
    required int minutesSinceMidnight,
    required String title,
    required String body,
  }) async {
    await init();
    debugPrint(
      '[NotificationService] Scheduling $title at $minutesSinceMidnight minutes',
    );

    final id = _stableId(uid, docId, minutesSinceMidnight);
    final now = tz.TZDateTime.now(tz.local);
    final hour = minutesSinceMidnight ~/ 60;
    final minute = minutesSinceMidnight % 60;

    tz.TZDateTime scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      'meds_reminders',
      'Medication Reminders',
      channelDescription: 'Daily reminders to take your medication',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );
    const details = NotificationDetails(android: androidDetails);

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } on PlatformException catch (e) {
      debugPrint(
        '[NotificationService] Exact alarm failed: $e, trying inexact',
      );
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  Future<void> cancelAll() => _plugin.cancelAll();

  int _stableId(String uid, String docId, int minutes) {
    final h = uid.hashCode ^ (docId.hashCode * 31) ^ minutes.hashCode;
    return h & 0x7fffffff;
  }

  int _randomId() => Random().nextInt(0x7fffffff);

  Future<void> _ensureTimeZone() async {
    if (_tzInitialized) return;
    tz.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
    _tzInitialized = true;
  }
}

import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_10y.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// The device side of the daily reminders (S5-3). Local notifications:
/// they are scheduled on the phone, so there is no server, no Firebase and no
/// Groq quota involved.
abstract interface class ReminderScheduler {
  /// Asks the user for the notification permission; true when granted.
  Future<bool> requestPermission();

  /// Whether notifications are allowed right now (the user can revoke them in
  /// the phone's settings at any time).
  Future<bool> hasPermission();

  /// Schedules a notification at [at], local time, repeated every week on
  /// that weekday and time until it is cancelled. [id] makes a later call
  /// replace it.
  Future<void> scheduleWeekly({
    required int id,
    required DateTime at,
    required String title,
    required String body,
  });

  Future<void> cancelAll();

  /// Fires when the user taps a reminder.
  Stream<void> get taps;
}

class LocalNotificationsScheduler implements ReminderScheduler {
  static const _channel = AndroidNotificationDetails(
    'reminders',
    'Recordatorios',
    channelDescription: 'Un saludo diario de marlix, a la hora que elijas',
  );

  final _plugin = FlutterLocalNotificationsPlugin();
  final _taps = StreamController<void>.broadcast();
  Future<void>? _initialized;

  Future<void> _ensureInitialized() => _initialized ??= _initialize();

  Future<void> _initialize() async {
    tz_data.initializeTimeZones();
    // The reminders follow the phone's clock, daylight saving time included.
    tz.setLocalLocation(tz.getLocation((await FlutterTimezone.getLocalTimezone()).identifier));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (_) => _taps.add(null),
    );
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  @override
  Stream<void> get taps {
    // A tap is only delivered once the plugin is initialized.
    unawaited(_ensureInitialized());
    return _taps.stream;
  }

  @override
  Future<bool> requestPermission() async {
    await _ensureInitialized();
    return await _android?.requestNotificationsPermission() ?? false;
  }

  @override
  Future<bool> hasPermission() async {
    await _ensureInitialized();
    return await _android?.areNotificationsEnabled() ?? false;
  }

  @override
  Future<void> scheduleWeekly({
    required int id,
    required DateTime at,
    required String title,
    required String body,
  }) async {
    await _ensureInitialized();
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime(tz.local, at.year, at.month, at.day, at.hour, at.minute),
      notificationDetails: const NotificationDetails(android: _channel),
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      // A few minutes late is fine for a greeting, and inexact alarms avoid
      // the exact-alarm permission.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  @override
  Future<void> cancelAll() async {
    await _ensureInitialized();
    await _plugin.cancelAll();
  }
}

final reminderSchedulerProvider = Provider<ReminderScheduler>(
  (ref) => LocalNotificationsScheduler(),
);

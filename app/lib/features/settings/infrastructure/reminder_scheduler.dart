import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_10y.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../application/reminder_scheduler.dart';

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
    // The plugin delivers reminder taps only after initialization.
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
      // Inexact alarms avoid requiring the Android exact-alarm permission.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  @override
  Future<void> cancelAll() async {
    await _ensureInitialized();
    await _plugin.cancelAll();
  }
}

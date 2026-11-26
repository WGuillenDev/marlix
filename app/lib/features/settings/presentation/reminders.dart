import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/storage_providers.dart';
import '../composition/reminder_scheduler_provider.dart';
import '../domain/reminder_config.dart';

final reminderConfigProvider = Provider<ReminderConfig>(
  (ref) => throw UnimplementedError('reminderConfigProvider must be overridden'),
);

typedef ReminderSettings = ({bool enabled, ReminderTime time});

class RemindersController extends Notifier<ReminderSettings> {
  static const enabledKey = 'reminders_enabled';
  static const timeKey = 'reminders_time';

  static const notificationTitle = 'marlix';

  var _queue = Future<void>.value();

  @override
  ReminderSettings build() {
    final preferences = ref.read(preferencesProvider);
    final saved = preferences.getString(timeKey);
    return (
      enabled: preferences.getBool(enabledKey) ?? false,
      time: saved == null ? ref.read(reminderConfigProvider).defaultTime : _parse(saved),
    );
  }

  ReminderTime _parse(String saved) {
    try {
      return ReminderConfig.parseTime(saved);
    } on Object catch (_) {
      return ref.read(reminderConfigProvider).defaultTime;
    }
  }

  Future<bool> enable() async {
    if (!await ref.read(reminderSchedulerProvider).requestPermission()) return false;
    await ref.read(preferencesProvider).setBool(enabledKey, true);
    state = (enabled: true, time: state.time);
    await reschedule();
    return true;
  }

  Future<void> disable() async {
    await ref.read(preferencesProvider).setBool(enabledKey, false);
    state = (enabled: false, time: state.time);
    await cancel();
  }

  Future<void> setTime(ReminderTime time) async {
    await ref.read(preferencesProvider).setString(timeKey, ReminderConfig.formatTime(time));
    state = (enabled: state.enabled, time: time);
    await reschedule();
  }

  // Schedule each weekday separately so reminders rotate even if the app stays closed.
  Future<void> reschedule() => _enqueue(() async {
    if (!state.enabled) return;
    final scheduler = ref.read(reminderSchedulerProvider);
    if (!await scheduler.hasPermission()) {
      await ref.read(preferencesProvider).setBool(enabledKey, false);
      state = (enabled: false, time: state.time);
      return;
    }
    final messages = ref.read(reminderConfigProvider).messages;
    await scheduler.cancelAll();
    for (final at in nextWeek(DateTime.now(), state.time)) {
      await scheduler.scheduleWeekly(
        id: at.weekday,
        at: at,
        title: notificationTitle,
        body: messages[at.weekday - 1],
      );
    }
  });

  /// Clear pending notifications at sign-out without changing the user's preference.
  Future<void> cancel() => _enqueue(ref.read(reminderSchedulerProvider).cancelAll);

  // Serialize scheduling because app startup can trigger several updates.
  Future<void> _enqueue(Future<void> Function() action) {
    final run = _queue.then((_) => action());
    _queue = run.catchError((_) {});
    return run;
  }

  static List<DateTime> nextWeek(DateTime now, ReminderTime time) {
    var first = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    if (!first.isAfter(now)) {
      first = DateTime(now.year, now.month, now.day + 1, time.hour, time.minute);
    }
    return [
      for (var day = 0; day < DateTime.daysPerWeek; day++)
        DateTime(first.year, first.month, first.day + day, time.hour, time.minute),
    ];
  }
}

final remindersProvider = NotifierProvider<RemindersController, ReminderSettings>(
  RemindersController.new,
);

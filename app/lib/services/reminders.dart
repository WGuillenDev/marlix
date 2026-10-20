import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/reminder_config.dart';
import 'help_resources.dart';
import 'reminder_scheduler.dart';

/// Overridden in `main` with the file loaded before the first frame, and in tests.
final reminderConfigProvider = Provider<ReminderConfig>(
  (ref) => throw UnimplementedError('reminderConfigProvider must be overridden'),
);

/// Whether the user turned the daily reminders on, and at what time.
typedef ReminderSettings = ({bool enabled, ReminderTime time});

/// The daily reminders (S5-3): one greeting a day at the time the user picks,
/// with no streaks. They are off until [enable] gets the system permission.
class RemindersController extends Notifier<ReminderSettings> {
  static const enabledKey = 'reminders_enabled';
  static const timeKey = 'reminders_time';

  /// The title of every reminder.
  static const notificationTitle = 'marlix';

  var _queue = Future<void>.value();

  @override
  ReminderSettings build() {
    final preferences = ref.read(sharedPreferencesProvider);
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

  /// Asks for the notification permission and turns the reminders on. False
  /// when the user does not allow them, and then nothing changes. Onboarding
  /// (S5-5) calls this too.
  Future<bool> enable() async {
    if (!await ref.read(reminderSchedulerProvider).requestPermission()) return false;
    await ref.read(sharedPreferencesProvider).setBool(enabledKey, true);
    state = (enabled: true, time: state.time);
    await reschedule();
    return true;
  }

  /// Turns them off and cancels the pending ones.
  Future<void> disable() async {
    await ref.read(sharedPreferencesProvider).setBool(enabledKey, false);
    state = (enabled: false, time: state.time);
    await cancel();
  }

  Future<void> setTime(ReminderTime time) async {
    await ref.read(sharedPreferencesProvider).setString(timeKey, ReminderConfig.formatTime(time));
    state = (enabled: state.enabled, time: time);
    await reschedule();
  }

  /// Schedules the next seven days, one text per weekday, each repeating every
  /// week: they keep going even if the app is never opened again. Run when the
  /// app opens too, to follow a permission revoked or a time zone change.
  Future<void> reschedule() => _enqueue(() async {
    if (!state.enabled) return;
    final scheduler = ref.read(reminderSchedulerProvider);
    // The user can revoke the permission in the phone's settings.
    if (!await scheduler.hasPermission()) {
      await ref.read(sharedPreferencesProvider).setBool(enabledKey, false);
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

  /// Cancels the pending reminders without changing the setting, for when the
  /// session ends.
  Future<void> cancel() => _enqueue(ref.read(reminderSchedulerProvider).cancelAll);

  /// Runs one change at a time, in order: opening the app triggers several.
  Future<void> _enqueue(Future<void> Function() action) {
    final run = _queue.then((_) => action());
    _queue = run.catchError((_) {});
    return run;
  }

  /// The next seven occurrences of [time] after [now], one per weekday.
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

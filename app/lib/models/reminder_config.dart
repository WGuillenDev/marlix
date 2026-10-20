import 'json_reader.dart';

/// A time of day, without a date or a time zone.
typedef ReminderTime = ({int hour, int minute});

/// What the daily reminders say and when they go out by default
/// (`assets/config/reminders.json`, S5-3). Read from configuration so the
/// texts and the hour change without touching the code.
class ReminderConfig {
  ReminderConfig({required this.defaultTime, required this.messages}) {
    // One text per day of the week, so none repeats inside a week.
    if (messages.length < DateTime.daysPerWeek || messages.any((text) => text.trim().isEmpty)) {
      throw const InvalidJsonException('"messages" needs at least 7 non-empty texts');
    }
  }

  factory ReminderConfig.fromJson(Map<String, Object?> json) => ReminderConfig(
    defaultTime: parseTime(json.requireString('defaultTime')),
    messages: json.requireStringList('messages'),
  );

  /// The hour of the reminder until the user picks another one.
  final ReminderTime defaultTime;

  /// The bank the texts rotate through.
  final List<String> messages;

  /// Parses `HH:MM`, 24-hour clock.
  static ReminderTime parseTime(String value) {
    final match = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$').firstMatch(value);
    if (match == null) throw InvalidJsonException('"$value" is not a HH:MM time');
    return (hour: int.parse(match[1]!), minute: int.parse(match[2]!));
  }

  static String formatTime(ReminderTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}

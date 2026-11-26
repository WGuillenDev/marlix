import '../../../shared/json_reader.dart';

typedef ReminderTime = ({int hour, int minute});

class ReminderConfig {
  ReminderConfig({required this.defaultTime, required this.messages}) {
    if (messages.length < DateTime.daysPerWeek || messages.any((text) => text.trim().isEmpty)) {
      throw const InvalidJsonException('"messages" needs at least 7 non-empty texts');
    }
  }

  factory ReminderConfig.fromJson(Map<String, Object?> json) => ReminderConfig(
    defaultTime: parseTime(json.requireString('defaultTime')),
    messages: json.requireStringList('messages'),
  );

  final ReminderTime defaultTime;

  final List<String> messages;

  static ReminderTime parseTime(String value) {
    final match = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$').firstMatch(value);
    if (match == null) throw InvalidJsonException('"$value" is not a HH:MM time');
    return (hour: int.parse(match[1]!), minute: int.parse(match[2]!));
  }

  static String formatTime(ReminderTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}

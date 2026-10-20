import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:marlix/models/json_reader.dart';
import 'package:marlix/models/reminder_config.dart';

List<String> week(String text) => List.filled(7, text);

void main() {
  final shipped = ReminderConfig.fromJson(
    jsonDecode(File('assets/config/reminders.json').readAsStringSync()) as Map<String, Object?>,
  );

  test('the shipped configuration greets at 19:00 with a different text each weekday', () {
    expect(shipped.defaultTime, (hour: 19, minute: 0));
    expect(shipped.messages.length, greaterThanOrEqualTo(7));
    expect(shipped.messages.toSet().length, shipped.messages.length);
  });

  // No guilt, no sad avatar, no streaks or day counters, and nothing that
  // depends on the user: the text shows on the lock screen (S5-3).
  test('no shipped text uses guilt, streaks, counters or user data', () {
    final forbidden = RegExp(
      r'\d|racha|extrañ|triste|falta|culpa|olvid|abandon|días|hace (un )?tiempo',
      caseSensitive: false,
    );
    for (final text in shipped.messages) {
      expect(forbidden.hasMatch(text), isFalse, reason: text);
    }
  });

  test('parses and formats HH:MM times', () {
    expect(ReminderConfig.parseTime('07:05'), (hour: 7, minute: 5));
    expect(ReminderConfig.formatTime((hour: 7, minute: 5)), '07:05');
    for (final bad in ['7:05', '24:00', '12:60', 'noche']) {
      expect(
        () => ReminderConfig.parseTime(bad),
        throwsA(isA<InvalidJsonException>()),
        reason: bad,
      );
    }
  });

  test('rejects a bank shorter than a week or with empty texts', () {
    expect(
      () => ReminderConfig(defaultTime: (hour: 19, minute: 0), messages: const ['a']),
      throwsA(isA<InvalidJsonException>()),
    );
    expect(
      () => ReminderConfig(defaultTime: (hour: 19, minute: 0), messages: [...week('a'), ' ']),
      throwsA(isA<InvalidJsonException>()),
    );
  });

  test('rejects wrong types', () {
    expect(
      () => ReminderConfig.fromJson({'defaultTime': 19, 'messages': week('a')}),
      throwsA(isA<InvalidJsonException>()),
    );
  });
}

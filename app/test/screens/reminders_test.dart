import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marlix/screens/chat/chat_screen.dart';
import 'package:marlix/screens/settings_screen.dart';
import 'package:marlix/services/reminders.dart';

import '../helpers/fake_backend.dart';

Future<void> openSettings(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Ajustes'));
  await tester.pumpAndSettle();
}

/// Settings has more than one switch: this is the one in the reminders card.
Finder get reminderSwitch => find.descendant(
  of: find.ancestor(of: find.text('Recordatorios'), matching: find.byType(Material)).first,
  matching: find.byType(Switch),
);

ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(ChatScreen, skipOffstage: false)));

Future<void> reopen(WidgetTester tester) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pumpAndSettle();
}

const weekdays = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];

void main() {
  group('the next week of a time', () {
    test('starts today when the time has not passed yet', () {
      final days = RemindersController.nextWeek(DateTime(2026, 10, 19, 8), (hour: 19, minute: 0));

      expect(days.first, DateTime(2026, 10, 19, 19));
      expect(days.last, DateTime(2026, 10, 25, 19));
      expect(days.map((d) => d.weekday).toSet(), hasLength(7));
    });

    test('starts tomorrow when the time already passed today', () {
      final days = RemindersController.nextWeek(DateTime(2026, 10, 19, 19), (hour: 19, minute: 0));

      expect(days.first, DateTime(2026, 10, 20, 19));
    });

    test('crosses the end of the month', () {
      final days = RemindersController.nextWeek(DateTime(2026, 10, 30, 20), (hour: 7, minute: 30));

      expect(days.first, DateTime(2026, 10, 31, 7, 30));
      expect(days.last, DateTime(2026, 11, 6, 7, 30));
    });
  });

  testWidgets('they are off by default: nothing is scheduled', (tester) async {
    final reminders = FakeReminderScheduler();
    await openChat(tester, reminders: reminders);
    await openSettings(tester);

    expect(tester.widget<Switch>(reminderSwitch).value, isFalse);
    expect(find.text('Hora del saludo'), findsNothing);
    expect(reminders.scheduled, isEmpty);
  });

  group('turning them on', () {
    testWidgets('asks for the permission and greets every day at 19:00', (tester) async {
      final reminders = FakeReminderScheduler();
      await openChat(tester, reminders: reminders);
      await openSettings(tester);

      await tester.tap(reminderSwitch);
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(reminderSwitch).value, isTrue);
      expect(find.text('Hora del saludo'), findsOneWidget);
      expect(find.text('19:00'), findsOneWidget);
      expect(reminders.scheduled, hasLength(7));
      for (final reminder in reminders.scheduled) {
        expect((reminder.at.hour, reminder.at.minute), (19, 0));
        expect(reminder.id, reminder.at.weekday);
        expect(reminder.body, weekdays[reminder.at.weekday - 1], reason: 'a text per weekday');
        expect(reminder.title, 'marlix');
      }
      expect(reminders.scheduled.map((r) => r.at.weekday).toSet(), hasLength(7));
    });

    testWidgets('stays off and explains how to allow them when the permission is denied', (
      tester,
    ) async {
      final reminders = FakeReminderScheduler()..grantsPermission = false;
      await openChat(tester, reminders: reminders);
      await openSettings(tester);

      await tester.tap(reminderSwitch);
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(reminderSwitch).value, isFalse);
      expect(find.textContaining('permite las notificaciones'), findsOneWidget);
      expect(reminders.scheduled, isEmpty);
    });

    testWidgets('exposes the function onboarding uses, with the same result', (tester) async {
      final reminders = FakeReminderScheduler();
      await openChat(tester, reminders: reminders);

      final granted = await containerOf(tester).read(remindersProvider.notifier).enable();
      await tester.pumpAndSettle();

      expect(granted, isTrue);
      expect(reminders.scheduled, hasLength(7));
    });
  });

  group('while they are on', () {
    final on = {RemindersController.enabledKey: true};

    testWidgets('the time row opens a picker in Spanish', (tester) async {
      await openChat(tester, savedPreferences: on);
      await openSettings(tester);

      await tester.tap(find.text('Hora del saludo'));
      await tester.pumpAndSettle();
      expect(find.text('¿A qué hora te saludo?'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('PM'), findsNothing, reason: '24-hour clock');

      await tester.tap(find.text('Listo'));
      await tester.pumpAndSettle();
      expect(find.text('19:00'), findsOneWidget);
    });

    testWidgets('picking another time moves every reminder to it', (tester) async {
      final reminders = FakeReminderScheduler();
      await openChat(tester, reminders: reminders, savedPreferences: on);
      await openSettings(tester);

      await containerOf(tester).read(remindersProvider.notifier).setTime((hour: 8, minute: 30));
      await tester.pumpAndSettle();

      expect(find.text('08:30'), findsOneWidget);
      expect(reminders.scheduled, hasLength(7));
      expect(reminders.scheduled.map((r) => (r.at.hour, r.at.minute)).toSet(), {(8, 30)});
    });

    testWidgets('the picked time is kept for the next time the app opens', (tester) async {
      final reminders = FakeReminderScheduler();
      await openChat(
        tester,
        reminders: reminders,
        savedPreferences: {...on, RemindersController.timeKey: '07:15'},
      );
      await tester.pumpAndSettle();

      expect(reminders.scheduled.map((r) => (r.at.hour, r.at.minute)).toSet(), {(7, 15)});
    });

    testWidgets('opening the app replaces the pending ones instead of adding more', (tester) async {
      final reminders = FakeReminderScheduler()
        ..scheduled.add((id: 9, at: DateTime(2020), title: 'marlix', body: 'viejo'));
      await openChat(tester, reminders: reminders, savedPreferences: on);
      await tester.pumpAndSettle();
      await reopen(tester);

      expect(reminders.scheduled.map((r) => r.body), isNot(contains('viejo')));
      expect(reminders.scheduled, hasLength(7));
    });

    testWidgets('turning them off cancels them for good', (tester) async {
      final reminders = FakeReminderScheduler();
      await openChat(tester, reminders: reminders, savedPreferences: on);
      await tester.pumpAndSettle();
      await openSettings(tester);
      expect(tester.widget<Switch>(reminderSwitch).value, isTrue);

      await tester.tap(reminderSwitch);
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(reminderSwitch).value, isFalse);
      expect(reminders.scheduled, isEmpty);

      await reopen(tester);
      expect(reminders.scheduled, isEmpty);
    });

    testWidgets('revoking the permission in the phone settings turns them off', (tester) async {
      final reminders = FakeReminderScheduler();
      await openChat(tester, reminders: reminders, savedPreferences: on);
      await tester.pumpAndSettle();

      reminders.grantsPermission = false;
      await reopen(tester);
      await openSettings(tester);

      expect(tester.widget<Switch>(reminderSwitch).value, isFalse);
    });

    testWidgets('signing out cancels them and signing in schedules them again', (tester) async {
      final reminders = FakeReminderScheduler();
      final auth = FakeAuthService(userId: 'user-ana@example.com');
      await openChat(tester, reminders: reminders, auth: auth, savedPreferences: on);
      await tester.pumpAndSettle();
      expect(reminders.scheduled, hasLength(7));

      await auth.signOut();
      await tester.pumpAndSettle();
      expect(reminders.scheduled, isEmpty);

      await auth.signIn(email: 'ana@example.com', password: 'contraseña-de-ana');
      await tester.pumpAndSettle();
      expect(reminders.scheduled, hasLength(7));
    });

    testWidgets('tapping one while settings is open lands on the chat', (tester) async {
      final reminders = FakeReminderScheduler();
      await openChat(tester, reminders: reminders, savedPreferences: on);
      await openSettings(tester);
      expect(find.byType(SettingsScreen), findsOneWidget);

      reminders.tap();
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScreen), findsNothing);
      expect(find.byType(ChatScreen), findsOneWidget);
    });
  });
}

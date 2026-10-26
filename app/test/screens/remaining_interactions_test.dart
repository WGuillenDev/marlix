import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marlix/models/usage.dart';
import 'package:marlix/screens/help_screen.dart';
import 'package:marlix/theme/app_theme.dart';
import 'package:marlix/widgets/chat_states.dart';

import '../helpers/fake_backend.dart';

Usage _usage({required int remaining, int limit = 100}) => Usage(
  used: limit - remaining,
  limit: limit,
  remaining: remaining,
  resetsAt: DateTime.utc(2026, 10, 26, 6),
);

/// The pill that shows the count, looked up by its text.
Color _chipColor(WidgetTester tester, String text) {
  final box = tester.widget<DecoratedBox>(
    find.ancestor(of: find.text(text), matching: find.byType(DecoratedBox)).first,
  );
  return (box.decoration as BoxDecoration).color!;
}

void main() {
  group('Usage.isLow', () {
    test('warns at 10 % of the cap or less, never at zero', () {
      expect(_usage(remaining: 11).isLow, isFalse);
      expect(_usage(remaining: 10).isLow, isTrue);
      expect(_usage(remaining: 1).isLow, isTrue);
      expect(_usage(remaining: 0).isLow, isFalse, reason: 'there it is the limit card');
    });

    test('follows the cap of the plan', () {
      expect(_usage(remaining: 20, limit: 200).isLow, isTrue);
      expect(_usage(remaining: 21, limit: 200).isLow, isFalse);
      expect(_usage(remaining: 1, limit: 5).isLow, isTrue, reason: 'a small cap rounds up');
    });

    test('a cap of zero never warns', () {
      expect(_usage(remaining: 0, limit: 0).isLow, isFalse);
    });
  });

  testWidgets('with plenty left it only shows the count', (tester) async {
    await openChat(tester, backend: FakeBackend()..usageRemaining = 11);
    await tester.pump();

    expect(find.text('Te quedan 11 mensajes hoy'), findsOneWidget);
    expect(_chipColor(tester, 'Te quedan 11 mensajes hoy'), AppColors.white);
  });

  testWidgets('with few left it warns and says when they renew', (tester) async {
    await openChat(tester, backend: FakeBackend()..usageRemaining = 10);
    await tester.pump();

    const text = 'Te quedan 10 mensajes hoy. Se renuevan a medianoche.';
    expect(find.text(text), findsOneWidget);
    expect(_chipColor(tester, text), AppColors.warningBackground);
  });

  testWidgets('the last one is worded in the singular', (tester) async {
    await openChat(tester, backend: FakeBackend()..usageRemaining = 1);
    await tester.pump();

    expect(find.text('Te queda 1 mensaje hoy. Se renuevan a medianoche.'), findsOneWidget);
  });

  testWidgets('the warning appears while chatting, when the count crosses the line', (
    tester,
  ) async {
    final backend = await openChat(tester, backend: FakeBackend()..usageRemaining = 12);
    await tester.pump();
    await type(tester, 'Uno más');
    await tester.tap(sendButton);
    backend.answer('Uno más', 'Claro que sí.', remaining: 10);
    await settle(tester);

    expect(find.textContaining('Se renuevan a medianoche'), findsOneWidget);
    expect(find.byType(DailyLimitCard), findsNothing);
  });

  testWidgets('when they run out the card explains the renewal and help stays one tap away', (
    tester,
  ) async {
    await openChat(tester, backend: FakeBackend()..usageRemaining = 0);
    await tester.pump();

    expect(find.byType(DailyLimitCard), findsOneWidget);
    expect(
      find.text('Mañana volvemos a conversar: los mensajes se renuevan a medianoche.'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Ayuda'));
    await tester.pumpAndSettle();
    expect(find.byType(HelpScreen), findsOneWidget, reason: 'the header button still works');
  });
}

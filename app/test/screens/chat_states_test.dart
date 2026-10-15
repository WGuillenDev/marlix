import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marlix/screens/chat/chat_screen.dart';
import 'package:marlix/screens/help_screen.dart';
import 'package:marlix/widgets/chat_states.dart';
import 'package:marlix/widgets/phone_format.dart';
import 'package:marlix/widgets/message_bubble.dart';
import 'package:marlix/widgets/typing_indicator.dart';

import '../helpers/fake_backend.dart';

Finder get retryButton => find.widgetWithText(OutlinedButton, 'Reintentar');

void main() {
  testWidgets('shows the loading indicator while waiting for the reply', (tester) async {
    final backend = await openChat(tester);
    await type(tester, 'Hola');
    await tester.tap(sendButton);
    await tester.pump();

    expect(find.byType(TypingIndicator), findsOneWidget);

    backend.answer('Hola', '¡Hola!');
    await settle(tester);
    expect(find.byType(TypingIndicator), findsNothing);
  });

  testWidgets('a slow reply shows the waking up banner until it arrives', (tester) async {
    final backend = await openChat(tester);
    await type(tester, 'Hola');
    await tester.tap(sendButton);
    await tester.pump(ChatScreen.slowReplyAfter - const Duration(seconds: 1));
    expect(find.byType(WakingUpBanner), findsNothing);

    await tester.pump(const Duration(seconds: 1));
    expect(
      find.text('marlix se está despertando… esto puede tardar unos segundos.'),
      findsOneWidget,
    );

    backend.answer('Hola', '¡Hola! Ya estoy acá.');
    await settle(tester);
    expect(find.byType(WakingUpBanner), findsNothing);
  });

  testWidgets('a network failure keeps the message and retries it', (tester) async {
    final backend = await openChat(tester);
    await type(tester, 'Hoy fue un día largo.');
    await tester.tap(sendButton);
    await tester.pump();
    backend.dropConnection();
    await settle(tester);

    expect(find.text('Hoy fue un día largo.'), findsOneWidget, reason: 'the text is not lost');
    expect(find.text('No se pudo enviar. Revisá tu conexión a internet.'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Vos, no enviado')), findsOneWidget);
    expect(find.byType(TypingIndicator), findsNothing);

    backend.reply = Completer();
    await tester.tap(retryButton);
    await tester.pump();
    expect(find.byType(TypingIndicator), findsOneWidget);
    expect(retryButton, findsNothing);

    backend.answer('Hoy fue un día largo.', 'Uy, contame qué pasó.');
    await settle(tester);

    expect(backend.sent, ['Hoy fue un día largo.', 'Hoy fue un día largo.']);
    expect(find.text('Uy, contame qué pasó.'), findsOneWidget);
    expect(find.text('No se pudo enviar. Revisá tu conexión a internet.'), findsNothing);
    expect(
      find.byType(MessageBubble),
      findsNWidgets(2),
      reason: 'retried in place, not duplicated',
    );
  });

  for (final (name, status, code, headers, text) in [
    (
      'the model is down',
      503,
      'LLM_UNAVAILABLE',
      <String, String>{},
      'marlix no puede responder en este momento. No se pudo enviar.',
    ),
    (
      'too many messages',
      429,
      'RATE_LIMITED',
      {'retry-after': '20'},
      'Vas muy rápido. Esperá 20 segundos y volvé a intentarlo.',
    ),
    ('an unexpected error', 500, 'INTERNAL_ERROR', <String, String>{}, 'No se pudo enviar.'),
  ]) {
    testWidgets('$name gets its own message and a retry', (tester) async {
      final backend = await openChat(tester);
      await type(tester, 'Hola');
      await tester.tap(sendButton);
      await tester.pump();
      backend.fail(status, code, headers: headers);
      await settle(tester);

      expect(find.text(text), findsOneWidget);
      expect(retryButton, findsOneWidget);
    });
  }

  testWidgets('the daily limit explains when it resets and locks the composer', (tester) async {
    final backend = await openChat(tester);
    await type(tester, 'Un mensaje más');
    await tester.tap(sendButton);
    await tester.pump();
    backend.fail(
      429,
      'DAILY_LIMIT_REACHED',
      details: {'resetsAt': DateTime.now().toUtc().add(const Duration(hours: 6)).toIso8601String()},
    );
    await settle(tester);

    expect(find.text('Por hoy llegamos al límite'), findsOneWidget);
    expect(
      find.text('Mañana volvemos a conversar: los mensajes se renuevan a medianoche.'),
      findsOneWidget,
    );
    expect(find.text('Un mensaje más'), findsOneWidget, reason: 'the text is not lost');
    expect(find.text('No se envió: llegamos al límite de hoy.'), findsOneWidget);
    expect(retryButton, findsNothing, reason: 'retrying cannot work until the reset');
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    expect(find.text('Límite diario alcanzado'), findsOneWidget);

    await tester.tap(find.text('La ayuda sigue disponible'));
    await tester.pumpAndSettle();
    expect(find.byType(HelpScreen), findsOneWidget, reason: 'help stays one tap away');
  });

  testWidgets('using the last message shows the limit right away', (tester) async {
    final backend = await openChat(tester);
    await type(tester, 'El último');
    await tester.tap(sendButton);
    backend.answer('El último', 'Me encantó hablar hoy contigo.', remaining: 0);
    await settle(tester);

    expect(find.text('Te quedan 0 mensajes hoy'), findsOneWidget);
    expect(find.byType(DailyLimitCard), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
  });

  testWidgets('opening the chat with no messages left shows the limit', (tester) async {
    await openChat(tester, backend: FakeBackend()..usageRemaining = 0);
    await tester.pump();

    expect(find.byType(DailyLimitCard), findsOneWidget);
  });

  testWidgets('the crisis reply is a prominent card that dials 9-1-1', (tester) async {
    final dialer = FakeDialer();
    final backend = await openChat(tester, dialer: dialer);
    await type(tester, 'Ya no aguanto más');
    await tester.tap(sendButton);
    backend.answerCrisis('Ya no aguanto más', 'Por favor llamá al 9-1-1 ahora.');
    await settle(tester);

    expect(find.byType(CrisisCard), findsOneWidget);
    expect(find.text('No estás solo ni sola en esto'), findsOneWidget);
    expect(find.text('Por favor llamá al 9-1-1 ahora.'), findsOneWidget);
    expect(retryButton, findsNothing);

    await tester.tap(find.text('Llamar al 9-1-1'));
    await tester.pump();
    expect(dialer.dialed, ['911']);

    await tester.tap(find.text('Ver más ayuda'));
    await tester.pumpAndSettle();
    expect(find.byType(HelpScreen), findsOneWidget);
  });

  test('formats the phone numbers of the help lines', () {
    expect(formatPhone('911'), '9-1-1');
    expect(formatPhone('22257511'), '2225-7511');
    expect(formatPhone('8002737869'), '800-273-7869');
    expect(formatPhone('12345'), '12345');
  });
}

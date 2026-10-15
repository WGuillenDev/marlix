import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marlix/widgets/message_bubble.dart';
import 'package:marlix/widgets/typing_indicator.dart';

import '../helpers/fake_backend.dart';

void main() {
  testWidgets('shows the header, the remaining messages and an empty chat', (tester) async {
    await openChat(tester);

    expect(find.text('marlix'), findsOneWidget);
    expect(find.text('Aquí para conversar'), findsOneWidget);
    expect(find.text('Te quedan 87 mensajes hoy'), findsOneWidget);
    expect(find.text('Contale a marlix cómo te fue hoy.'), findsOneWidget);
  });

  testWidgets('the send button is disabled for an empty or blank message', (tester) async {
    await openChat(tester);
    IconButton button() =>
        tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.send_rounded));

    expect(button().onPressed, isNull);
    await type(tester, '   ');
    expect(button().onPressed, isNull);
    await type(tester, 'Hola');
    expect(button().onPressed, isNotNull);
  });

  testWidgets('sends a message, shows the indicator and then the reply', (tester) async {
    final backend = await openChat(tester);

    await type(tester, '  Hoy salí a caminar  ');
    await tester.tap(sendButton);
    await tester.pump();

    expect(backend.sent, ['Hoy salí a caminar']);
    expect(find.text('Hoy salí a caminar'), findsOneWidget);
    expect(find.byType(TypingIndicator), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
    expect(
      tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.send_rounded)).onPressed,
      isNull,
    );

    backend.answer('Hoy salí a caminar', '¡Qué rico! ¿Por dónde fuiste?');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(TypingIndicator), findsNothing);
    expect(find.text('¡Qué rico! ¿Por dónde fuiste?'), findsOneWidget);
    expect(find.byType(MessageBubble), findsNWidgets(2));
    expect(find.text('Te quedan 86 mensajes hoy'), findsOneWidget);
  });

  testWidgets('tells the user and marlix apart', (tester) async {
    final backend = await openChat(tester);
    await type(tester, 'Hola');
    await tester.tap(sendButton);
    backend.answer('Hola', '¡Hola! ¿Cómo estás?');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final userBubble = tester.getRect(
      find.ancestor(of: find.text('Hola'), matching: find.byType(DecoratedBox)).first,
    );
    final marlixBubble = tester.getRect(
      find
          .ancestor(of: find.text('¡Hola! ¿Cómo estás?'), matching: find.byType(DecoratedBox))
          .first,
    );

    expect(userBubble.right, greaterThan(marlixBubble.right), reason: 'user on the right');
    expect(marlixBubble.left, lessThan(userBubble.left), reason: 'marlix on the left');
    expect(find.bySemanticsLabel('Vos'), findsOneWidget);
    expect(find.bySemanticsLabel('marlix'), findsWidgets);
  });

  testWidgets('scrolls to the newest message when it arrives', (tester) async {
    final backend = await openChat(tester);
    for (var turn = 0; turn < 8; turn++) {
      await type(tester, 'Mensaje $turn con un texto largo para que la lista no quepa entera');
      await tester.tap(sendButton);
      backend.answer(
        'Mensaje $turn con un texto largo para que la lista no quepa entera',
        'Respuesta $turn, también larga para llenar la pantalla de burbujas',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      backend.reply = Completer();
    }

    await tester.drag(find.byType(ListView), const Offset(0, 600));
    await tester.pumpAndSettle();
    expect(
      find.text('Respuesta 7, también larga para llenar la pantalla de burbujas'),
      findsNothing,
    );

    await type(tester, 'Último');
    await tester.tap(sendButton);
    backend.answer('Último', 'La más nueva');
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('La más nueva'), findsOneWidget);
    expect(tester.getRect(find.text('La más nueva')).bottom, lessThan(800));
  });

  testWidgets('fits a small screen with the keyboard open', (tester) async {
    final backend = await openChat(tester, size: const Size(320, 568));
    tester.view.viewInsets = FakeViewPadding(bottom: 260 * tester.view.devicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    await type(tester, 'Hola desde una pantalla chica');
    await tester.tap(sendButton);
    backend.answer('Hola desde una pantalla chica', 'Te leo bien desde acá');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.getRect(find.byType(TextField)).bottom, lessThanOrEqualTo(568 - 260));
    expect(find.text('Te leo bien desde acá'), findsOneWidget);
  });
}

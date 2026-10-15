import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:marlix/app.dart';
import 'package:marlix/services/marlix_api.dart';
import 'package:marlix/widgets/message_bubble.dart';
import 'package:marlix/widgets/typing_indicator.dart';

const usage = {'used': 13, 'limit': 100, 'remaining': 87, 'resetsAt': '2026-10-16T06:00:00Z'};
var _ids = 0;

Map<String, Object?> message(String role, String content) => {
  'id': 'id-${_ids++}',
  'role': role,
  'content': content,
  'createdAt': '2026-10-15T18:00:00Z',
};

http.Response json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// A backend whose chat replies wait for [reply] to complete, so the test
/// controls when marlix answers.
class FakeBackend {
  Completer<http.Response> reply = Completer();
  final sent = <String>[];

  MarlixApi api() => MarlixApi(
    client: MockClient((request) async {
      if (request.url.path == '/v1/usage') return json({'plan': 'personal', ...usage});
      sent.add((jsonDecode(request.body) as Map)['message'] as String);
      return reply.future;
    }),
    baseUrl: Uri.parse('https://api.test'),
  );

  void answer(String userText, String replyText, {int remaining = 86}) {
    reply.complete(
      json({
        'type': 'reply',
        'userMessage': message('user', userText),
        'reply': message('assistant', replyText),
        'usage': {...usage, 'used': 100 - remaining, 'remaining': remaining},
      }),
    );
  }
}

Future<FakeBackend> openChat(WidgetTester tester, {Size size = const Size(360, 800)}) async {
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  final backend = FakeBackend();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [marlixApiProvider.overrideWithValue(backend.api())],
      child: const MarlixApp(),
    ),
  );
  await tester.pump();
  return backend;
}

Future<void> type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
}

Finder get sendButton => find.byTooltip('Enviar');

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
    IconButton button() => tester.widget<IconButton>(find.byType(IconButton));

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
    expect(tester.widget<IconButton>(find.byType(IconButton)).onPressed, isNull);

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

  testWidgets('keeps the text when sending fails', (tester) async {
    final backend = await openChat(tester);

    await type(tester, 'No se pierde');
    await tester.tap(sendButton);
    await tester.pump();
    backend.reply.completeError(http.ClientException('Connection closed'));
    await tester.pump();
    await tester.pump();

    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'No se pierde');
    expect(find.byType(MessageBubble), findsNothing);
    expect(find.byType(TypingIndicator), findsNothing);
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

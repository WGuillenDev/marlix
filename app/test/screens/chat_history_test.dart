import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marlix/widgets/message_bubble.dart';

import '../helpers/fake_backend.dart';

Map<String, Object?> stored(String id, String role, String content) => {
  'id': id,
  'role': role,
  'content': content,
  'createdAt': '2026-10-15T18:00:00Z',
  'interrupted': false,
};

/// [count] messages, oldest first, alternating user and marlix.
List<Map<String, Object?>> conversation(String prefix, int count) => [
  for (var i = 0; i < count; i++)
    stored('$prefix-$i', i.isEven ? 'user' : 'assistant', '$prefix mensaje $i'),
];

Finder get list => find.byType(ListView);

/// Drags the chat up to older messages until [done] holds, at most [tries] times.
Future<void> scrollUpUntil(WidgetTester tester, bool Function() done, {int tries = 12}) async {
  for (var i = 0; i < tries && !done(); i++) {
    await tester.drag(list, const Offset(0, 1500));
    await tester.pump();
  }
  await settle(tester);
}

void main() {
  testWidgets('loads the history when the chat opens, in order', (tester) async {
    final backend = FakeBackend()
      ..historyPages = [
        [stored('1', 'user', 'Ayer fui al mercado'), stored('2', 'assistant', '¿Qué compraste?')],
      ];
    await openChat(tester, backend: backend);
    await settle(tester);

    expect(backend.historyRequests, [null]);
    expect(find.text('Ayer fui al mercado'), findsOneWidget);
    expect(find.text('¿Qué compraste?'), findsOneWidget);
    expect(find.text('Contale a marlix cómo te fue hoy.'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Ayer fui al mercado')).dy,
      lessThan(tester.getTopLeft(find.text('¿Qué compraste?')).dy),
    );
  });

  testWidgets('does not call the chat empty while the history loads', (tester) async {
    final backend = FakeBackend()..historyGate = Completer();
    await openChat(tester, backend: backend);

    expect(find.text('Cargando tu conversación…'), findsOneWidget);
    expect(find.text('Contale a marlix cómo te fue hoy.'), findsNothing);

    backend.historyGate.complete();
    await settle(tester);
    expect(find.text('Contale a marlix cómo te fue hoy.'), findsOneWidget);
    expect(find.text('Cargando tu conversación…'), findsNothing);
  });

  testWidgets('a new message goes after the history', (tester) async {
    final backend = FakeBackend()..historyPages = [conversation('hist', 4)];
    await openChat(tester, backend: backend);
    await settle(tester);

    await type(tester, 'Hola otra vez');
    await tester.tap(sendButton);
    await tester.pump();
    backend.answer('Hola otra vez', 'Qué bueno verte');
    await settle(tester);

    expect(find.text('hist mensaje 3'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('hist mensaje 3')).dy,
      lessThan(tester.getTopLeft(find.text('Hola otra vez')).dy),
    );
    expect(find.text('Qué bueno verte'), findsOneWidget);
  });

  testWidgets('loads the next older page only when scrolling up, one page at a time', (
    tester,
  ) async {
    final backend = FakeBackend()
      ..historyPages = [conversation('nuevo', 30), conversation('viejo', 30)];
    await openChat(tester, backend: backend);
    await settle(tester);

    // The newest page fills the screen, so nothing else is requested yet.
    expect(backend.historyRequests, [null]);
    expect(find.text('viejo mensaje 29'), findsNothing);

    await scrollUpUntil(tester, () => backend.historyRequests.length > 1);
    expect(backend.historyRequests, [null, '1']);

    // The oldest page is the last one: scrolling further asks for nothing more.
    await scrollUpUntil(tester, () => false);
    expect(backend.historyRequests, [null, '1']);
    expect(find.text('viejo mensaje 0'), findsOneWidget);
  });

  testWidgets('loading older messages does not pull the chat back down', (tester) async {
    final backend = FakeBackend()
      ..historyPages = [conversation('nuevo', 30), conversation('viejo', 30)];
    await openChat(tester, backend: backend);
    await settle(tester);

    await scrollUpUntil(tester, () => backend.historyRequests.length > 1);
    await tester.pump(const Duration(seconds: 1));

    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable).first);
    expect(scrollable.position.pixels, greaterThan(500));
    expect(find.byType(MessageBubble), findsWidgets);
  });

  testWidgets('a failed history load shows a retry and the chat keeps working', (tester) async {
    final backend = FakeBackend()
      ..historyOffline = true
      ..historyPages = [
        [stored('1', 'user', 'Hola de antes')],
      ];
    await openChat(tester, backend: backend);
    await settle(tester);

    expect(find.textContaining('No pudimos cargar tus mensajes anteriores'), findsOneWidget);
    expect(find.text('Contale a marlix cómo te fue hoy.'), findsNothing);

    await type(tester, 'Hola');
    await tester.tap(sendButton);
    await tester.pump();
    expect(backend.sent, ['Hola']);
    backend.answer('Hola', 'Hola, qué gusto');
    await settle(tester);
    expect(find.text('Hola, qué gusto'), findsOneWidget);

    backend.historyOffline = false;
    await tester.tap(find.text('Reintentar'));
    await settle(tester);

    expect(find.text('Hola de antes'), findsOneWidget);
    expect(find.textContaining('No pudimos cargar'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Hola de antes')).dy,
      lessThan(tester.getTopLeft(find.text('Hola, qué gusto')).dy),
    );
  });
}

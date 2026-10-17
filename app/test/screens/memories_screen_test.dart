import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:marlix/screens/auth_screen.dart';
import 'package:marlix/screens/memories/memories_screen.dart';

import '../helpers/fake_backend.dart';

FakeBackend backendRemembering() => FakeBackend()
  ..memories = [
    {'id': 'm2', 'fact': 'Te gusta el café chorreado por la mañana.'},
    {'id': 'm1', 'fact': 'Tu hermana se llama Ana.'},
  ];

Future<void> openMemories(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Ajustes'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Lo que marlix sabe de mí'));
  await tester.pumpAndSettle();
}

Finder memoryCard(String fact) =>
    find.ancestor(of: find.text(fact), matching: find.byType(DecoratedBox)).first;

Future<void> tapOn(WidgetTester tester, String fact, String tooltip) async {
  await tester.tap(find.descendant(of: memoryCard(fact), matching: find.byTooltip(tooltip)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('settings opens the screen, which lists every memory newest first', (tester) async {
    final backend = await openChat(tester, backend: backendRemembering());
    await tester.tap(find.byTooltip('Ajustes'));
    await tester.pumpAndSettle();

    expect(find.text('Ver, editar o borrar recuerdos'), findsOneWidget);
    await tester.tap(find.text('Lo que marlix sabe de mí'));
    await tester.pumpAndSettle();

    expect(find.byType(MemoriesScreen), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Te gusta el café chorreado por la mañana.')).dy,
      lessThan(tester.getTopLeft(find.text('Tu hermana se llama Ana.')).dy),
    );
    expect(find.textContaining('lo borrado ya no lo uso'), findsOneWidget);
    expect(find.text('Borrar todo lo que sabe'), findsOneWidget);
    expect(backend.memoryRequests, ['GET /v1/memories']);
    expect(backend.authorizations.last, 'Bearer token-of-user-ana@example.com');
  });

  testWidgets('with nothing remembered it says so and offers no delete button', (tester) async {
    await openChat(tester);
    await openMemories(tester);

    expect(find.textContaining('Todavía no recuerdo nada de vos'), findsOneWidget);
    expect(find.text('Borrar todo lo que sabe'), findsNothing);
  });

  testWidgets('edits a memory with the sheet and shows the saved text', (tester) async {
    final backend = await openChat(tester, backend: backendRemembering());
    await openMemories(tester);

    await tapOn(tester, 'Tu hermana se llama Ana.', 'Editar recuerdo');
    expect(find.text('Editar recuerdo'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '  Tu hermana mayor se llama Ana. ');
    await tester.pump();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Tu hermana mayor se llama Ana.'), findsOneWidget);
    expect(find.text('Tu hermana se llama Ana.'), findsNothing);
    expect(
      backend.memoryRequests.last,
      'PATCH /v1/memories/m1 {"fact":"Tu hermana mayor se llama Ana."}',
    );
  });

  testWidgets('cannot save an empty or unchanged memory, and cancel sends nothing', (tester) async {
    final backend = await openChat(tester, backend: backendRemembering());
    await openMemories(tester);
    await tapOn(tester, 'Tu hermana se llama Ana.', 'Editar recuerdo');

    FilledButton save() => tester.widget(find.widgetWithText(FilledButton, 'Guardar'));
    expect(save().onPressed, isNull, reason: 'unchanged');
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(save().onPressed, isNull, reason: 'blank');

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Tu hermana se llama Ana.'), findsOneWidget);
    expect(backend.memoryRequests, ['GET /v1/memories']);
  });

  testWidgets('deletes one memory', (tester) async {
    final backend = await openChat(tester, backend: backendRemembering());
    await openMemories(tester);

    await tapOn(tester, 'Tu hermana se llama Ana.', 'Borrar recuerdo');

    expect(find.text('Tu hermana se llama Ana.'), findsNothing);
    expect(find.text('Te gusta el café chorreado por la mañana.'), findsOneWidget);
    expect(backend.memoryRequests.last, 'DELETE /v1/memories/m1');
    expect(backend.memories.map((m) => m['id']), ['m2']);
  });

  testWidgets('deletes everything only after confirming', (tester) async {
    final backend = await openChat(tester, backend: backendRemembering());
    await openMemories(tester);

    await tester.tap(find.text('Borrar todo lo que sabe'));
    await tester.pumpAndSettle();
    expect(find.text('¿Borrar todo lo que sabe?'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(backend.memoryRequests, ['GET /v1/memories']);
    expect(find.text('Tu hermana se llama Ana.'), findsOneWidget);

    await tester.tap(find.text('Borrar todo lo que sabe'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Borrar todo'));
    await tester.pumpAndSettle();

    expect(backend.memoryRequests.last, 'DELETE /v1/memories');
    expect(find.text('Tu hermana se llama Ana.'), findsNothing);
    expect(find.textContaining('Todavía no recuerdo nada de vos'), findsOneWidget);
  });

  testWidgets('a failed delete keeps the memory on screen and says why', (tester) async {
    final backend = await openChat(tester, backend: backendRemembering());
    await openMemories(tester);

    backend.memoriesFailure = () => throw http.ClientException('No connection');
    await tapOn(tester, 'Tu hermana se llama Ana.', 'Borrar recuerdo');

    expect(find.text('Tu hermana se llama Ana.'), findsOneWidget);
    expect(find.text('No hay conexión. Revisá tu internet e intentá de nuevo.'), findsOneWidget);
  });

  testWidgets('a memory deleted somewhere else leaves the list', (tester) async {
    final backend = await openChat(tester, backend: backendRemembering());
    await openMemories(tester);

    backend.memories = [backend.memories.first];
    await tapOn(tester, 'Tu hermana se llama Ana.', 'Borrar recuerdo');

    expect(find.text('Tu hermana se llama Ana.'), findsNothing);
    expect(find.text('Ese recuerdo ya no existe.'), findsOneWidget);
  });

  testWidgets('if the list cannot load, it offers a retry', (tester) async {
    final backend = backendRemembering()
      ..memoriesFailure = () => throw http.ClientException('No connection');
    await openChat(tester, backend: backend);
    await openMemories(tester);

    expect(find.textContaining('No pude cargar lo que recuerdo'), findsOneWidget);

    backend.memoriesFailure = null;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Tu hermana se llama Ana.'), findsOneWidget);
  });

  testWidgets('a rejected session goes back to sign in', (tester) async {
    final backend = backendRemembering()
      ..memoriesFailure = () => jsonResponse({
        'error': {'code': 'UNAUTHORIZED', 'message': 'Invalid token.'},
      }, 401);
    await openChat(tester, backend: backend);
    await openMemories(tester);

    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.byType(MemoriesScreen), findsNothing);
  });
}

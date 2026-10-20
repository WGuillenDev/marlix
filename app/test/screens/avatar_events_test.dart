import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marlix/models/chat.dart';
import 'package:marlix/screens/chat/avatar_controller.dart';
import 'package:marlix/screens/chat/chat_screen.dart';
import 'package:marlix/widgets/avatar_marlix.dart';

import '../helpers/fake_backend.dart';

AvatarState shown(WidgetTester tester) =>
    tester.widget<AvatarMarlix>(find.byType(AvatarMarlix)).state;

Future<void> sendMessage(WidgetTester tester, String text) async {
  await type(tester, text);
  await tester.tap(find.byTooltip('Enviar'));
  await tester.pump();
}

void main() {
  testWidgets('the avatar is in the header and rests while nothing happens', (tester) async {
    await openChat(tester);
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: find.byType(ChatScreen), matching: find.byType(AvatarMarlix)),
      findsOneWidget,
    );
    expect(shown(tester), AvatarState.idle);
    expect(tester.widget<AvatarMarlix>(find.byType(AvatarMarlix)).folder, 'assets/avatars/marlix');
    expect(tester.getSize(find.byType(AvatarMarlix)).shortestSide, 64);
  });

  testWidgets('it thinks while marlix replies and rests when the reply arrives', (tester) async {
    final backend = await openChat(tester);
    await sendMessage(tester, 'Hola');
    expect(shown(tester), AvatarState.thinking);

    backend.answer('Hola', 'Hola, ¿cómo estás?');
    await tester.pump();
    await tester.pump();

    expect(shown(tester), AvatarState.idle);
  });

  testWidgets('a reply to a positive message makes it happy for a moment, then it rests', (
    tester,
  ) async {
    final backend = await openChat(tester);
    await sendMessage(tester, 'Hoy me fue muy bien');
    backend.answer('Hoy me fue muy bien', '¡Qué alegría!', tone: 'positive');
    await tester.pump();
    await tester.pump();

    expect(shown(tester), AvatarState.happy);

    await tester.pump(AvatarController.happyFor - const Duration(milliseconds: 100));
    expect(shown(tester), AvatarState.happy);
    await tester.pump(const Duration(milliseconds: 200));
    expect(shown(tester), AvatarState.idle);
  });

  testWidgets('a new message while it celebrates takes it back to thinking for good', (
    tester,
  ) async {
    final backend = await openChat(tester);
    await sendMessage(tester, 'Hoy me fue muy bien');
    backend.answer('Hoy me fue muy bien', '¡Qué alegría!', tone: 'positive');
    await tester.pump();
    await tester.pump();
    expect(shown(tester), AvatarState.happy);

    backend.reply = Completer();
    await sendMessage(tester, 'Y mañana también');
    expect(shown(tester), AvatarState.thinking);

    // The old celebration timer must not rest it while marlix is still thinking.
    await tester.pump(AvatarController.happyFor * 2);
    expect(shown(tester), AvatarState.thinking);

    backend.answer('Y mañana también', 'Aquí estaré.');
    await tester.pump();
    await tester.pump();
    expect(shown(tester), AvatarState.idle);
  });

  testWidgets('a crisis never makes it happy', (tester) async {
    final backend = await openChat(tester);
    await sendMessage(tester, 'Hoy estoy feliz pero me quiero morir');
    backend.answerCrisis('Hoy estoy feliz pero me quiero morir', 'Estoy contigo.');
    await tester.pump();
    await tester.pump();

    expect(shown(tester), AvatarState.idle);
  });

  testWidgets('a failed message sends it back to rest', (tester) async {
    final backend = await openChat(tester);
    await sendMessage(tester, 'Hola');
    expect(shown(tester), AvatarState.thinking);

    backend.dropConnection();
    await tester.pump();
    await tester.pump();

    expect(shown(tester), AvatarState.idle);
  });

  testWidgets('history loaded at the start is never celebrated', (tester) async {
    final backend = FakeBackend()
      ..historyPages = [
        [messageJson('user', 'Hoy me fue muy bien'), messageJson('assistant', '¡Qué alegría!')],
      ];
    await openChat(tester, backend: backend);
    await tester.pumpAndSettle();

    expect(shown(tester), AvatarState.idle);
  });

  testWidgets('it shrinks with the keyboard open so the chat keeps its room', (tester) async {
    await openChat(tester, size: const Size(320, 568));
    tester.view.viewInsets = FakeViewPadding(bottom: 260 * tester.view.devicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();

    expect(tester.getSize(find.byType(AvatarMarlix)).shortestSide, 48);
    expect(tester.takeException(), isNull);
  });

  testWidgets('with animations removed the avatar keeps its pose', (tester) async {
    await openChat(tester);
    await tester.pumpAndSettle();

    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('with animations on, it moves', (tester) async {
    await openChat(tester);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures();
    await tester.pump();

    expect(tester.hasRunningAnimations, isTrue);
  });

  group('the response tone', () {
    Map<String, Object?> body(Map<String, Object?> extra) => {
      'type': 'reply',
      'userMessage': messageJson('user', 'Hola'),
      'reply': messageJson('assistant', 'Hola'),
      ...extra,
    };

    test('is positive only when the backend says so', () {
      expect(ChatResponse.fromJson(body({'tone': 'positive'})).tone, MessageTone.positive);
      expect(ChatResponse.fromJson(body({'tone': 'neutral'})).tone, MessageTone.neutral);
    });

    test('is neutral when it is missing or unknown, so an older backend still works', () {
      expect(ChatResponse.fromJson(body({})).tone, MessageTone.neutral);
      expect(ChatResponse.fromJson(body({'tone': 'ecstatic'})).tone, MessageTone.neutral);
    });
  });
}

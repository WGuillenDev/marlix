import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:marlix/models/voice_config.dart';
import 'package:marlix/services/voice/voice_providers.dart';

import '../helpers/fake_backend.dart';
import '../services/voice/voice_fakes.dart';

/// A phone that can run Supertonic, with the voice engines replaced by fakes.
class _Voices {
  final supertonic = FakeEngine(VoiceEngineKind.supertonic);
  final native = FakeEngine(VoiceEngineKind.native);

  List<Override> get overrides => [
    deviceFactsProvider.overrideWithValue(FakeFacts()),
    voiceModelProvider.overrideWithValue(FakeModel(ready: true)),
    supertonicEngineFactoryProvider.overrideWithValue((VoiceConfig _) => supertonic),
    nativeEngineFactoryProvider.overrideWithValue((VoiceConfig _) => native),
  ];
}

const _readAloud = {'read_aloud': true};

/// Voice work is a chain of futures; a few frames let all of them run.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// The app goes to the background and comes back, through the states Android
/// really reports.
void _background(WidgetTester tester) {
  for (final state in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

void _foreground(WidgetTester tester) {
  for (final state in [
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

Future<void> _ask(WidgetTester tester, FakeBackend backend, String reply) async {
  await type(tester, 'Hola');
  await tester.tap(sendButton);
  await tester.pump();
  backend.answer('Hola', reply);
  await _settle(tester);
}

void main() {
  testWidgets('with the setting off a reply is only text', (tester) async {
    final voices = _Voices();
    final backend = await openChat(tester, overrides: voices.overrides);

    await _ask(tester, backend, '¡Qué bueno!');

    expect(find.text('¡Qué bueno!'), findsOneWidget);
    expect(voices.supertonic.spoken, isEmpty);
    expect(backend.modes, ['text']);
    expect(find.byTooltip('Pausar'), findsNothing);
  });

  testWidgets('with the setting on the reply is asked in voice mode and read aloud', (
    tester,
  ) async {
    final voices = _Voices()..supertonic.hold = Completer<void>();
    final backend = await openChat(
      tester,
      overrides: voices.overrides,
      savedPreferences: _readAloud,
    );

    await _ask(tester, backend, '¡Qué bueno!');

    expect(backend.modes, ['voice']);
    expect(find.text('¡Qué bueno!'), findsOneWidget, reason: 'the text is always shown');
    expect(voices.supertonic.spoken, ['¡Qué bueno!']);
    expect(find.text('marlix está hablando'), findsOneWidget);

    voices.supertonic.hold!.complete();
    await _settle(tester);
    expect(find.text('marlix está hablando'), findsNothing);
  });

  testWidgets('the person can pause, resume and stop', (tester) async {
    final voices = _Voices()..supertonic.hold = Completer<void>();
    final backend = await openChat(
      tester,
      overrides: voices.overrides,
      savedPreferences: _readAloud,
    );
    await _ask(tester, backend, 'Cuéntame más.');

    await tester.tap(find.byTooltip('Pausar'));
    await _settle(tester);
    expect(voices.supertonic.pauses, 1);
    expect(find.text('En pausa'), findsOneWidget);

    await tester.tap(find.byTooltip('Continuar'));
    await _settle(tester);
    expect(voices.supertonic.resumes, 1);
    expect(find.text('marlix está hablando'), findsOneWidget);

    final stopsBefore = voices.supertonic.stops;
    await tester.tap(find.byTooltip('Detener'));
    await _settle(tester);
    expect(voices.supertonic.stops, greaterThan(stopsBefore));
    expect(find.byTooltip('Detener'), findsNothing);
    expect(find.text('Cuéntame más.'), findsOneWidget);
  });

  testWidgets('going to the background pauses and coming back continues', (tester) async {
    final voices = _Voices()..supertonic.hold = Completer<void>();
    final backend = await openChat(
      tester,
      overrides: voices.overrides,
      savedPreferences: _readAloud,
    );
    await _ask(tester, backend, 'Cuéntame más.');

    _background(tester);
    await _settle(tester);
    expect(voices.supertonic.pauses, 1);

    _foreground(tester);
    await _settle(tester);
    expect(voices.supertonic.resumes, 1);
    expect(find.text('marlix está hablando'), findsOneWidget);
  });

  testWidgets('a pause by the person is not undone by coming back to the app', (tester) async {
    final voices = _Voices()..supertonic.hold = Completer<void>();
    final backend = await openChat(
      tester,
      overrides: voices.overrides,
      savedPreferences: _readAloud,
    );
    await _ask(tester, backend, 'Cuéntame más.');
    await tester.tap(find.byTooltip('Pausar'));
    await _settle(tester);

    _background(tester);
    _foreground(tester);
    await _settle(tester);

    expect(voices.supertonic.resumes, 0);
    expect(find.text('En pausa'), findsOneWidget);
  });

  testWidgets('opening settings or help stops the voice', (tester) async {
    final voices = _Voices()..supertonic.hold = Completer<void>();
    final backend = await openChat(
      tester,
      overrides: voices.overrides,
      savedPreferences: _readAloud,
    );
    await _ask(tester, backend, 'Cuéntame más.');
    final stopsBefore = voices.supertonic.stops;

    await tester.tap(find.byTooltip('Ajustes'));
    await tester.pumpAndSettle();

    expect(voices.supertonic.stops, greaterThan(stopsBefore));
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byTooltip('Detener'), findsNothing);
  });

  testWidgets('turning the setting off in Settings stops the voice', (tester) async {
    final voices = _Voices()..supertonic.hold = Completer<void>();
    final backend = await openChat(
      tester,
      overrides: voices.overrides,
      savedPreferences: _readAloud,
    );
    await _ask(tester, backend, 'Cuéntame más.');

    await tester.tap(find.byTooltip('Ajustes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leer las respuestas en voz alta'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Detener'), findsNothing, reason: 'the reading ended');
    await tester.pageBack();
    await tester.pumpAndSettle();

    backend.reply = Completer();
    await _ask(tester, backend, 'Otra cosa.');
    expect(voices.supertonic.spoken, ['Cuéntame más.']);
    expect(backend.modes, ['voice', 'text']);
  });

  testWidgets('a voice that fails never breaks the text chat', (tester) async {
    final voices = _Voices();
    voices.supertonic.scripts.addAll([
      [StateError('no audio')],
      [StateError('no audio')],
      [StateError('no audio')],
    ]);
    voices.native.scripts.add([StateError('no voice')]);
    final backend = await openChat(
      tester,
      overrides: voices.overrides,
      savedPreferences: _readAloud,
    );

    await _ask(tester, backend, 'Cuéntame más.');

    expect(find.text('Cuéntame más.'), findsOneWidget);
    expect(find.byTooltip('Detener'), findsNothing);
    await type(tester, 'Sigo aquí');
    expect(
      tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.send_rounded)).onPressed,
      isNotNull,
      reason: 'the person can keep writing',
    );
  });

  testWidgets('a crisis reply is not read aloud', (tester) async {
    final voices = _Voices();
    final backend = await openChat(
      tester,
      overrides: voices.overrides,
      savedPreferences: _readAloud,
    );

    await type(tester, 'Hola');
    await tester.tap(sendButton);
    await tester.pump();
    backend.answerCrisis('Hola', 'No estás solo.');
    await _settle(tester);

    expect(find.text('No estás solo.'), findsOneWidget);
    expect(voices.supertonic.spoken, isEmpty);
    expect(voices.native.spoken, isEmpty);
  });
}

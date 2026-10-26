import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:marlix/models/voice_config.dart';
import 'package:marlix/screens/chat/chat_screen.dart';
import 'package:marlix/screens/help_screen.dart';
import 'package:marlix/screens/voice/voice_mode_screen.dart';
import 'package:marlix/services/read_aloud.dart';
import 'package:marlix/services/voice/device_facts.dart';
import 'package:marlix/services/voice/voice_engine.dart';
import 'package:marlix/services/voice/voice_providers.dart';
import 'package:marlix/widgets/avatar_marlix.dart';

import '../helpers/fake_backend.dart';
import '../services/voice/voice_fakes.dart';

/// A phone with the voice engines replaced by fakes.
class _Phone {
  _Phone({
    bool modelReady = true,
    ConnectionKind link = ConnectionKind.unmetered,
    bool lowRam = false,
    Object? nativeError,
  }) : facts = FakeFacts(link: link, lowRam: lowRam),
       model = FakeModel(ready: modelReady),
       native = FakeEngine(VoiceEngineKind.native, prepareError: nativeError);

  final FakeFacts facts;
  final FakeModel model;
  final supertonic = FakeEngine(VoiceEngineKind.supertonic);
  final FakeEngine native;

  List<Override> get overrides => [
    deviceFactsProvider.overrideWithValue(facts),
    voiceModelProvider.overrideWithValue(model),
    supertonicEngineFactoryProvider.overrideWithValue((VoiceConfig _) => supertonic),
    nativeEngineFactoryProvider.overrideWithValue((VoiceConfig _) => native),
  ];
}

/// Voice work is a chain of futures; a few frames let all of them run.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _openVoiceMode(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Modo voz'));
  await tester.pumpAndSettle();
}

Finder get _modeScreen => find.byType(VoiceModeScreen);

void main() {
  group('opening and leaving', () {
    testWidgets('the chat has a voice button and it opens the full-screen mode', (tester) async {
      await openChat(tester, overrides: _Phone().overrides);
      await tester.pump();

      expect(find.byTooltip('Modo voz'), findsOneWidget);
      await _openVoiceMode(tester);

      expect(_modeScreen, findsOneWidget);
      expect(find.text('Modo voz'), findsOneWidget);
      expect(find.text('Aquí estoy'), findsOneWidget);
    });

    testWidgets('the avatar is large and centered, much bigger than in the header', (tester) async {
      await openChat(tester, overrides: _Phone().overrides);
      await tester.pump();
      final header = tester.getSize(find.byType(AvatarMarlix)).shortestSide;

      await _openVoiceMode(tester);
      final big = find.descendant(of: _modeScreen, matching: find.byType(AvatarMarlix));
      final size = tester.getSize(big);

      expect(size.shortestSide, greaterThan(header * 3));
      expect(tester.getCenter(big).dx, closeTo(180, 1), reason: 'centered on a 360 wide screen');
    });

    testWidgets('it shows how many interactions are left today', (tester) async {
      await openChat(tester, overrides: _Phone().overrides);
      await tester.pump();
      await _openVoiceMode(tester);

      expect(
        find.descendant(of: _modeScreen, matching: find.text('Te quedan 87 mensajes hoy')),
        findsOneWidget,
      );
    });

    testWidgets('the person can go back to the chat from the X and from Terminar', (tester) async {
      await openChat(tester, overrides: _Phone().overrides);
      await tester.pump();

      for (final tooltip in ['Volver al chat', 'Terminar']) {
        await _openVoiceMode(tester);
        await tester.tap(find.byTooltip(tooltip));
        await tester.pumpAndSettle();
        expect(_modeScreen, findsNothing, reason: tooltip);
        expect(find.byType(ChatScreen), findsOneWidget);
      }
    });

    testWidgets('the system back button also leaves, and entering again works', (tester) async {
      await openChat(tester, overrides: _Phone().overrides);
      await tester.pump();

      for (var i = 0; i < 3; i++) {
        await _openVoiceMode(tester);
        expect(_modeScreen, findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(_modeScreen, findsNothing);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('help stays one tap away', (tester) async {
      await openChat(tester, overrides: _Phone().overrides);
      await tester.pump();
      await _openVoiceMode(tester);

      await tester.tap(find.byTooltip('Ayuda'));
      await tester.pumpAndSettle();

      expect(find.byType(HelpScreen), findsOneWidget);
    });

    testWidgets('the voice button gives its room to the text while writing', (tester) async {
      await openChat(tester, overrides: _Phone().overrides);
      await tester.pump();
      expect(find.byTooltip('Modo voz'), findsOneWidget);

      await type(tester, 'Hola');

      expect(find.byTooltip('Modo voz'), findsNothing);
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      expect(find.byTooltip('Modo voz'), findsOneWidget);
    });

    testWidgets('with no interactions left the voice button of the chat is off', (tester) async {
      await openChat(tester, backend: FakeBackend()..usageRemaining = 0);
      await tester.pump();

      final button = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.graphic_eq_rounded),
      );
      expect(button.onPressed, isNull);
    });
  });

  group('talking', () {
    testWidgets('a message written there is asked in voice mode and read aloud', (tester) async {
      final phone = _Phone()..supertonic.hold = Completer<void>();
      final backend = await openChat(tester, overrides: phone.overrides);
      await tester.pump();
      await _openVoiceMode(tester);

      await tester.tap(find.byTooltip('Chat'));
      await tester.pumpAndSettle();
      await type(tester, 'Hola');
      await tester.tap(sendButton);
      await tester.pump();
      expect(find.text('Pensando…'), findsOneWidget);

      backend.answer('Hola', 'Qué gusto verte.');
      await _settle(tester);

      expect(backend.modes, ['voice'], reason: 'the voice mode asks for short, clean replies');
      expect(phone.supertonic.spoken, ['Qué gusto verte.']);
      expect(find.text('marlix está hablando'), findsOneWidget);
      expect(find.text('"Qué gusto verte."'), findsNothing);
      expect(find.text('Qué gusto verte.'), findsOneWidget, reason: 'the last reply is shown');
      expect(find.byTooltip('Chat'), findsOneWidget, reason: 'the field closes after sending');

      phone.supertonic.hold!.complete();
      await _settle(tester);
    });

    testWidgets('it says it is preparing the voice until the first sound', (tester) async {
      final phone = _Phone()
        ..supertonic.hold = Completer<void>()
        ..supertonic.scripts.add([const VoiceFinished()]);
      final backend = await openChat(tester, overrides: phone.overrides);
      await tester.pump();
      await _openVoiceMode(tester);
      await tester.tap(find.byTooltip('Chat'));
      await tester.pumpAndSettle();
      await type(tester, 'Hola');
      await tester.tap(sendButton);
      await tester.pump();
      backend.answer('Hola', 'Qué gusto verte.');
      await _settle(tester);

      expect(find.text('Preparando la voz…'), findsOneWidget);

      phone.supertonic.hold!.complete();
      await _settle(tester);
    });

    testWidgets('the big button pauses and resumes what marlix says', (tester) async {
      final phone = _Phone()..supertonic.hold = Completer<void>();
      final backend = await openChat(tester, overrides: phone.overrides);
      await tester.pump();
      await _openVoiceMode(tester);
      await tester.tap(find.byTooltip('Chat'));
      await tester.pumpAndSettle();
      await type(tester, 'Hola');
      await tester.tap(sendButton);
      await tester.pump();
      backend.answer('Hola', 'Cuéntame más.');
      await _settle(tester);

      await tester.tap(find.byTooltip('Pausar'));
      await _settle(tester);
      expect(phone.supertonic.pauses, 1);
      expect(find.text('En pausa'), findsOneWidget);

      await tester.tap(find.byTooltip('Continuar'));
      await _settle(tester);
      expect(phone.supertonic.resumes, 1);
      expect(find.text('marlix está hablando'), findsOneWidget);

      phone.supertonic.hold!.complete();
      await _settle(tester);
    });

    testWidgets('leaving cuts the voice and ends the mode', (tester) async {
      final phone = _Phone()..supertonic.hold = Completer<void>();
      final backend = await openChat(tester, overrides: phone.overrides);
      await tester.pump();
      await _openVoiceMode(tester);
      await tester.tap(find.byTooltip('Chat'));
      await tester.pumpAndSettle();
      await type(tester, 'Hola');
      await tester.tap(sendButton);
      await tester.pump();
      backend.answer('Hola', 'Cuéntame más.');
      await _settle(tester);
      final stopsBefore = phone.supertonic.stops;

      await tester.tap(find.byTooltip('Terminar'));
      await tester.pumpAndSettle();

      expect(phone.supertonic.stops, greaterThan(stopsBefore));
      expect(find.byTooltip('Detener'), findsNothing, reason: 'nothing keeps being read');
      final container = ProviderScope.containerOf(tester.element(find.byType(ChatScreen)));
      expect(container.read(voiceModeProvider), isFalse);
    });

    testWidgets('the microphone is there for S6-8 but cannot be used yet', (tester) async {
      await openChat(tester, overrides: _Phone().overrides);
      await tester.pump();
      await _openVoiceMode(tester);

      final mic = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.mic_rounded));
      expect(mic.onPressed, isNull);
      expect(find.textContaining('Pronto podrás hablarle'), findsOneWidget);
    });
  });

  group('the voice model', () {
    testWidgets('nothing is shown while the voice works', (tester) async {
      await openChat(tester, overrides: _Phone().overrides);
      await tester.pump();
      await _openVoiceMode(tester);
      await _settle(tester);

      expect(find.text('Dale a marlix su voz'), findsNothing);
      expect(find.text('Descargando la voz'), findsNothing);
    });

    testWidgets('a missing model is offered with wifi and downloads', (tester) async {
      final phone = _Phone(modelReady: false);
      await openChat(tester, overrides: phone.overrides);
      await tester.pump();
      await _openVoiceMode(tester);
      await _settle(tester);

      expect(find.text('Dale a marlix su voz'), findsOneWidget);
      expect(find.textContaining('hay que descargar su voz'), findsOneWidget);
      expect(find.text('Descargar con datos móviles'), findsNothing);

      await tester.tap(find.text('Descargar con wifi'));
      await _settle(tester);

      expect(phone.model.downloads, 1);
      expect(find.text('Dale a marlix su voz'), findsNothing, reason: 'it is on the phone now');
    });

    testWidgets('while it downloads the progress is shown and replies still work', (tester) async {
      final phone = _Phone(modelReady: false)..model.onDownload = () => Completer<void>().future;
      await openChat(tester, overrides: phone.overrides);
      await tester.pump();
      await _openVoiceMode(tester);
      await _settle(tester);

      await tester.tap(find.text('Descargar con wifi'));
      await _settle(tester);

      expect(find.text('Descargando la voz'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.textContaining('Puedes seguir conversando'), findsOneWidget);
    });

    testWidgets('over mobile data it asks first and says what it costs', (tester) async {
      final phone = _Phone(modelReady: false, link: ConnectionKind.mobile);
      await openChat(tester, overrides: phone.overrides);
      await tester.pump();
      await _openVoiceMode(tester);
      await _settle(tester);

      expect(find.textContaining('datos móviles: la descarga gasta'), findsOneWidget);
      expect(find.text('Descargar con wifi'), findsNothing);
      expect(phone.model.downloads, 0);

      await tester.tap(find.text('Descargar con datos móviles'));
      await _settle(tester);
      expect(phone.model.downloads, 1);
    });

    testWidgets('without a connection it says so and offers nothing to tap', (tester) async {
      final phone = _Phone(modelReady: false, link: ConnectionKind.none);
      await openChat(tester, overrides: phone.overrides);
      await tester.pump();
      await _openVoiceMode(tester);
      await _settle(tester);

      expect(find.text('No hay conexión a internet.'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('a phone with no Spanish voice says the text chat keeps working', (tester) async {
      final phone = _Phone(lowRam: true, nativeError: const NoSpanishVoiceException());
      await openChat(tester, overrides: phone.overrides);
      await tester.pump();
      await _openVoiceMode(tester);
      await _settle(tester);

      expect(find.text('Este teléfono no puede hablar'), findsOneWidget);
      expect(find.textContaining('El chat de texto sigue'), findsOneWidget);
    });
  });
}

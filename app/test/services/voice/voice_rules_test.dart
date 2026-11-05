import 'package:flutter_test/flutter_test.dart';
import 'package:marlix/models/voice_config.dart';
import 'package:marlix/services/voice/native_voice_engine.dart';
import 'package:marlix/services/voice/sentences.dart';
import 'package:marlix/services/voice/voice_planner.dart';

const nativeOnly = VoiceConfig(
  engine: VoiceEngineKind.native,
  voice: 'default',
  language: 'es',
  steps: 5,
  rate: 1,
  fallback: NativeVoiceConfig(voice: 'default', pitch: 1, rate: 1),
);

VoicePlan plan({
  VoiceConfig config = VoiceConfig.defaults,
  bool lowRam = false,
  bool failedBefore = false,
  bool ready = true,
  int free = 5 << 30,
}) => VoicePlanner.plan(
  config: config,
  lowRam: lowRam,
  modelFailedBefore: failedBefore,
  modelReady: ready,
  freeBytes: free,
);

Matcher native(NativeReason reason) => isA<PlanNative>().having((p) => p.reason, 'reason', reason);

void main() {
  group('VoicePlanner, the rules of docs/decisions.md', () {
    test('a capable phone with the model uses Supertonic', () {
      expect(plan(), isA<PlanSupertonic>().having((p) => p.needsDownload, 'download', isFalse));
    });

    test('without the model and with space it must download', () {
      expect(
        plan(ready: false),
        isA<PlanSupertonic>().having((p) => p.needsDownload, 'download', isTrue),
      );
    });

    test('the configuration of the avatar can ask for the native voice', () {
      expect(plan(config: nativeOnly), native(NativeReason.configured));
    });

    test('low RAM wins over everything else', () {
      expect(plan(lowRam: true), native(NativeReason.lowRam));
      expect(plan(lowRam: true, ready: false), native(NativeReason.lowRam));
    });

    test('a phone where the model failed does not try again', () {
      expect(plan(failedBefore: true), native(NativeReason.loadFailed));
    });

    test('1 GB is needed to download, not to use a model already there', () {
      expect(plan(ready: false, free: VoicePlanner.minFreeBytes - 1), native(NativeReason.noSpace));
      expect(plan(ready: false, free: VoicePlanner.minFreeBytes), isA<PlanSupertonic>());
      expect(plan(free: 0), isA<PlanSupertonic>());
    });

    test('1.3 seconds of audio per second of work is the speed that is enough', () {
      expect(VoicePlanner.minSpeed, 1.3);
      expect(VoicePlanner.fastEnough(1.29), isFalse);
      expect(VoicePlanner.fastEnough(1.3), isTrue);
      // What the S6-1 tests gave: the S24 Ultra 3.0 to 3.7 and the HONOR 90 1.8 to 2.3.
      expect(VoicePlanner.fastEnough(1.8), isTrue);
    });
  });

  group('splitSentences', () {
    test('splits at the end of each sentence and keeps the punctuation', () {
      expect(splitSentences('Hola. ¿Cómo estás? ¡Qué bien!'), [
        'Hola.',
        '¿Cómo estás?',
        '¡Qué bien!',
      ]);
    });

    test('a text with no final punctuation is one sentence', () {
      expect(splitSentences('Aquí estoy para escucharte'), ['Aquí estoy para escucharte']);
    });

    test('a decimal number or an abbreviation without a space does not cut', () {
      expect(splitSentences('Mide 3.5 metros. Listo.'), ['Mide 3.5 metros.', 'Listo.']);
    });

    test('an ellipsis ends a sentence and keeps its dots', () {
      expect(splitSentences('Bueno... sigamos. Dale.'), ['Bueno...', 'sigamos.', 'Dale.']);
    });

    test('only punctuation is joined to the previous sentence, not spoken alone', () {
      expect(splitSentences('Hola. ... Adiós.'), ['Hola. ...', 'Adiós.']);
    });

    test('empty or blank text gives nothing to say', () {
      expect(splitSentences(''), isEmpty);
      expect(splitSentences('  \n '), isEmpty);
      expect(splitSentences('...'), isEmpty);
    });

    test('line breaks count as spaces', () {
      expect(splitSentences('Uno.\nDos.'), ['Uno.', 'Dos.']);
    });
  });

  group('splitClauses', () {
    test('splits at each comma, semicolon and colon and keeps the punctuation', () {
      expect(splitClauses('Buenas, qué gusto saludarte, ¿cómo amaneciste?'), [
        'Buenas,',
        'qué gusto saludarte,',
        '¿cómo amaneciste?',
      ]);
      expect(splitClauses('Mira: ya casi; falta poco.'), ['Mira:', 'ya casi;', 'falta poco.']);
    });

    test('a sentence with no comma is one clause', () {
      expect(splitClauses('Aquí estoy para escucharte.'), ['Aquí estoy para escucharte.']);
    });

    test('a comma inside a number does not split', () {
      expect(splitClauses('Mide 3,5 metros, más o menos.'), ['Mide 3,5 metros,', 'más o menos.']);
    });

    test('nothing to say gives no clauses', () {
      expect(splitClauses(''), isEmpty);
      expect(splitClauses(' , '), isEmpty);
    });
  });

  group('pauseAfter (S6-14)', () {
    test('a comma pauses short, a semicolon longer and a sentence end the longest', () {
      expect(pauseAfter('Claro,'), commaPause);
      expect(pauseAfter('Mira:'), semicolonPause);
      expect(pauseAfter('ya casi;'), semicolonPause);
      expect(pauseAfter('Fue un buen día.'), sentencePause);
      expect(pauseAfter('¿Qué hacemos?'), sentencePause);
      expect(pauseAfter('¡Qué bien!'), sentencePause);
      expect(commaPause, lessThan(semicolonPause));
      expect(semicolonPause, lessThan(sentencePause));
    });

    test('looks past closing quotes and spaces', () {
      expect(pauseAfter('Me dijo «ya voy». '), sentencePause);
      expect(pauseAfter('(eso creo),'), commaPause);
    });

    test('a piece with no final punctuation gets no pause', () {
      expect(pauseAfter('y entonces'), Duration.zero);
      expect(pauseAfter(''), Duration.zero);
    });
  });

  group('splitForSpeech', () {
    test('the first sentence is spoken clause by clause so the first sound comes sooner', () {
      expect(splitForSpeech('Claro, mae, te cuento. Fue un buen día, la verdad.'), [
        'Claro,',
        'mae,',
        'te cuento.',
        'Fue un buen día, la verdad.',
      ]);
    });

    test('a first sentence without commas is spoken whole', () {
      expect(splitForSpeech('Qué buena idea. Y después, ¿qué?'), [
        'Qué buena idea.',
        'Y después, ¿qué?',
      ]);
    });

    test('nothing to say gives nothing', () {
      expect(splitForSpeech('  '), isEmpty);
    });
  });

  group('NativeVoiceEngine helpers', () {
    test('picks Costa Rican Spanish first, then the nearest the phone has', () {
      expect(NativeVoiceEngine.pickLocale('es', ['es-ES', 'es-MX', 'es-CR']), 'es-CR');
      expect(NativeVoiceEngine.pickLocale('es', ['es-ES', 'es-US']), 'es-US');
      expect(NativeVoiceEngine.pickLocale('es', ['en-US', 'fr-FR']), isNull);
    });

    test('another language is taken as it is', () {
      expect(NativeVoiceEngine.pickLocale('en-US', ['en-US']), 'en-US');
      expect(NativeVoiceEngine.pickLocale('en-US', ['es-CR']), isNull);
    });

    test('the configuration rate 1 is Android rate 0.5, kept in range', () {
      expect(NativeVoiceEngine.androidRate(1), 0.5);
      expect(NativeVoiceEngine.androidRate(1.5), 0.75);
      expect(NativeVoiceEngine.androidRate(0), 0.1);
      expect(NativeVoiceEngine.androidRate(10), 1.0);
    });
  });
}

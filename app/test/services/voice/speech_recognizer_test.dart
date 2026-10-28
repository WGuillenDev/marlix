import 'package:flutter_test/flutter_test.dart';
import 'package:marlix/services/voice/speech_recognizer.dart';

void main() {
  group('pickLocale', () {
    test('prefers Costa Rican Spanish over the other variants', () {
      expect(SpeechToTextRecognizer.pickLocale('es', ['es_ES', 'es_CR', 'en_US']), 'es_CR');
    });

    test('falls back along the list when the phone lacks it', () {
      expect(SpeechToTextRecognizer.pickLocale('es', ['en_US', 'es_US', 'es_ES']), 'es_US');
    });

    test('understands the iOS spelling and returns the id the phone gave', () {
      expect(SpeechToTextRecognizer.pickLocale('es', ['es-MX', 'es-ES']), 'es-MX');
    });

    test('is null when the phone has no Spanish', () {
      expect(SpeechToTextRecognizer.pickLocale('es', ['en_US', 'fr_FR']), isNull);
    });

    test('another language asks for exactly that one', () {
      expect(SpeechToTextRecognizer.pickLocale('en_US', ['es_CR', 'en_US']), 'en_US');
    });
  });

  group('failureOf', () {
    test('silence is not a breakage', () {
      expect(SpeechToTextRecognizer.failureOf('error_no_match'), SpeechFailure.noSpeech);
      expect(SpeechToTextRecognizer.failureOf('error_speech_timeout'), SpeechFailure.noSpeech);
    });

    test('a missing language or recognizer means the phone cannot do it', () {
      expect(
        SpeechToTextRecognizer.failureOf('error_language_unavailable'),
        SpeechFailure.unavailable,
      );
      expect(SpeechToTextRecognizer.failureOf('error_permission'), SpeechFailure.unavailable);
    });

    test('anything else is a generic failure', () {
      expect(SpeechToTextRecognizer.failureOf('error_network'), SpeechFailure.other);
      expect(SpeechToTextRecognizer.failureOf('error_server_disconnected'), SpeechFailure.other);
      expect(SpeechToTextRecognizer.failureOf('whatever'), SpeechFailure.other);
    });
  });
}

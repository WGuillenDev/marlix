import 'package:flutter_test/flutter_test.dart';
import 'package:marlix/services/voice/echo.dart';

void main() {
  group('speechWords', () {
    test('drops accents, punctuation and case', () {
      expect(speechWords('¿Cómo estás, MAÑANA?'), ['como', 'estas', 'manana']);
    });

    test('is empty for nothing', () {
      expect(speechWords('  ...  '), isEmpty);
    });
  });

  group('isEchoOf', () {
    const said = 'Cuéntame más sobre tu día.';

    test('is marlix coming back when every word is one marlix said', () {
      expect(isEchoOf('cuentame mas sobre', said), isTrue);
      expect(isEchoOf('Tu día', said), isTrue);
    });

    test('is the person when there is a word marlix did not say', () {
      expect(isEchoOf('espera un momento', said), isFalse);
      expect(isEchoOf('cuéntame algo más', said), isFalse);
    });

    test('an empty hearing is nothing to act on', () {
      expect(isEchoOf('', said), isTrue);
    });

    test('with nothing said by marlix, anything is the person', () {
      expect(isEchoOf('hola', ''), isFalse);
    });
  });
}

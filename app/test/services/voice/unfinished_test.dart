import 'package:flutter_test/flutter_test.dart';
import 'package:marlix/services/voice/unfinished.dart';

void main() {
  group('endsUnfinished', () {
    test('a sentence that stops on a connector or a filler is unfinished', () {
      expect(endsUnfinished('Hoy fui al trabajo y'), isTrue);
      expect(endsUnfinished('Quería contarte pero'), isTrue);
      expect(endsUnfinished('Es que, eh'), isTrue);
      expect(endsUnfinished('Hablé con la'), isTrue);
    });

    test('trailing dots and commas mean the person was thinking', () {
      expect(endsUnfinished('Pues...'), isTrue);
      expect(endsUnfinished('Pues…'), isTrue);
      expect(endsUnfinished('Hoy, ayer,'), isTrue);
    });

    test('a sentence closed by Whisper is finished', () {
      expect(endsUnfinished('Hoy fui al trabajo y.'), isFalse);
      expect(endsUnfinished('¿Y tú?'), isFalse);
      expect(endsUnfinished('¡Qué dicha!'), isFalse);
    });

    test('a sentence that ends on a normal word is finished', () {
      expect(endsUnfinished('Me siento mejor hoy'), isFalse);
    });

    test('nothing is not unfinished', () {
      expect(endsUnfinished('   '), isFalse);
    });
  });
}

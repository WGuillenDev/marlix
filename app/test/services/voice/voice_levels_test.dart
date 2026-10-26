import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:marlix/services/voice/native_voice_engine.dart';
import 'package:marlix/services/voice/supertonic_voice_engine.dart';

void main() {
  group('Supertonic levels', () {
    // 50 ms steps at 1 kHz: 50 samples each.
    const rate = 1000;
    List<double> tone(double amplitude, int steps) => [
      for (var i = 0; i < 50 * steps; i++) amplitude * math.sin(i * 0.5),
    ];

    test('are relative to the loudest step of the sentence', () {
      final levels = SupertonicVoiceEngine.levelsOf([...tone(0.4, 2), ...tone(0.1, 2)], rate);

      expect(levels, hasLength(4));
      expect(levels[0], closeTo(1, 0.05));
      expect(levels[3], closeTo(0.25, 0.05));
    });

    test('a quiet voice moves the mouth as much as a loud one', () {
      final quiet = SupertonicVoiceEngine.levelsOf(tone(0.02, 2), rate);
      final loud = SupertonicVoiceEngine.levelsOf(tone(0.8, 2), rate);

      expect(quiet.first, closeTo(loud.first, 0.05));
    });

    test('silence is 0, also when the whole audio is silent', () {
      final levels = SupertonicVoiceEngine.levelsOf([
        ...tone(0.5, 1),
        ...List.filled(50, 0.0),
      ], rate);

      expect(levels.last, 0);
      expect(SupertonicVoiceEngine.levelsOf(List.filled(200, 0.0), rate), everyElement(0));
    });

    test('an empty audio has no levels', () {
      expect(SupertonicVoiceEngine.levelsOf(const [], rate), isEmpty);
    });

    test('a last step shorter than the others still counts', () {
      final levels = SupertonicVoiceEngine.levelsOf([...tone(0.5, 1), 0.5, -0.5, 0.5], rate);

      expect(levels, hasLength(2));
      expect(levels.last, greaterThan(0));
    });
  });

  group('native word levels', () {
    test('longer words open the mouth wider, within limits', () {
      expect(NativeVoiceEngine.wordLevel('y'), 0.3);
      expect(
        NativeVoiceEngine.wordLevel('casa'),
        lessThan(NativeVoiceEngine.wordLevel('conversación')),
      );
      expect(NativeVoiceEngine.wordLevel('extraordinariamente'), 1);
    });
  });
}

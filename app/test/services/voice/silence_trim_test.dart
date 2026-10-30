import 'package:flutter_test/flutter_test.dart';
import 'package:marlix/services/voice/silence_trim.dart';

void main() {
  const rate = 1000;
  List<double> silence(int ms) => List.filled(ms, 0.0);
  List<double> speech(int ms) => List.filled(ms, 0.5);

  group('trimSilence', () {
    test('cuts the silence at both ends and keeps a margin', () {
      final audio = [...silence(200), ...speech(100), ...silence(300)];

      final trimmed = trimSilence(audio, rate, keep: const Duration(milliseconds: 30));

      expect(trimmed.length, closeTo(100 + 2 * 30, 10));
      expect(trimmed.contains(0.5), isTrue);
    });

    test('leaves audio without silence as it is', () {
      expect(trimSilence(speech(100), rate), speech(100));
    });

    test('returns nothing for pure silence', () {
      expect(trimSilence(silence(200), rate), isEmpty);
    });

    test('does not cut a quiet pause inside the speech', () {
      final audio = [...speech(50), ...silence(80), ...speech(50)];

      expect(trimSilence(audio, rate), audio);
    });
  });
}

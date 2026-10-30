import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:marlix/services/voice/turn_detector.dart';
import 'package:marlix/services/voice/voice_activity.dart';

import 'energy_voice_activity.dart';

/// [ms] of frames with a voice of [probability] and a loudness of [level].
List<VoiceFrame> frames(int ms, double probability, [double level = 0.2]) {
  final count = ms ~/ TurnDetector.frameMs;
  final frame = pcmOf(TurnDetector.frameMs, level);
  return [for (var i = 0; i < count; i++) VoiceFrame(frame, probability)];
}

List<VoiceFrame> silence(int ms) => frames(ms, 0.02, 0.002);
List<VoiceFrame> speech(int ms) => frames(ms, 0.95);

List<TurnEvent> feed(TurnDetector detector, Iterable<List<VoiceFrame>> parts) => [
  for (final part in parts)
    for (final frame in part) ...detector.add(frame),
];

void main() {
  group('TurnDetector', () {
    test('silence is not a turn', () {
      final detector = TurnDetector();

      expect(feed(detector, [silence(5000)]), isEmpty);
      expect(detector.speaking, isFalse);
    });

    test('noise that does not look like a voice is not a turn, however loud', () {
      final detector = TurnDetector();

      expect(feed(detector, [frames(5000, 0.1, 0.5)]), isEmpty);
    });

    test('a voice-like sound that is quiet or not sure is not a turn', () {
      final detector = TurnDetector();

      expect(feed(detector, [frames(3000, 0.7, 0.2)]), isEmpty, reason: 'not sure enough');
      expect(feed(detector, [frames(3000, 0.95, 0.02)]), isEmpty, reason: 'too quiet, like a voice far away');
    });

    test('a click shorter than the minimum is not a turn', () {
      final detector = TurnDetector();

      expect(feed(detector, [silence(500), speech(100), silence(2000)]), isEmpty);
    });

    test('a turn starts with the voice and ends after the silence, with a pre-roll', () {
      final detector = TurnDetector();

      final events = feed(detector, [silence(1000), speech(500), silence(1200)]);

      expect(events, hasLength(2));
      expect(events.first, isA<TurnStarted>());
      final ended = events.last as TurnEnded;
      // The 21 frames kept when the start is confirmed (the pre-roll and the
      // minimum of speech), the 5 of speech that followed and the 25 of silence
      // that close the turn.
      expect(ended.pcm.length, (21 + 5 + 25) * TurnDetector.frameSamples * 2);
      expect(detector.speaking, isFalse);
    });

    test('a pause shorter than the silence stays in the same turn', () {
      final detector = TurnDetector();

      final events = feed(detector, [speech(600), silence(500), speech(600), silence(1200)]);

      expect(events.whereType<TurnStarted>(), hasLength(1));
      expect(events.whereType<TurnEnded>(), hasLength(1));
    });

    test('a frame that looks unsure does not cut the start of a turn', () {
      final detector = TurnDetector();

      final events = feed(detector, [speech(200), frames(32, 0.3), speech(300)]);

      expect(events.single, isA<TurnStarted>());
    });

    test('noise that only now and then looks like a voice is dropped, not sent', () {
      final detector = TurnDetector(longest: const Duration(seconds: 3));
      final flicker = [
        for (var i = 0; i < 100; i++) ...[...frames(32, 0.9), ...frames(64, 0.1, 0.02)],
      ];

      final events = feed(detector, [speech(400), flicker]);

      expect(events.whereType<TurnStarted>(), hasLength(1));
      expect(events.whereType<TurnEnded>(), isEmpty);
      expect(events.whereType<TurnDropped>(), hasLength(1));
    });

    test('the silence that ends the turn can be set', () {
      final detector = TurnDetector(silence: const Duration(milliseconds: 400));

      final events = feed(detector, [speech(600), silence(500)]);

      expect(events.last, isA<TurnEnded>());
    });

    test('while marlix speaks a voice that is not sure or loud is not the person', () {
      final detector = TurnDetector()..guarded = true;

      expect(feed(detector, [frames(2000, 0.8, 0.2)]), isEmpty, reason: 'not sure enough');
      expect(feed(detector, [frames(2000, 0.97, 0.05)]), isEmpty, reason: 'too quiet');
      expect(feed(detector, [frames(2000, 0.4, 0.05)]), isEmpty, reason: 'a fan, not a voice');
      expect(feed(TurnDetector(), [frames(400, 0.8, 0.05)]).first, isA<TurnStarted>());
    });

    test('while marlix speaks the person has to last longer', () {
      final detector = TurnDetector()..guarded = true;

      expect(feed(detector, [frames(300, 0.97, 0.3)]), isEmpty, reason: 'too short');
      expect(feed(detector, [frames(300, 0.97, 0.3)]).first, isA<TurnStarted>());
    });

    test('a turn that never stops is closed at the longest', () {
      final detector = TurnDetector(longest: const Duration(seconds: 2));

      final events = feed(detector, [speech(3000)]);

      expect(events.whereType<TurnEnded>(), hasLength(1));
    });

    test('flush ends the turn that was going on', () {
      final detector = TurnDetector();
      feed(detector, [speech(800)]);

      final events = detector.flush();

      expect(events.single, isA<TurnEnded>());
      expect(detector.speaking, isFalse);
    });

    test('flush with nobody speaking gives nothing', () {
      final detector = TurnDetector();
      feed(detector, [silence(500)]);

      expect(detector.flush(), isEmpty);
    });
  });

  group('EnergyVoiceActivity', () {
    test('audio in odd pieces gives the same frames', () {
      final bytes =
          (BytesBuilder()
                ..add(pcmOf(800, 0.002))
                ..add(pcmOf(700, 0.2)))
              .takeBytes();
      List<double> run(Iterable<Uint8List> chunks) {
        final activity = EnergyVoiceActivity();
        final seen = <double>[];
        activity.frames.listen((f) => seen.add(f.probability));
        chunks.forEach(activity.feed);
        return seen;
      }

      final whole = run([bytes]);
      final pieces = run([
        for (var i = 0; i < bytes.length; i += 1001)
          Uint8List.sublistView(bytes, i, i + 1001 > bytes.length ? bytes.length : i + 1001),
      ]);

      expect(pieces, whole);
    });
  });
}

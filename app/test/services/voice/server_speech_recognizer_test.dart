import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:marlix/services/api_exception.dart';
import 'package:marlix/services/voice/audio_capture.dart';
import 'package:marlix/services/voice/server_speech_recognizer.dart';
import 'package:marlix/services/voice/speech_recognizer.dart';

import 'energy_voice_activity.dart';

class FakeCapture implements AudioCapture {
  var stops = 0;
  StreamController<Uint8List>? _audio;

  @override
  Future<Stream<Uint8List>> start() async {
    _audio = StreamController<Uint8List>();
    return _audio!.stream;
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  void play(int ms, double level) => _audio!.add(pcmOf(ms, level));

  void say(int ms) => play(ms, 0.2);
  void hush(int ms) => play(ms, 0.002);
}

class BrokenCapture implements AudioCapture {
  @override
  Future<Stream<Uint8List>> start() async => throw StateError('no microphone');

  @override
  Future<void> stop() async {}
}

Future<void> settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late FakeCapture capture;
  late EnergyVoiceActivity activity;
  late List<Uint8List> sent;
  late Future<String> Function(Uint8List wav) answer;
  late ServerSpeechRecognizer recognizer;

  setUp(() {
    capture = FakeCapture();
    activity = EnergyVoiceActivity();
    sent = [];
    answer = (wav) async => 'Hola mae';
    recognizer = ServerSpeechRecognizer(
      capture: capture,
      activity: activity,
      transcribe: (wav) {
        sent.add(wav);
        return answer(wav);
      },
    );
  });

  Future<void> aTurn() async {
    await settle();
    capture
      ..say(600)
      ..hush(1200);
    await settle();
  }

  test('a spoken turn goes to the backend as a WAV and comes back as the final text', () async {
    final events = <Object>[];
    recognizer.listen().listen(events.add, onError: events.add);

    await aTurn();

    expect(events.map((e) => e.runtimeType), [SpeechVoice, SpeechUnderstanding, SpeechFinal]);
    expect((events.last as SpeechFinal).text, 'Hola mae');
    expect(ascii.decode(sent.single.sublist(0, 4)), 'RIFF');
    expect(capture.stops, greaterThan(0), reason: 'one turn per listen');
  });

  test('nothing understood is a noSpeech failure', () async {
    answer = (wav) async => '  ';
    final errors = <Object>[];
    recognizer.listen().listen((_) {}, onError: errors.add);

    await aTurn();

    expect((errors.single as SpeechException).failure, SpeechFailure.noSpeech);
  });

  test('a backend that is unreachable or slow is a busy failure', () async {
    for (final error in <Object>[
      const NetworkException('offline'),
      const ApiTimeoutException('slow'),
    ]) {
      answer = (wav) async => throw error;
      final errors = <Object>[];
      recognizer.listen().listen((_) {}, onError: errors.add);

      await aTurn();

      expect((errors.single as SpeechException).failure, SpeechFailure.busy);
    }
  });

  test('another backend error is an other failure', () async {
    answer = (wav) async => throw const InvalidResponseException('bad');
    final errors = <Object>[];
    recognizer.listen().listen((_) {}, onError: errors.add);

    await aTurn();

    expect((errors.single as SpeechException).failure, SpeechFailure.other);
  });

  test('a microphone that cannot open is unavailable', () async {
    final broken = ServerSpeechRecognizer(
      capture: BrokenCapture(),
      activity: EnergyVoiceActivity(),
      transcribe: (wav) async => '',
    );
    final errors = <Object>[];
    broken.listen().listen((_) {}, onError: errors.add);

    await settle();

    expect((errors.single as SpeechException).failure, SpeechFailure.unavailable);
  });

  test('stop ends the turn that was going on and asks for its text', () async {
    final events = <Object>[];
    recognizer.listen().listen(events.add, onError: events.add);
    await settle();
    capture.say(600);
    await settle();

    await recognizer.stop();
    await settle();

    expect(events.last, isA<SpeechFinal>());
  });

  test('stop with nobody heard is a noSpeech failure', () async {
    final errors = <Object>[];
    recognizer.listen().listen((_) {}, onError: errors.add);
    await settle();

    await recognizer.stop();
    await settle();

    expect((errors.single as SpeechException).failure, SpeechFailure.noSpeech);
  });

  test('cancel closes the microphone and the stream without a result', () async {
    final events = <Object>[];
    var done = false;
    recognizer.listen().listen(events.add, onError: events.add, onDone: () => done = true);
    await settle();

    await recognizer.cancel();
    await settle();

    expect(events, isEmpty);
    expect(done, isTrue);
    expect(capture.stops, greaterThan(0));
  });

  test(
    'while marlix speaks a sound as quiet as its own echo is not taken for the person',
    () async {
      final events = <Object>[];
      recognizer.listen(marlixSpeaking: () => true).listen(events.add, onError: events.add);
      await settle();

      capture.play(1000, 0.05);
      await settle();

      expect(events, isEmpty);
    },
  );
}

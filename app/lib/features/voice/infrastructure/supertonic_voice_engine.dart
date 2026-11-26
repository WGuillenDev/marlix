import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:supertonic_flutter/supertonic_flutter.dart';

import '../application/voice_engine.dart';
import '../domain/sentences.dart';
import '../domain/silence_trim.dart';
import '../domain/voice_config.dart';

class SupertonicVoiceEngine implements MeasurableVoiceEngine, PrefetchingVoiceEngine {
  SupertonicVoiceEngine({required this.config, SupertonicTTS? tts, TTSAudioPlayer? player})
    : _tts = tts ?? SupertonicTTS(),
      _player = player ?? TTSAudioPlayer();

  final VoiceConfig config;
  final SupertonicTTS _tts;
  final TTSAudioPlayer _player;

  // Report amplitude often enough to animate individual syllables.
  static const progressEvery = Duration(milliseconds: 50);

  static const benchmarkText =
      'Hola, qué gusto verte por aquí. Cuéntame cómo ha estado tu día y qué te gustaría hacer hoy.';

  final _prepared = <String, Future<TTSResult>>{};
  StreamController<VoiceEvent>? _active;
  StreamSubscription<PlayerState>? _playerStates;
  Timer? _ticker;
  Stopwatch? _clock;
  var _stopped = false;
  var _paused = false;

  @override
  VoiceEngineKind get kind => VoiceEngineKind.supertonic;

  /// Load verified files with networking disabled so the SDK cannot download them itself.
  @override
  Future<void> prepare() async {
    try {
      await HttpOverrides.runWithHttpOverrides(_tts.initialize, _NoNetwork());
    } on Object catch (error) {
      throw VoiceException('Supertonic could not load the model: $error');
    }
  }

  /// Measure seconds of audio generated per second of synthesis.
  @override
  Future<double> benchmark() async {
    final clock = Stopwatch()..start();
    final result = await _tts.synthesize(
      benchmarkText,
      language: config.language,
      voiceStyle: config.voice,
      config: _ttsConfig,
    );
    clock.stop();
    return result.duration / (clock.elapsedMicroseconds / Duration.microsecondsPerSecond);
  }

  /// Normalize each amplitude window against the loudest in the sentence.
  static List<double> levelsOf(List<double> audio, int sampleRate) {
    final step = (sampleRate * progressEvery.inMicroseconds / Duration.microsecondsPerSecond)
        .round();
    if (step <= 0 || audio.isEmpty) return const [];
    final rms = <double>[];
    for (var start = 0; start < audio.length; start += step) {
      final end = math.min(start + step, audio.length);
      var sum = 0.0;
      for (var i = start; i < end; i++) {
        sum += audio[i] * audio[i];
      }
      rms.add(math.sqrt(sum / (end - start)));
    }
    final loudest = rms.reduce(math.max);
    if (loudest == 0) return List.filled(rms.length, 0.0);
    return [for (final value in rms) value / loudest];
  }

  // Trim generated silence and add a controlled pause after the final punctuation.
  Future<TTSResult> _synthesize(String text) async {
    final result = await _tts.synthesize(
      text,
      language: config.language,
      voiceStyle: config.voice,
      config: _ttsConfig,
    );
    final rate = result.sampleRate;
    final pause = pauseAfter(text).inMicroseconds / Duration.microsecondsPerSecond;
    final audio = [
      ...trimSilence(result.audioData, rate),
      ...List.filled((pause * rate).round(), 0.0),
    ];
    return TTSResult(
      audioData: Float64List.fromList(audio),
      sampleRate: rate,
      duration: audio.length / rate,
    );
  }

  @override
  void warm(String text) {
    if (_prepared.containsKey(text)) return;
    final audio = _synthesize(text);
    _prepared[text] = audio;
    unawaited(audio.then<void>((_) {}, onError: (Object _) {}));
  }

  TTSConfig get _ttsConfig => TTSConfig(denoisingSteps: config.steps, speechSpeed: config.rate);

  @override
  Stream<VoiceEvent> speak(String text) {
    _finish(done: false);
    _stopped = false;
    _paused = false;
    final controller = StreamController<VoiceEvent>();
    _active = controller;
    unawaited(_run(text, controller));
    return controller.stream;
  }

  Future<void> _run(String text, StreamController<VoiceEvent> controller) async {
    try {
      final result = await (_prepared.remove(text) ?? _synthesize(text));
      if (_stopped || _active != controller) return;

      final clock = _clock = Stopwatch()..start();
      await _playerStates?.cancel();
      _playerStates = _player.playerStateStream.listen((state) {
        if (state == PlayerState.completed) _finish(done: true);
      });
      await _player.play(result);
      if (_stopped || _active != controller) return;
      // If paused before synthesis finished, hold playback at the start.
      if (_paused) {
        clock.stop();
        await _player.pause();
      }

      final levels = levelsOf(result.audioData, result.sampleRate);
      controller.add(const VoiceStarted(VoiceEngineKind.supertonic));
      _ticker = Timer.periodic(progressEvery, (_) {
        if (_paused) return;
        final spoken = clock.elapsedMicroseconds / Duration.microsecondsPerSecond;
        controller.add(VoiceProgress((spoken / result.duration).clamp(0.0, 1.0)));
        final step = (spoken * Duration.microsecondsPerSecond / progressEvery.inMicroseconds)
            .floor();
        controller.add(VoiceLevel(step < levels.length ? levels[step] : 0));
      });
    } on Object catch (error) {
      if (_active == controller) {
        controller.addError(VoiceException('Supertonic failed: $error'));
        _finish(done: false);
      }
    }
  }

  void _finish({required bool done}) {
    _ticker?.cancel();
    _ticker = null;
    final active = _active;
    if (active == null) return;
    _active = null;
    if (done) {
      // Close the mouth when playback finishes.
      active.add(const VoiceLevel(0));
      active.add(const VoiceFinished());
    }
    active.close();
  }

  @override
  Future<void> pause() async {
    if (_active == null || _paused) return;
    _paused = true;
    _clock?.stop();
    await _player.pause();
  }

  @override
  Future<void> resume() async {
    if (!_paused) return;
    _paused = false;
    if (_active == null) return;
    await _player.resume();
    _clock?.start();
  }

  @override
  Future<void> stop() async {
    _stopped = true;
    _paused = false;
    _prepared.clear();
    _finish(done: false);
    await _player.stop();
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _playerStates?.cancel();
    _player.dispose();
    _tts.dispose();
  }
}

class _NoNetwork extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..connectionFactory = (uri, proxyHost, proxyPort) =>
          Future.error(const SocketException('Only VoiceModelStore downloads the voice model'));
  }
}

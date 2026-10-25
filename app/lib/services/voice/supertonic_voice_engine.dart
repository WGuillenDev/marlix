import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:supertonic_flutter/supertonic_flutter.dart';

import '../../models/voice_config.dart';
import 'sentences.dart';
import 'voice_engine.dart';

/// Supertonic 3 (S6-1): a neural voice that runs on the phone. It sounds much
/// more human than the native one, but it needs the model downloaded (done by
/// `VoiceModelStore`, never by this class) and some speed from the phone.
class SupertonicVoiceEngine implements MeasurableVoiceEngine, PrefetchingVoiceEngine {
  SupertonicVoiceEngine({required this.config, SupertonicTTS? tts, TTSAudioPlayer? player})
    : _tts = tts ?? SupertonicTTS(),
      _player = player ?? TTSAudioPlayer();

  final VoiceConfig config;
  final SupertonicTTS _tts;
  final TTSAudioPlayer _player;

  /// How often the progress is reported while the audio plays.
  static const progressEvery = Duration(milliseconds: 100);

  /// Spoken once per phone to learn how fast it is (see `VoiceService`): a
  /// phrase of about five seconds of audio, like the ones marlix says.
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

  /// Loads the model that `VoiceModelStore` already downloaded and checked.
  ///
  /// The package downloads from `main`, with no check, when files are missing
  /// or a load fails, and it does it even over mobile data. Here the network is
  /// closed, so that can never happen behind the app's back: the download is
  /// the store's job.
  @override
  Future<void> prepare() async {
    try {
      await HttpOverrides.runWithHttpOverrides(_tts.initialize, _NoNetwork());
    } on Object catch (error) {
      throw VoiceException('Supertonic could not load the model: $error');
    }
  }

  /// Seconds of audio made per second of work, for [benchmarkText]. Under about
  /// 1.3 the next sentence is not ready when the current one ends.
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

  /// One sentence, clause by clause, with the pause of each comma in between.
  Future<TTSResult> _synthesize(String text) async {
    final clauses = splitClauses(text);
    if (clauses.length < 2) return _synthesizeClause(clauses.isEmpty ? text : clauses.single.text);

    final audio = <double>[];
    var duration = 0.0;
    int? sampleRate;
    for (final clause in clauses) {
      final part = await _synthesizeClause(clause.text);
      sampleRate = part.sampleRate;
      audio.addAll(part.audioData);
      duration += part.duration;
      if (clause.pause > Duration.zero) {
        final silence = clause.pause.inMicroseconds / Duration.microsecondsPerSecond;
        audio.addAll(List.filled((silence * sampleRate).round(), 0.0));
        duration += silence;
      }
    }
    return TTSResult(
      audioData: Float64List.fromList(audio),
      sampleRate: sampleRate!,
      duration: duration,
    );
  }

  Future<TTSResult> _synthesizeClause(String text) => _tts.synthesize(
    text,
    language: config.language,
    voiceStyle: config.voice,
    config: _ttsConfig,
  );

  @override
  void warm(String text) {
    if (_prepared.containsKey(text)) return;
    final audio = _synthesize(text);
    _prepared[text] = audio;
    // Nobody may ask for it (the reply was cut): a failure here is not an error.
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
      // Paused while the audio was still being made: hold it at the start.
      if (_paused) {
        clock.stop();
        await _player.pause();
      }

      controller.add(const VoiceStarted(VoiceEngineKind.supertonic));
      _ticker = Timer.periodic(progressEvery, (_) {
        final spoken = clock.elapsedMicroseconds / Duration.microsecondsPerSecond;
        controller.add(VoiceProgress((spoken / result.duration).clamp(0.0, 1.0)));
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
    if (done) active.add(const VoiceFinished());
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

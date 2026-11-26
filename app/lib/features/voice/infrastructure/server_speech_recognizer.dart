import 'dart:async';
import 'dart:typed_data';

import '../../../shared/application/api_exception.dart';
import '../application/speech_recognizer.dart';
import '../application/voice_activity.dart';
import '../domain/turn_detector.dart';
import '../domain/voice_frame.dart';
import '../domain/wav.dart';
import 'audio_capture.dart';

class ServerSpeechRecognizer implements SpeechRecognizer {
  ServerSpeechRecognizer({
    required this._capture,
    required this._activity,
    required this._transcribe,
  });

  final AudioCapture _capture;
  final VoiceActivity _activity;
  final Future<String> Function(Uint8List wav) _transcribe;

  @override
  Duration get reopenDelay => const Duration(milliseconds: 250);

  // End an idle turn so the microphone does not stay open indefinitely.
  static const idleLimit = Duration(seconds: 30);

  StreamController<SpeechEvent>? _active;
  StreamSubscription<Uint8List>? _audio;
  StreamSubscription<VoiceFrame>? _voice;
  TurnDetector? _detector;
  Timer? _idle;

  @override
  Stream<SpeechEvent> listen({Duration? silence, bool Function()? marlixSpeaking}) {
    final closing = _close();
    final controller = StreamController<SpeechEvent>();
    _active = controller;
    unawaited(_start(controller, silence, marlixSpeaking, closing));
    return controller.stream;
  }

  Future<void> _start(
    StreamController<SpeechEvent> controller,
    Duration? silence,
    bool Function()? marlixSpeaking,
    Future<void> closing,
  ) async {
    try {
      // Wait for the prior listen to close before opening the microphone again.
      await closing;
      if (_active != controller) return;
      final detector = silence == null ? TurnDetector() : TurnDetector(silence: silence);
      _detector = detector;
      await _activity.open();
      if (_active != controller) return;
      final audio = await _capture.start();
      if (_active != controller) {
        unawaited(_capture.stop());
        return;
      }
      _idle = Timer(
        idleLimit,
        () => _fail(controller, const SpeechException(SpeechFailure.noSpeech)),
      );
      _voice = _activity.frames.listen((frame) {
        // Require stronger speech evidence while playback can leak into the mic.
        detector.guarded = marlixSpeaking?.call() ?? false;
        _hear(controller, detector.add(frame));
      });
      _audio = audio.listen(
        _activity.feed,
        onError: (Object error) =>
            _fail(controller, SpeechException(SpeechFailure.other, '$error')),
      );
    } on Object catch (error) {
      _fail(controller, SpeechException(SpeechFailure.unavailable, '$error'));
    }
  }

  void _hear(StreamController<SpeechEvent> controller, List<TurnEvent> events) {
    for (final event in events) {
      if (_active != controller) return;
      switch (event) {
        case TurnStarted():
          _idle?.cancel();
          controller.add(const SpeechVoice());
        case TurnEnded(:final pcm):
          unawaited(_understand(controller, pcm));
        case TurnDropped():
          _fail(controller, const SpeechException(SpeechFailure.noSpeech));
      }
    }
  }

  Future<void> _understand(StreamController<SpeechEvent> controller, Uint8List pcm) async {
    controller.add(const SpeechUnderstanding());
    unawaited(_stopCapture());
    try {
      final text = (await _transcribe(pcm16ToWav(pcm))).trim();
      if (_active != controller) return;
      if (text.isEmpty) {
        _fail(controller, const SpeechException(SpeechFailure.noSpeech));
        return;
      }
      controller.add(SpeechFinal(text));
      await _close();
    } on Object catch (error) {
      _fail(controller, _failureOf(error));
    }
  }

  static SpeechException _failureOf(Object error) => switch (error) {
    ApiTimeoutException() ||
    NetworkException() ||
    LlmUnavailableException() ||
    RateLimitedException() => SpeechException(SpeechFailure.busy, '$error'),
    _ => SpeechException(SpeechFailure.other, '$error'),
  };

  void _fail(StreamController<SpeechEvent> controller, SpeechException error) {
    if (_active != controller) return;
    controller.addError(error);
    unawaited(_close());
  }

  Future<void> _stopCapture() async {
    _idle?.cancel();
    // Cancellation can stall when the stream is already closed.
    unawaited(_audio?.cancel());
    unawaited(_voice?.cancel());
    _audio = null;
    _voice = null;
    _activity.close();
    await _capture.stop();
  }

  Future<void> _close() async {
    final active = _active;
    _active = null;
    _detector = null;
    await _stopCapture();
    if (active != null && !active.isClosed) await active.close();
  }

  @override
  Future<void> stop() async {
    final controller = _active;
    final detector = _detector;
    if (controller == null || detector == null) return;
    final ended = detector.flush();
    if (ended.isEmpty) {
      _fail(controller, const SpeechException(SpeechFailure.noSpeech));
    } else {
      _hear(controller, ended);
    }
  }

  @override
  Future<void> cancel() => _close();
}

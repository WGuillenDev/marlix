import 'dart:async';

import 'package:marlix/models/voice_config.dart';
import 'package:marlix/services/voice/device_facts.dart';
import 'package:marlix/services/voice/speech_recognizer.dart';
import 'package:marlix/services/voice/voice_engine.dart';
import 'package:marlix/services/voice/voice_model_store.dart';

/// A phone described in a test.
class FakeFacts implements DeviceFacts {
  FakeFacts({
    this.lowRam = false,
    this.free = 5 << 30,
    this.link = ConnectionKind.unmetered,
    this.print = 'phone-1',
  });

  bool lowRam;
  int free;
  ConnectionKind link;
  String print;

  @override
  Future<bool> isLowRam() async => lowRam;

  @override
  Future<int> freeBytes() async => free;

  @override
  Future<ConnectionKind> connection() async => link;

  @override
  Future<String> fingerprint() async => print;
}

/// The model on the phone: it is there or not, and a download can fail.
class FakeModel implements VoiceModel {
  FakeModel({this.ready = false});

  bool ready;
  var downloads = 0;
  var deletions = 0;

  /// What the next download does before it ends.
  Future<void> Function()? onDownload;

  @override
  final manifest = const VoiceModelManifest(
    repo: 'Supertone/supertonic-3',
    revision: 'rev1',
    files: [VoiceModelFile(path: 'onnx/a.onnx', bytes: 400, sha256: 'x')],
  );

  @override
  Future<bool> isReady() async => ready;

  @override
  Future<void> download({void Function(DownloadProgress progress)? onProgress}) async {
    downloads++;
    onProgress?.call(const DownloadProgress(receivedBytes: 100, totalBytes: 400));
    await onDownload?.call();
    ready = true;
  }

  @override
  Future<void> deleteAll() async {
    deletions++;
    ready = false;
  }
}

/// What one call to `speak` does: say events, or fail.
typedef Script = List<Object>;

/// An engine that follows scripts, one per `speak` call; with no script left
/// it says the sentence normally.
class FakeEngine implements MeasurableVoiceEngine, PrefetchingVoiceEngine {
  FakeEngine(this.kind, {this.speed = 3.0, this.prepareError, this.onPrepare});

  @override
  final VoiceEngineKind kind;
  final double speed;
  final Object? prepareError;

  /// Runs while the model is being loaded, to look at the world at that moment.
  final void Function()? onPrepare;

  final scripts = <Script>[];
  final spoken = <String>[];

  /// What the service asked to prepare, and how many sentences were already
  /// said at that moment.
  final warmed = <String>[];
  final spokenWhenWarmed = <int>[];
  var prepared = 0;
  var benchmarks = 0;
  var stops = 0;
  var pauses = 0;
  var resumes = 0;
  var disposed = false;
  var _stopped = false;
  var _speaking = false;

  /// While set, `speak` stays open until it completes: a long sentence.
  Completer<void>? hold;

  @override
  Future<void> prepare() async {
    prepared++;
    onPrepare?.call();
    if (prepareError != null) throw prepareError!;
  }

  @override
  void warm(String text) {
    warmed.add(text);
    spokenWhenWarmed.add(spoken.length);
  }

  @override
  Future<double> benchmark() async {
    benchmarks++;
    return speed;
  }

  @override
  Stream<VoiceEvent> speak(String text) {
    spoken.add(text);
    _stopped = false;
    _speaking = true;
    final script = scripts.isEmpty
        ? <Object>[VoiceStarted(kind), const VoiceProgress(0.5), const VoiceFinished()]
        : scripts.removeAt(0);
    final controller = StreamController<VoiceEvent>();
    unawaited(() async {
      for (final step in script) {
        if (step is VoiceFinished && hold != null) {
          // A long sentence: it is still being said until the hold is released.
          await hold!.future;
          if (_stopped) break;
        }
        if (step is VoiceEvent) {
          controller.add(step);
        } else {
          controller.addError(step);
          _speaking = false;
          await controller.close();
          return;
        }
      }
      _speaking = false;
      await controller.close();
    }());
    return controller.stream;
  }

  @override
  Future<void> pause() async => pauses++;

  @override
  Future<void> resume() async => resumes++;

  @override
  Future<void> stop() async {
    stops++;
    _stopped = true;
    // Stopping an engine that is not speaking changes nothing.
    if (_speaking && hold != null && !hold!.isCompleted) hold!.complete();
  }

  @override
  Future<void> dispose() async => disposed = true;
}

/// A recognizer the test talks through: it says what the person "says".
class FakeRecognizer implements SpeechRecognizer {
  var listens = 0;

  @override
  Duration get reopenDelay => const Duration(milliseconds: 200);

  /// The `silence` the last `listen` asked for.
  Duration? lastSilence;
  var stops = 0;
  var cancels = 0;
  StreamController<SpeechEvent>? _stream;

  bool get isListening => _stream != null && !_stream!.isClosed;

  @override
  Stream<SpeechEvent> listen({Duration? silence, bool Function()? marlixSpeaking}) {
    listens++;
    lastSilence = silence;
    _stream = StreamController<SpeechEvent>();
    return _stream!.stream;
  }

  void hear(String text) => _stream!.add(SpeechPartial(text));

  /// The detector heard a voice that is not the end of the turn.
  void voice() => _stream!.add(const SpeechVoice());

  /// The turn ended and its audio went to be transcribed.
  void understanding() => _stream!.add(const SpeechUnderstanding());

  /// The turn ended by itself with nothing said.
  void end() => unawaited(_stream!.close());

  /// What the real one does after `stop`: the final result, then the end.
  void finish(String text) {
    _stream!.add(SpeechFinal(text));
    unawaited(_stream!.close());
  }

  void fail(SpeechFailure failure) {
    _stream!.addError(SpeechException(failure));
    unawaited(_stream!.close());
  }

  @override
  Future<void> stop() async => stops++;

  @override
  Future<void> cancel() async {
    cancels++;
    unawaited(_stream?.close());
  }
}

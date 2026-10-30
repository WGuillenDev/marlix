import 'dart:async';

import '../../models/voice_config.dart';
import 'device_facts.dart';
import 'sentences.dart';
import 'voice_engine.dart';
import 'voice_memory.dart';
import 'voice_model_store.dart';
import 'voice_planner.dart';

/// Where the voice stands on this phone. Screens show it; they never choose.
sealed class VoiceStatus {
  const VoiceStatus();
}

/// Nothing was checked yet.
final class VoiceIdle extends VoiceStatus {
  const VoiceIdle();
}

final class VoiceChecking extends VoiceStatus {
  const VoiceChecking();
}

/// Supertonic would work but its model is not on the phone. The person decides
/// when to download it: 401 MB, so wifi unless they say otherwise.
final class VoiceNeedsDownload extends VoiceStatus {
  const VoiceNeedsDownload({required this.totalBytes, required this.connection, this.failure});

  final int totalBytes;
  final ConnectionKind connection;

  /// Why the last try stopped, if there was one. It can continue.
  final String? failure;
}

final class VoiceDownloading extends VoiceStatus {
  const VoiceDownloading(this.progress);

  final DownloadProgress progress;
}

/// The voice works. [reason] is set when the engine is the native voice
/// although marlix prefers Supertonic, so the screens can explain it.
final class VoiceReady extends VoiceStatus {
  const VoiceReady(this.engine, {this.reason});

  final VoiceEngineKind engine;
  final NativeReason? reason;
}

/// No engine can speak: the phone has no Spanish voice that works and
/// Supertonic is not available. The text chat keeps working; the person should
/// be told.
final class VoiceUnavailable extends VoiceStatus {
  const VoiceUnavailable();
}

/// Chooses the engine for this phone, runs it and covers for it when it fails.
///
/// The rules are in docs/decisions.md ("Scaling to any phone"). In short:
/// Supertonic whenever the phone can run it, the native voice when it cannot,
/// and never a broken conversation: if Supertonic fails in the middle of a
/// reply, that reply goes on with the native voice.
class VoiceService {
  VoiceService({
    required this.config,
    required this.facts,
    required this.memory,
    required this.model,
    required this.createSupertonic,
    required this.createNative,
    required this.onStatus,
  });

  final VoiceConfig Function() config;
  final DeviceFacts facts;
  final VoiceMemory memory;
  final VoiceModel model;
  final MeasurableVoiceEngine Function(VoiceConfig config) createSupertonic;
  final VoiceEngine Function(VoiceConfig config) createNative;
  final void Function(VoiceStatus status) onStatus;

  /// Failures in a row before Supertonic is given up on until the app restarts.
  static const failuresToGiveUp = 3;

  VoiceStatus _status = const VoiceIdle();
  MeasurableVoiceEngine? _supertonic;
  VoiceEngine? _native;
  var _failures = 0;
  var _generation = 0;

  /// Open while the speech is paused: the sentence loop waits on it.
  Completer<void>? _pause;

  VoiceStatus get status => _status;

  void _set(VoiceStatus status) {
    _status = status;
    onStatus(status);
  }

  /// Looks at the phone and prepares the voice. Run when the app opens and
  /// whenever the avatar's configuration changes.
  Future<void> start() async {
    _set(const VoiceChecking());
    await _release();
    final settings = config();
    final revision = model.manifest.revision;

    // A load that never finished means the app died while loading the model,
    // which is what a phone short of memory does. That phone does not try again.
    if (memory.loadStarted != null) {
      if (memory.loadStarted == revision) await memory.markFailed(revision);
      await memory.endLoad();
    }

    final ready = await model.isReady();
    final plan = VoicePlanner.plan(
      config: settings,
      lowRam: await facts.isLowRam(),
      modelFailedBefore: memory.failed(revision),
      modelReady: ready,
      freeBytes: await facts.freeBytes(),
    );
    switch (plan) {
      case PlanNative(:final reason):
        await _useNative(reason);
      case PlanSupertonic(needsDownload: true):
        // Already measured as too slow here: downloading again would be for nothing.
        final speed = memory.speed(await _speedKey(settings));
        if (speed != null && !VoicePlanner.fastEnough(speed)) {
          await _useNative(NativeReason.tooSlow);
        } else {
          _set(
            VoiceNeedsDownload(
              totalBytes: model.manifest.totalBytes,
              connection: await facts.connection(),
            ),
          );
        }
      case PlanSupertonic():
        await _loadSupertonic();
    }
  }

  /// Downloads the model and loads it. Over mobile data only if the person
  /// allowed it; it does nothing without a connection. Until it ends, replies
  /// are spoken with the native voice.
  Future<void> download({bool allowMobileData = false}) async {
    final current = _status;
    if (current is! VoiceNeedsDownload) return;
    final connection = await facts.connection();
    if (connection == ConnectionKind.none) {
      _set(
        VoiceNeedsDownload(
          totalBytes: current.totalBytes,
          connection: connection,
          failure: 'No internet connection',
        ),
      );
      return;
    }
    if (connection == ConnectionKind.mobile && !allowMobileData) {
      _set(VoiceNeedsDownload(totalBytes: current.totalBytes, connection: connection));
      return;
    }
    if (await facts.freeBytes() < VoicePlanner.minFreeBytes) {
      await _useNative(NativeReason.noSpace);
      return;
    }

    _set(VoiceDownloading(DownloadProgress(receivedBytes: 0, totalBytes: current.totalBytes)));
    try {
      await model.download(onProgress: (progress) => _set(VoiceDownloading(progress)));
    } on VoiceModelException catch (error) {
      _set(
        VoiceNeedsDownload(
          totalBytes: current.totalBytes,
          connection: connection,
          failure: error.message,
        ),
      );
      return;
    }
    await _loadSupertonic();
  }

  Future<String> _speedKey(VoiceConfig settings) async =>
      '${await facts.fingerprint()}|${model.manifest.revision}|${settings.steps}|${settings.voice}';

  Future<void> _loadSupertonic() async {
    final settings = config();
    final revision = model.manifest.revision;
    final engine = createSupertonic(settings);
    await memory.beginLoad(revision);
    try {
      await engine.prepare();
      final key = await _speedKey(settings);
      var speed = memory.speed(key);
      if (speed == null) {
        speed = await engine.benchmark();
        await memory.saveSpeed(key, speed);
      }
      await memory.endLoad();
      if (!VoicePlanner.fastEnough(speed)) {
        await engine.dispose();
        await model.deleteAll();
        await _useNative(NativeReason.tooSlow);
        return;
      }
      _supertonic = engine;
      _failures = 0;
      _set(const VoiceReady(VoiceEngineKind.supertonic));
    } on Object {
      await memory.markFailed(revision);
      await memory.endLoad();
      await engine.dispose();
      await model.deleteAll();
      await _useNative(NativeReason.loadFailed);
    }
  }

  Future<void> _useNative(NativeReason reason) async {
    try {
      await _nativeEngine();
      _set(VoiceReady(VoiceEngineKind.native, reason: reason));
    } on NoSpanishVoiceException {
      _set(const VoiceUnavailable());
    }
  }

  Future<VoiceEngine> _nativeEngine() async {
    final existing = _native;
    if (existing != null) return existing;
    final engine = createNative(config());
    try {
      await engine.prepare();
    } on NoSpanishVoiceException {
      _set(const VoiceUnavailable());
      rethrow;
    }
    return _native = engine;
  }

  /// Speaks [text] sentence by sentence with the best engine the phone has.
  /// The stream carries one [VoiceStarted], the progress over the whole text, the
  /// level of the sound and one [VoiceFinished]; if no engine can speak it carries an error. While the
  /// model is downloading, the native voice speaks.
  Stream<VoiceEvent> speak(String text) {
    final controller = StreamController<VoiceEvent>();
    unawaited(_speakAll(text, controller));
    return controller.stream;
  }

  Future<void> _speakAll(String text, StreamController<VoiceEvent> controller) async {
    final turn = ++_generation;
    _openPause();
    await _stopEngines();
    bool stopped() => turn != _generation;

    final sentences = splitForSpeech(text);
    final totalChars = sentences.fold(0, (sum, sentence) => sum + sentence.length);
    var spokenChars = 0;
    var started = false;
    // Once Supertonic fails in a reply, the rest of that reply is native.
    var degraded = false;

    try {
      for (var index = 0; index < sentences.length; index++) {
        final sentence = sentences[index];
        final next = index + 1 < sentences.length ? sentences[index + 1] : null;
        var done = false;
        while (!done && !stopped()) {
          // Paused between two sentences: the next one waits for the resume.
          if (_pause case final pause?) await pause.future;
          if (stopped()) break;
          final VoiceEngine engine;
          try {
            engine = (!degraded && _supertonic != null) ? _supertonic! : await _nativeEngine();
          } on VoiceException catch (error) {
            controller.addError(error);
            return;
          }

          var finished = false;
          try {
            await for (final event in engine.speak(sentence)) {
              if (stopped()) break;
              switch (event) {
                case VoiceStarted():
                  if (!started) {
                    started = true;
                    controller.add(VoiceStarted(engine.kind));
                  }
                  // Sound is playing: get the next sentence ready now, so there is
                  // no silence between the two.
                  if (next != null && engine is PrefetchingVoiceEngine) engine.warm(next);
                case VoiceProgress(:final fraction):
                  controller.add(
                    VoiceProgress((spokenChars + fraction * sentence.length) / totalChars),
                  );
                case VoiceLevel():
                  controller.add(event);
                case VoiceFinished():
                  finished = true;
              }
            }
          } on Object {
            finished = false;
          }
          if (stopped()) break;

          if (finished) {
            done = true;
            if (engine.kind == VoiceEngineKind.supertonic) _failures = 0;
          } else if (engine.kind == VoiceEngineKind.supertonic) {
            degraded = true;
            await _supertonicFailed();
          } else {
            // A phone can say it has Spanish and still fail to speak it, when the
            // voice data was never downloaded. To the person that is the same as
            // having none, and the screens must say so.
            if (_supertonic == null) _set(const VoiceUnavailable());
            controller.addError(const VoiceException('The native voice could not speak'));
            return;
          }
        }
        if (stopped()) return;
        spokenChars += sentence.length;
      }
      if (!stopped()) controller.add(const VoiceFinished());
    } finally {
      await controller.close();
    }
  }

  /// Supertonic failed on a sentence. A few failures in a row mean it is not
  /// working on this phone any more: it is left until the app restarts.
  Future<void> _supertonicFailed() async {
    _failures++;
    if (_failures < failuresToGiveUp) return;
    final engine = _supertonic;
    _supertonic = null;
    await engine?.dispose();
    await _useNative(NativeReason.loadFailed);
  }

  bool get isPaused => _pause != null;

  /// Holds the speech where it is; [resume] continues it and [stop] ends it.
  Future<void> pause() async {
    if (_pause != null) return;
    _pause = Completer<void>();
    await _supertonic?.pause();
    await _native?.pause();
  }

  Future<void> resume() async {
    if (_pause == null) return;
    await _supertonic?.resume();
    await _native?.resume();
    _openPause();
  }

  Future<void> stop() async {
    _generation++;
    _openPause();
    await _stopEngines();
  }

  /// Lets a paused sentence loop go on, or end if it was stopped.
  void _openPause() {
    final pause = _pause;
    _pause = null;
    if (pause != null && !pause.isCompleted) pause.complete();
  }

  Future<void> _stopEngines() async {
    await _supertonic?.stop();
    await _native?.stop();
  }

  Future<void> _release() async {
    _generation++;
    _openPause();
    final supertonic = _supertonic;
    final native = _native;
    _supertonic = null;
    _native = null;
    await supertonic?.dispose();
    await native?.dispose();
  }

  Future<void> dispose() => _release();
}

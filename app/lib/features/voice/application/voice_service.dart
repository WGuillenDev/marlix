import 'dart:async';

import '../domain/sentences.dart';
import '../domain/voice_config.dart';
import 'device_facts.dart';
import 'sentence_feed.dart';
import 'voice_engine.dart';
import 'voice_memory.dart';
import 'voice_model.dart';
import 'voice_planner.dart';

sealed class VoiceStatus {
  const VoiceStatus();
}

final class VoiceIdle extends VoiceStatus {
  const VoiceIdle();
}

final class VoiceChecking extends VoiceStatus {
  const VoiceChecking();
}

final class VoiceNeedsDownload extends VoiceStatus {
  const VoiceNeedsDownload({required this.totalBytes, required this.connection, this.failure});

  final int totalBytes;
  final ConnectionKind connection;

  final String? failure;
}

final class VoiceDownloading extends VoiceStatus {
  const VoiceDownloading(this.progress);

  final DownloadProgress progress;
}

final class VoiceReady extends VoiceStatus {
  const VoiceReady(this.engine, {this.reason});

  final VoiceEngineKind engine;
  final NativeReason? reason;
}

final class VoiceUnavailable extends VoiceStatus {
  const VoiceUnavailable();
}

/// Falls back to the device engine if the preferred engine fails during a reply.
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

  static const failuresToGiveUp = 3;

  VoiceStatus _status = const VoiceIdle();
  MeasurableVoiceEngine? _supertonic;
  VoiceEngine? _native;
  var _failures = 0;
  var _generation = 0;

  Completer<void>? _pause;

  SentenceFeed? _feed;

  VoiceStatus get status => _status;

  void _set(VoiceStatus status) {
    _status = status;
    onStatus(status);
  }

  Future<void> start() async {
    _set(const VoiceChecking());
    await _release();
    final settings = config();
    final revision = model.manifest.revision;

    // An unfinished load indicates a process exit. Do not reload the same revision.
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

  /// Use the device voice during download and require consent for mobile data.
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

  /// Emits progress for the whole reply and a single completion event.
  Stream<VoiceEvent> speak(String text) => _speak(SentenceFeed.complete(splitForSpeech(text)));

  /// Reads arriving sentences and reports progress over the text received so far.
  Stream<VoiceEvent> speakSentences(Stream<String> sentences) =>
      _speak(SentenceFeed.live(sentences));

  Stream<VoiceEvent> _speak(SentenceFeed feed) {
    final controller = StreamController<VoiceEvent>();
    unawaited(_speakAll(feed, controller));
    return controller.stream;
  }

  Future<void> _speakAll(SentenceFeed feed, StreamController<VoiceEvent> controller) async {
    final turn = ++_generation;
    _feed?.cancel();
    _feed = feed;
    _openPause();
    await _stopEngines();
    bool stopped() => turn != _generation;

    var spokenChars = 0;
    var started = false;
    // Keep the fallback voice for the rest of this reply.
    var degraded = false;

    try {
      while (true) {
        final sentence = await feed.next();
        if (sentence == null || stopped()) break;
        var done = false;
        while (!done && !stopped()) {
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
                  if (feed.upcoming case final next? when engine is PrefetchingVoiceEngine) {
                    engine.warm(next);
                  }
                case VoiceProgress(:final fraction):
                  controller.add(
                    VoiceProgress((spokenChars + fraction * sentence.length) / feed.totalChars),
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
            // Android can report a locale before its voice data is installed.
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
      feed.cancel();
      await controller.close();
    }
  }

  Future<void> _supertonicFailed() async {
    _failures++;
    if (_failures < failuresToGiveUp) return;
    final engine = _supertonic;
    _supertonic = null;
    await engine?.dispose();
    await _useNative(NativeReason.loadFailed);
  }

  bool get isPaused => _pause != null;

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
    _feed?.cancel();
    _openPause();
    await _stopEngines();
  }

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
    _feed?.cancel();
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

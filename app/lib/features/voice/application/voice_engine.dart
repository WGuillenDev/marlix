import '../domain/voice_config.dart';

sealed class VoiceEvent {
  const VoiceEvent();
}

final class VoiceStarted extends VoiceEvent {
  const VoiceStarted(this.engine);

  final VoiceEngineKind engine;
}

final class VoiceProgress extends VoiceEvent {
  const VoiceProgress(this.fraction);

  final double fraction;
}

/// Normalized audio level for avatar lip movement. Native voices estimate it.
final class VoiceLevel extends VoiceEvent {
  const VoiceLevel(this.level);

  final double level;
}

final class VoiceFinished extends VoiceEvent {
  const VoiceFinished();
}

abstract interface class VoiceEngine {
  VoiceEngineKind get kind;

  Future<void> prepare();

  /// Cancellation closes the stream without emitting VoiceFinished.
  Stream<VoiceEvent> speak(String text);

  Future<void> pause();

  /// The native engine restarts the sentence when resuming.
  Future<void> resume();

  Future<void> stop();

  Future<void> dispose();
}

abstract interface class PrefetchingVoiceEngine implements VoiceEngine {
  /// Prefetch is best effort. Playback retries synthesis if needed.
  void warm(String text);
}

abstract interface class MeasurableVoiceEngine implements VoiceEngine {
  Future<double> benchmark();
}

class VoiceException implements Exception {
  const VoiceException(this.message);

  final String message;

  @override
  String toString() => 'VoiceException: $message';
}

class NoSpanishVoiceException extends VoiceException {
  const NoSpanishVoiceException() : super('The phone has no Spanish voice');
}

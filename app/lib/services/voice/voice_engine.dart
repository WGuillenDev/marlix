import '../../models/voice_config.dart';

/// What a voice engine reports while it speaks. Both engines give the same
/// signals: Supertonic knows the length of the audio it made and the native
/// voice reports the word it is on, and both are turned into a fraction.
sealed class VoiceEvent {
  const VoiceEvent();
}

/// The first sound is playing.
final class VoiceStarted extends VoiceEvent {
  const VoiceStarted(this.engine);

  final VoiceEngineKind engine;
}

/// How much of what is being said has been spoken, from 0 to 1.
final class VoiceProgress extends VoiceEvent {
  const VoiceProgress(this.fraction);

  final double fraction;
}

/// Everything was said.
final class VoiceFinished extends VoiceEvent {
  const VoiceFinished();
}

/// A way of making the avatar speak. Screens never see one: they go through
/// `VoiceController`, which chooses the engine for each phone.
abstract interface class VoiceEngine {
  VoiceEngineKind get kind;

  /// Gets the engine ready to speak: loads the model, or checks the phone has a
  /// Spanish voice. Throws [VoiceException] if it cannot.
  Future<void> prepare();

  /// Speaks [text]. The stream ends after [VoiceFinished], or without it when
  /// [stop] cut the speech; an engine failure comes as a stream error.
  Stream<VoiceEvent> speak(String text);

  /// Holds the speech without ending its stream. Does nothing when the engine
  /// is not speaking.
  Future<void> pause();

  /// Continues what [pause] held. The native voice cannot resume in the middle
  /// of a sentence, so it says the sentence again from its start.
  Future<void> resume();

  Future<void> stop();

  Future<void> dispose();
}

/// An engine that makes the audio before playing it, so it can get the next
/// sentence ready while the current one plays and leave no silence between them.
abstract interface class PrefetchingVoiceEngine implements VoiceEngine {
  /// Starts preparing [text], which will be passed to [speak] next. It never
  /// fails: if the preparation does, [speak] makes the audio again.
  void warm(String text);
}

/// An engine that can say how fast the phone runs it.
abstract interface class MeasurableVoiceEngine implements VoiceEngine {
  /// Seconds of audio made per second of work.
  Future<double> benchmark();
}

/// An engine could not do what it was asked.
class VoiceException implements Exception {
  const VoiceException(this.message);

  final String message;

  @override
  String toString() => 'VoiceException: $message';
}

/// The phone has no voice for the language, so even the fallback cannot speak.
class NoSpanishVoiceException extends VoiceException {
  const NoSpanishVoiceException() : super('The phone has no Spanish voice');
}

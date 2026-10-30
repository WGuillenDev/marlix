import 'dart:async';

/// What the recognizer hears while the person talks.
sealed class SpeechEvent {
  const SpeechEvent();
}

/// The person began to speak: enough to be sure, before anything is understood.
/// It is what lets them interrupt marlix without waiting for the words (S6-9).
final class SpeechVoice extends SpeechEvent {
  const SpeechVoice();
}

/// The person stopped speaking and what they said is being turned into text.
final class SpeechUnderstanding extends SpeechEvent {
  const SpeechUnderstanding();
}

/// What has been understood so far; it changes as the person keeps talking.
final class SpeechPartial extends SpeechEvent {
  const SpeechPartial(this.text);

  final String text;
}

/// The recognizer is done and this is what it understood.
final class SpeechFinal extends SpeechEvent {
  const SpeechFinal(this.text);

  final String text;
}

enum SpeechFailure {
  /// The phone has no recognizer for the language, or it cannot start.
  unavailable,

  /// The microphone heard nothing that could be turned into words.
  noSpeech,

  /// The phone's service is still closing the last turn; trying again in a
  /// moment works.
  busy,

  /// Anything else, such as no connection when the phone needs one.
  other,
}

class SpeechException implements Exception {
  const SpeechException(this.failure, [this.detail = '']);

  final SpeechFailure failure;
  final String detail;

  @override
  String toString() => 'SpeechException: ${failure.name} $detail'.trim();
}

/// A way of understanding the person (S6-8). Screens never see one: they go
/// through `SpeechController`, so the recognizer behind it can change (Whisper in
/// Groq or inside the phone are the alternatives of the card) without touching them.
///
/// The microphone permission is not its business; `MicrophonePermission` asks it.
abstract interface class SpeechRecognizer {
  /// How long to wait after a turn before opening the microphone again. The
  /// phone's own service needs a moment to close the last turn.
  Duration get reopenDelay;

  /// Starts listening. Once the person has started to speak, after [silence]
  /// without new words the turn ends by itself and the stream carries
  /// [SpeechFinal], so nobody has to press a button (S6-9); null leaves the end
  /// to the phone or to [stop]. A failure
  /// comes as a [SpeechException] error, and [cancel] ends it without a result.
  ///
  /// [marlixSpeaking] says whether marlix is speaking right now. A recognizer
  /// that can tell its own voice coming back from the person's uses it to ask
  /// for more before it takes a sound for the person interrupting.
  Stream<SpeechEvent> listen({Duration? silence, bool Function()? marlixSpeaking});

  /// Stops listening and asks for the final result of what was heard.
  Future<void> stop();

  /// Stops listening and throws away what was heard.
  Future<void> cancel();
}

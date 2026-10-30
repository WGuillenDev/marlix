import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../chat/avatar_controller.dart';
import '../chat/chat_controller.dart';
import '../chat/reply_reader.dart';
import '../../services/voice/voice_providers.dart';
import '../../widgets/avatar_marlix.dart';
import 'speech_controller.dart';

/// Whether the person is in a conversation with marlix, or has paused it.
enum ConversationMode { off, on, paused }

/// Whose turn it is (S6-9). It is not stored: it follows the microphone, the
/// chat and the reading, so the screen and the avatar can never disagree with
/// what is really happening.
enum ConversationPhase { paused, listening, thinking, speaking, ready }

ConversationPhase conversationPhase({
  required ConversationMode mode,
  required SpeechState speech,
  required bool thinking,
  required Reading reading,
}) {
  if (mode != ConversationMode.on) return ConversationPhase.paused;
  if (speech is SpeechListening && speech.heard.isNotEmpty) return ConversationPhase.listening;
  if (thinking || speech is SpeechTranscribing) return ConversationPhase.thinking;
  // Paused because a voice was heard over it: marlix is listening, not speaking.
  if (reading == Reading.speaking) return ConversationPhase.speaking;
  return speech is SpeechListening ? ConversationPhase.listening : ConversationPhase.ready;
}

/// Runs the conversation without buttons (S6-9): listening, thinking, speaking
/// and listening again, with the person free to interrupt. It only decides when
/// the microphone opens; `SpeechController` listens and `ReplyReader` speaks.
class ConversationController extends Notifier<ConversationMode> {
  /// Turns in a row with nobody speaking before the conversation pauses by
  /// itself, so a forgotten phone does not keep listening.
  static const maxEmptyTurns = 3;

  /// The wait before trying again when the phone's service was still busy with
  /// the last turn, and how many tries before giving up.
  static const retryAfter = Duration(milliseconds: 1500);
  static const maxRetries = 5;

  static const farewellAfter = Duration(milliseconds: 500);

  static const limitFarewell = 'Por hoy llegamos al límite de mensajes. Mañana seguimos hablando.';

  var _emptyTurns = 0;
  var _retries = 0;
  Duration? _nextWait;
  var _farewellSaid = false;
  Timer? _reopen;
  Timer? _farewellWait;

  @override
  ConversationMode build() {
    ref.onDispose(() {
      _reopen?.cancel();
      _farewellWait?.cancel();
    });
    ref.listen(speechControllerProvider, (previous, next) {
      if (next is SpeechListening && next.heard.isNotEmpty) {
        _emptyTurns = 0;
        _retries = 0;
      }
      _next();
    });
    ref.listen(replyReaderProvider, (_, _) => _next());
    ref.listen(chatControllerProvider, (_, _) => _next());
    return ConversationMode.off;
  }

  SpeechController get _speech => ref.read(speechControllerProvider.notifier);

  /// Starts the conversation: the microphone opens by itself.
  void start() {
    _emptyTurns = 0;
    _retries = 0;
    _farewellSaid = false;
    // A refusal or a failure of the last try must not pause it again at once.
    final speech = ref.read(speechControllerProvider);
    if (speech is SpeechDenied || speech is SpeechProblem) unawaited(_speech.cancel());
    state = ConversationMode.on;
    _next();
  }

  /// Seguir hablando after a pause or a problem.
  void resume() => start();

  /// Closes the microphone and quiets marlix, but stays in the mode.
  Future<void> pause() async {
    if (state == ConversationMode.off) return;
    state = ConversationMode.paused;
    _reopen?.cancel();
    _farewellWait?.cancel();
    await _speech.cancel();
    await ref.read(replyReaderProvider.notifier).stop();
  }

  /// Leaves the mode for good.
  Future<void> end() async {
    _reopen?.cancel();
    _farewellWait?.cancel();
    final wasOff = state == ConversationMode.off;
    state = ConversationMode.off;
    if (wasOff) return;
    await _speech.cancel();
    await ref.read(replyReaderProvider.notifier).stop();
  }

  /// The avatar listens whenever the screen says "te escucho": the microphone
  /// may have opened while marlix was still speaking, and nothing else tells the
  /// avatar when it finishes.
  void _followPhase() {
    final reading = ref.read(replyReaderProvider);
    final phase = conversationPhase(
      mode: state,
      speech: ref.read(speechControllerProvider),
      thinking: ref.read(chatControllerProvider).sending && reading == Reading.idle,
      reading: reading,
    );
    final avatar = ref.read(avatarStateProvider.notifier);
    if (phase == ConversationPhase.listening &&
        ref.read(avatarStateProvider) != AvatarState.listening) {
      avatar.listen();
    }
  }

  void _next() {
    if (state != ConversationMode.on || !ref.mounted) return;
    _followPhase();
    final chat = ref.read(chatControllerProvider);
    if (chat.limitReached) {
      _farewell();
      return;
    }
    if (chat.sending) return;

    switch (ref.read(speechControllerProvider)) {
      case SpeechListening() || SpeechTranscribing():
        return;
      case SpeechIdle():
        _reopenSoon();
      case SpeechProblem(failure: SpeechFailure.noSpeech):
        // Nobody spoke: listen again, up to a few turns. While marlix speaks the
        // person is not expected to, so those turns do not count.
        final marlixIsSpeaking = ref.read(replyReaderProvider) != Reading.idle;
        if (!marlixIsSpeaking && ++_emptyTurns >= maxEmptyTurns) {
          _emptyTurns = 0;
          state = ConversationMode.paused;
        }
        _speech.clear();
      case SpeechProblem(failure: SpeechFailure.busy):
        if (++_retries > maxRetries) {
          _retries = 0;
          state = ConversationMode.paused;
        }
        _nextWait = retryAfter;
        _speech.clear();
      case SpeechDenied() || SpeechProblem():
        // The message stays on screen; the person decides when to try again.
        state = ConversationMode.paused;
    }
  }

  void _reopenSoon() {
    if (_reopen?.isActive ?? false) return;
    final reading = ref.read(replyReaderProvider);
    final wait =
        _nextWait ??
        (reading == Reading.idle ? ref.read(speechRecognizerProvider).reopenDelay : Duration.zero);
    _nextWait = null;
    _reopen = Timer(wait, () {
      if (state != ConversationMode.on || !ref.mounted) return;
      final chat = ref.read(chatControllerProvider);
      if (chat.sending || chat.limitReached) return;
      if (ref.read(speechControllerProvider) is SpeechIdle) unawaited(_speech.listen());
    });
  }

  /// The day ran out: marlix says so once, after finishing what it was saying,
  /// and the conversation ends without the microphone. The short wait lets the
  /// reply that used up the day start being read first, so the farewell does
  /// not cut it.
  void _farewell() {
    unawaited(_speech.cancel());
    if (_farewellSaid) {
      if (ref.read(replyReaderProvider) == Reading.idle) state = ConversationMode.off;
      return;
    }
    if (ref.read(replyReaderProvider) != Reading.idle || (_farewellWait?.isActive ?? false)) return;
    _farewellWait = Timer(farewellAfter, () {
      if (state != ConversationMode.on || !ref.mounted) return;
      if (ref.read(replyReaderProvider) != Reading.idle) return _next();
      _farewellSaid = true;
      unawaited(ref.read(replyReaderProvider.notifier).read(limitFarewell));
    });
  }
}

final conversationControllerProvider = NotifierProvider<ConversationController, ConversationMode>(
  ConversationController.new,
);

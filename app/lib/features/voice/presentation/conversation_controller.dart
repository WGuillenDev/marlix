import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../avatar/presentation/avatar_controller.dart';
import '../../avatar/presentation/avatar_marlix.dart';
import '../../conversation/presentation/chat_controller.dart';
import '../../conversation/presentation/reply_reader.dart';
import '../composition/voice_providers.dart';
import 'speech_controller.dart';

enum ConversationMode { off, on, paused }

/// Derive the active turn from mic, reply and playback state.
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
  if (reading == Reading.speaking || reading == Reading.preparing) {
    return ConversationPhase.speaking;
  }
  return speech is SpeechListening ? ConversationPhase.listening : ConversationPhase.ready;
}

class ConversationController extends Notifier<ConversationMode> {
  // Pause after repeated silence so an unattended microphone does not stay open.
  static const maxEmptyTurns = 3;

  // Give the recognizer time to finish closing its previous turn.
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

  void start() {
    _emptyTurns = 0;
    _retries = 0;
    _farewellSaid = false;
    // Clear the previous audio error so it does not pause the new session.
    final speech = ref.read(speechControllerProvider);
    if (speech is SpeechDenied || speech is SpeechProblem) unawaited(_speech.cancel());
    state = ConversationMode.on;
    ref.read(callRouteProvider).inCall = true;
    _next();
  }

  void resume() => start();

  Future<void> pause() async {
    if (state == ConversationMode.off) return;
    state = ConversationMode.paused;
    ref.read(callRouteProvider).inCall = false;
    _reopen?.cancel();
    _farewellWait?.cancel();
    await _speech.cancel();
    await ref.read(replyReaderProvider.notifier).stop();
  }

  Future<void> end() async {
    _reopen?.cancel();
    _farewellWait?.cancel();
    final wasOff = state == ConversationMode.off;
    state = ConversationMode.off;
    ref.read(callRouteProvider).inCall = false;
    if (wasOff) return;
    await _speech.cancel();
    await ref.read(replyReaderProvider.notifier).stop();
  }

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
        // Silence during the assistant's playback does not count as an idle turn.
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

  /// Let the final reply start before queuing the daily-limit message.
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

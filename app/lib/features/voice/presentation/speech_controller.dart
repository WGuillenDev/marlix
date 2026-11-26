import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../avatar/presentation/avatar_controller.dart';
import '../../conversation/presentation/chat_controller.dart';
import '../../conversation/presentation/reply_reader.dart';
import '../application/microphone_permission.dart';
import '../application/speech_recognizer.dart';
import '../composition/microphone_provider.dart';
import '../composition/voice_providers.dart';
import '../domain/echo.dart';
import '../domain/unfinished.dart';

export '../application/speech_recognizer.dart' show SpeechFailure;

sealed class SpeechState {
  const SpeechState();
}

final class SpeechIdle extends SpeechState {
  const SpeechIdle();
}

final class SpeechListening extends SpeechState {
  const SpeechListening([this.heard = '']);

  final String heard;
}

final class SpeechTranscribing extends SpeechState {
  const SpeechTranscribing();
}

/// Blocked permission can only be restored from system settings.
final class SpeechDenied extends SpeechState {
  const SpeechDenied({required this.blocked});

  final bool blocked;
}

final class SpeechProblem extends SpeechState {
  const SpeechProblem(this.failure);

  final SpeechFailure failure;
}

// Leave time for natural pauses before closing a turn.
final speechSilenceProvider = Provider<Duration>((ref) => const Duration(seconds: 1));

// Allow a short continuation after speech that seems unfinished.
final speechCarryWaitProvider = Provider<Duration>((ref) => const Duration(seconds: 4));

class SpeechController extends Notifier<SpeechState> {
  StreamSubscription<SpeechEvent>? _listening;

  var _overReply = false;

  /// Marlix was paused because a voice was heard over it, until the words say
  /// whether it was the person. The phone does not always cancel marlix's own
  /// voice, so a voice alone is not enough to cut it.
  var _heldReply = false;

  // Buffer incomplete speech for the next turn or until the continuation window expires.
  var _carry = '';
  var _carries = 0;
  Timer? _carryTimer;

  // Cap continuation attempts so unfinished speech eventually receives a reply.
  static const maxCarries = 2;

  @override
  SpeechState build() {
    final recognizer = ref.read(speechRecognizerProvider);
    ref.onDispose(() {
      _carryTimer?.cancel();
      unawaited(_listening?.cancel());
      unawaited(recognizer.cancel());
    });
    return const SpeechIdle();
  }

  SpeechRecognizer get _recognizer => ref.read(speechRecognizerProvider);

  AvatarController get _avatar => ref.read(avatarStateProvider.notifier);

  bool get listening => state is SpeechListening;

  String get _lastReply {
    final last = ref.read(chatControllerProvider).entries.lastOrNull;
    return last is MarlixEntry ? last.message.content : '';
  }

  Future<void> listen() async {
    if (listening) return;
    final access = await ref.read(microphonePermissionProvider).ask();
    if (!ref.mounted || listening) return;
    if (access != MicrophoneAccess.granted) {
      state = SpeechDenied(blocked: access == MicrophoneAccess.blocked);
      return;
    }

    _overReply = ref.read(replyReaderProvider) != Reading.idle;
    state = const SpeechListening();
    if (!_overReply) _avatar.listen();
    // Cancellation can stall after the stream ends, so do not block the next listen.
    unawaited(_listening?.cancel());
    _listening = _recognizer
        .listen(
          silence: ref.read(speechSilenceProvider),
          marlixSpeaking: () => ref.read(replyReaderProvider) != Reading.idle,
        )
        .listen(
          _onEvent,
          onError: (Object error) {
            if (!ref.mounted) return;
            _avatar.stopListening();
            _avatar.stopThinking();
            _releaseReply();
            state = SpeechProblem(error is SpeechException ? error.failure : SpeechFailure.other);
          },
          onDone: () {
            if (ref.mounted && state is SpeechListening) {
              _avatar.stopListening();
              state = const SpeechIdle();
            }
          },
        );
  }

  void _onEvent(SpeechEvent event) {
    if (!ref.mounted) return;
    switch (event) {
      case SpeechVoice():
        _carryTimer?.cancel();
        final reading = ref.read(replyReaderProvider);
        if (reading == Reading.speaking || reading == Reading.preparing) {
          _heldReply = true;
          unawaited(ref.read(replyReaderProvider.notifier).pause());
        }
        _avatar.listen();
        if (state is! SpeechListening) state = const SpeechListening();
      case SpeechUnderstanding():
        _avatar.think();
        state = const SpeechTranscribing();
      case SpeechPartial(:final text):
        if (_overReply && isEchoOf(text, _lastReply)) return;
        if (ref.read(replyReaderProvider) != Reading.idle) {
          unawaited(ref.read(replyReaderProvider.notifier).stop());
          _avatar.listen();
        }
        state = SpeechListening(text);
      case SpeechFinal(:final text):
        _avatar.stopListening();
        _avatar.stopThinking();
        state = const SpeechIdle();
        if (_overReply && isEchoOf(text, _lastReply)) {
          _releaseReply();
          return;
        }
        if (_heldReply) {
          _heldReply = false;
          unawaited(ref.read(replyReaderProvider.notifier).stop());
        }
        final said = [_carry, text].where((part) => part.isNotEmpty).join(' ');
        if (endsUnfinished(said) && _carries < maxCarries) {
          _carry = said;
          _carries++;
          _carryTimer?.cancel();
          _carryTimer = Timer(ref.read(speechCarryWaitProvider), _sendCarry);
          return;
        }
        _send(said);
    }
  }

  void _releaseReply() {
    if (!_heldReply) return;
    _heldReply = false;
    unawaited(ref.read(replyReaderProvider.notifier).resume());
  }

  void _send(String text) {
    _carry = '';
    _carries = 0;
    _carryTimer?.cancel();
    unawaited(ref.read(chatControllerProvider.notifier).send(text));
  }

  void _sendCarry() {
    if (!ref.mounted || _carry.isEmpty) return;
    _send(_carry);
  }

  /// Reset controller state only. The recognizer already closed this turn.
  void clear() {
    if (_carry.isNotEmpty) _sendCarry();
    _listening = null;
    _avatar.stopListening();
    _avatar.stopThinking();
    state = const SpeechIdle();
  }

  Future<void> cancel() async {
    _carryTimer?.cancel();
    _heldReply = false;
    _carry = '';
    _carries = 0;
    final listening = _listening;
    _listening = null;
    unawaited(listening?.cancel());
    _avatar.stopListening();
    _avatar.stopThinking();
    state = const SpeechIdle();
    await _recognizer.cancel();
  }

  Future<void> openSettings() => ref.read(microphonePermissionProvider).openSettings();
}

final speechControllerProvider = NotifierProvider<SpeechController, SpeechState>(
  SpeechController.new,
);

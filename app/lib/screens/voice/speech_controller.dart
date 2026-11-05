import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/microphone_permission.dart';
import '../../services/voice/echo.dart';
import '../../services/voice/speech_recognizer.dart';
import '../../services/voice/unfinished.dart';
import '../../services/voice/voice_providers.dart';
import '../chat/avatar_controller.dart';
import '../chat/chat_controller.dart';
import '../chat/reply_reader.dart';

export '../../services/voice/speech_recognizer.dart' show SpeechFailure;

sealed class SpeechState {
  const SpeechState();
}

/// Not listening.
final class SpeechIdle extends SpeechState {
  const SpeechIdle();
}

/// The microphone is open; [heard] is what has been understood so far.
final class SpeechListening extends SpeechState {
  const SpeechListening([this.heard = '']);

  final String heard;
}

/// The person finished speaking and what they said is being turned into text.
final class SpeechTranscribing extends SpeechState {
  const SpeechTranscribing();
}

/// The person did not allow the microphone. When [blocked] the system will not
/// ask again, so the phone's settings are the only way.
final class SpeechDenied extends SpeechState {
  const SpeechDenied({required this.blocked});

  final bool blocked;
}

/// The recognizer could not understand the person; writing keeps working.
final class SpeechProblem extends SpeechState {
  const SpeechProblem(this.failure);

  final SpeechFailure failure;
}

/// How long the person is silent before the turn is theirs no more: too short
/// cuts them mid-sentence, too long feels slow (S6-9). 1.2 s cut people at
/// natural pauses on the S24, because the phone sends the words in bursts.
final speechSilenceProvider = Provider<Duration>((ref) => const Duration(seconds: 1));

/// How long marlix waits for the rest of a sentence that sounded unfinished
/// before it answers (S6-9). A provider so tests do not wait for it.
final speechCarryWaitProvider = Provider<Duration>((ref) => const Duration(seconds: 4));

/// The only way screens listen to the person (S6-8). What is understood goes
/// through the same `ChatController.send` as typed text, so the crisis filter of
/// `POST /chat` applies equally. Nothing here can break the text chat.
///
/// The microphone can be open while marlix speaks, so the person can interrupt
/// (S6-9). A voice heard over marlix pauses it at once; the words decide: the
/// person's cut the reading, marlix's own echo or noise let it go on.
class SpeechController extends Notifier<SpeechState> {
  StreamSubscription<SpeechEvent>? _listening;

  /// The turn started while marlix was speaking, so what it hears may be marlix.
  var _overReply = false;

  /// Marlix was paused because a voice was heard over it, until the words say
  /// whether it was the person. The phone does not always cancel marlix's own
  /// voice, so a voice alone is not enough to cut it.
  var _heldReply = false;

  /// What the person said in a sentence that sounded unfinished: it goes with
  /// the next turn, or alone if nothing else comes.
  var _carry = '';
  var _carries = 0;
  Timer? _carryTimer;

  /// A sentence is held back at most twice, so marlix never stays silent for ever.
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

  /// What marlix is saying, or said last: the voice that can come back.
  String get _lastReply {
    final last = ref.read(chatControllerProvider).entries.lastOrNull;
    return last is MarlixEntry ? last.message.content : '';
  }

  /// Opens the microphone, asking for the permission first if the person has
  /// not given it. It does not cut marlix: if it is speaking, the microphone
  /// stays open to hear an interruption.
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
    // Not awaited: a subscription whose stream already ended can take long to
    // answer, and the microphone must not wait for it.
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
            // Noise, or nothing understood: marlix goes on where it was.
            _releaseReply();
            state = SpeechProblem(error is SpeechException ? error.failure : SpeechFailure.other);
          },
          onDone: () {
            // Ended without a result, such as cancelled: nothing is left open.
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
          // The person speaks over marlix: it goes quiet and listens.
          unawaited(ref.read(replyReaderProvider.notifier).stop());
          _avatar.listen();
        }
        state = SpeechListening(text);
      case SpeechFinal(:final text):
        _avatar.stopListening();
        _avatar.stopThinking();
        state = const SpeechIdle();
        // Marlix's own voice coming back, not the person.
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

  /// Nothing came after a sentence that sounded unfinished: it was the whole thing.
  void _sendCarry() {
    if (!ref.mounted || _carry.isEmpty) return;
    _send(_carry);
  }

  /// Forgets a turn that ended by itself, such as one nobody spoke in. The
  /// recognizer is not touched: it is already done.
  void clear() {
    // A turn without words after an unfinished sentence ends it.
    if (_carry.isNotEmpty) _sendCarry();
    _listening = null;
    _avatar.stopListening();
    _avatar.stopThinking();
    state = const SpeechIdle();
  }

  /// Closes the microphone and drops what was heard.
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

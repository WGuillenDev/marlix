import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/chat.dart';
import '../../widgets/avatar_marlix.dart';
import '../onboarding/profile_controller.dart';
import 'chat_controller.dart';

const defaultAvatarFolder = 'assets/avatars/marlix';

/// The folder to load the layers from: the one in the user's profile (S5-7) or,
/// if there is none or it does not look like a bundled avatar, marlix's.
/// The seed stores it with a trailing slash, which would break `folder/name.svg`.
String avatarFolderFrom(String? layersPath) {
  final path = layersPath?.replaceFirst(RegExp(r'/+$'), '');
  if (path == null || !path.startsWith('assets/avatars/') || path.contains('..')) {
    return defaultAvatarFolder;
  }
  return path;
}

/// Folder of the layers of the avatar to show. The profile is loaded before
/// the chat opens; while it loads or if it failed, marlix's folder is used.
final avatarFolderProvider = Provider<String>(
  (ref) => avatarFolderFrom(ref.watch(profileControllerProvider).value?.avatarLayersPath),
);

/// What the avatar is doing (S5-4), the only place that decides it: screens
/// just watch it, so voice mode adds `listening` here without touching the
/// widget.
///
/// It follows the conversation: `thinking` while marlix replies, a brief
/// `happy` after a reply to a positive message, `idle` otherwise. The voice
/// (S6-5) sets `speaking` while its audio plays, and the microphone (S6-9)
/// sets `listening`.
class AvatarController extends Notifier<AvatarState> {
  /// How long the avatar celebrates before going back to rest.
  static const happyFor = Duration(seconds: 3);

  Timer? _happyTimer;

  @override
  AvatarState build() {
    ref.onDispose(() => _happyTimer?.cancel());
    ref.listen(chatControllerProvider, (previous, next) {
      if (next.sending) {
        _show(AvatarState.thinking);
      } else if (previous?.sending ?? false) {
        // Only the moment the reply arrives, not every later change of the chat.
        final last = next.entries.lastOrNull;
        _show(
          last is MarlixEntry && last.tone == MessageTone.positive
              ? AvatarState.happy
              : AvatarState.idle,
        );
      }
    });
    return AvatarState.idle;
  }

  /// The microphone is open and the person is being heard (S6-9).
  void listen() => _show(AvatarState.listening);

  /// The microphone closed. It only ends `listening`: a reply being thought or
  /// said keeps its own state.
  void stopListening() {
    if (state == AvatarState.listening) _show(AvatarState.idle);
  }

  /// What the person said is being turned into text: marlix is already
  /// thinking, before the message is sent.
  void think() => _show(AvatarState.thinking);

  /// What was heard came to nothing, or is about to be sent. It only ends a
  /// `thinking` that the chat is not behind.
  void stopThinking() {
    if (state == AvatarState.thinking && !ref.read(chatControllerProvider).sending) {
      _show(AvatarState.idle);
    }
  }

  /// The first sound of a reply is playing.
  void speak() => _show(AvatarState.speaking);

  /// The sound ended, was cut or failed. It only closes the mouth: if the
  /// avatar is thinking about a new message, that stays.
  void rest() {
    if (state != AvatarState.speaking) return;
    _show(AvatarState.idle);
    ref.read(avatarVolumeProvider.notifier).set(0);
  }

  void _show(AvatarState next) {
    _happyTimer?.cancel();
    state = next;
    if (next == AvatarState.happy) {
      _happyTimer = Timer(happyFor, () => state = AvatarState.idle);
    }
  }
}

final avatarStateProvider = NotifierProvider<AvatarController, AvatarState>(AvatarController.new);

/// How loud the voice is right now, from 0 to 1. The avatar's mouth follows it
/// while `speaking`; it is its own provider so only the avatar rebuilds with it.
class AvatarVolume extends Notifier<double> {
  @override
  double build() => 0;

  void set(double volume) => state = volume.clamp(0.0, 1.0);
}

final avatarVolumeProvider = NotifierProvider<AvatarVolume, double>(AvatarVolume.new);

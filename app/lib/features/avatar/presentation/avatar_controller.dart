import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../account/presentation/profile_controller.dart';
import '../../conversation/domain/chat.dart';
import '../../conversation/presentation/chat_controller.dart';
import 'avatar_marlix.dart';

const defaultAvatarFolder = 'assets/avatars/marlix';

String avatarFolderFrom(String? layersPath) {
  final path = layersPath?.replaceFirst(RegExp(r'/+$'), '');
  if (path == null || !path.startsWith('assets/avatars/') || path.contains('..')) {
    return defaultAvatarFolder;
  }
  return path;
}

final avatarFolderProvider = Provider<String>(
  (ref) => avatarFolderFrom(ref.watch(profileControllerProvider).value?.avatarLayersPath),
);

/// Owns avatar state transitions across chat, transcription and playback.
class AvatarController extends Notifier<AvatarState> {
  static const happyFor = Duration(seconds: 3);

  Timer? _happyTimer;

  @override
  AvatarState build() {
    ref.onDispose(() => _happyTimer?.cancel());
    ref.listen(chatControllerProvider, (previous, next) {
      if (next.sending) {
        _show(AvatarState.thinking);
      } else if (previous?.sending ?? false) {
        if (state == AvatarState.speaking) return;
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

  void listen() => _show(AvatarState.listening);

  /// Closing the microphone only clears the listening pose.
  void stopListening() {
    if (state == AvatarState.listening) _show(AvatarState.idle);
  }

  /// What the person said is being turned into text: marlix is already
  /// thinking, before the message is sent.
  void think() => _show(AvatarState.thinking);

  /// Clear transcription's thinking pose only if chat has not taken it over.
  void stopThinking() {
    if (state == AvatarState.thinking && !ref.read(chatControllerProvider).sending) {
      _show(AvatarState.idle);
    }
  }

  void speak() => _show(AvatarState.speaking);

  /// Stop lip movement without clearing a newer thinking pose.
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

/// Normalized amplitude used only while speaking.
class AvatarVolume extends Notifier<double> {
  @override
  double build() => 0;

  void set(double volume) => state = volume.clamp(0.0, 1.0);
}

final avatarVolumeProvider = NotifierProvider<AvatarVolume, double>(AvatarVolume.new);

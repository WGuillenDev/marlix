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
/// just watch it, so voice mode adds `listening` and `speaking` here without
/// touching the widget.
///
/// It follows the conversation: `thinking` while marlix replies, a brief
/// `happy` after a reply to a positive message, `idle` otherwise.
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

  void _show(AvatarState next) {
    _happyTimer?.cancel();
    state = next;
    if (next == AvatarState.happy) {
      _happyTimer = Timer(happyFor, () => state = AvatarState.idle);
    }
  }
}

final avatarStateProvider = NotifierProvider<AvatarController, AvatarState>(AvatarController.new);

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/chat.dart';
import '../../widgets/avatar_marlix.dart';
import 'chat_controller.dart';

/// Folder of the layers of the avatar to show. Always marlix for now; S5-7
/// overrides it with the one the backend says is the user's.
final avatarFolderProvider = Provider<String>((ref) => 'assets/avatars/marlix');

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

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/chat.dart';
import '../../models/usage.dart';
import '../../services/marlix_api.dart';

class ChatState {
  const ChatState({this.messages = const [], this.sending = false, this.usage});

  /// Oldest first. Only this session's messages until the history exists (S4-4).
  final List<ChatMessage> messages;

  /// marlix is replying; the screen shows the typing indicator.
  final bool sending;

  /// Unknown until `GET /v1/usage` or the first reply answers.
  final Usage? usage;

  ChatState copyWith({List<ChatMessage>? messages, bool? sending, Usage? usage}) => ChatState(
    messages: messages ?? this.messages,
    sending: sending ?? this.sending,
    usage: usage ?? this.usage,
  );
}

class ChatController extends Notifier<ChatState> {
  var _localIds = 0;

  @override
  ChatState build() => const ChatState();

  MarlixApi get _api => ref.read(marlixApiProvider);

  /// Best effort: the remaining messages chip stays hidden if it fails.
  Future<void> loadUsage() async {
    try {
      final usage = await _api.usage();
      if (ref.mounted) state = state.copyWith(usage: usage);
    } on Exception {
      // The next reply carries the usage too.
    }
  }

  /// Shows the message right away and adds marlix's reply when it arrives.
  /// On failure the message is taken back and the error is rethrown, so the
  /// screen can put the text back in the field.
  Future<void> send(String text) async {
    final message = text.trim();
    if (message.isEmpty || state.sending) return;

    final pending = ChatMessage(
      id: 'local-${_localIds++}',
      role: MessageRole.user,
      content: message,
      createdAt: DateTime.now().toUtc(),
    );
    state = state.copyWith(messages: [...state.messages, pending], sending: true);

    try {
      final response = await _api.sendMessage(message);
      if (!ref.mounted) return;
      state = ChatState(
        messages: [
          for (final existing in state.messages)
            if (existing.id != pending.id) existing,
          response.userMessage,
          response.reply,
        ],
        usage: response.usage,
      );
    } catch (_) {
      if (ref.mounted) {
        state = state.copyWith(
          messages: [
            for (final existing in state.messages)
              if (existing.id != pending.id) existing,
          ],
          sending: false,
        );
      }
      rethrow;
    }
  }
}

final chatControllerProvider = NotifierProvider<ChatController, ChatState>(ChatController.new);

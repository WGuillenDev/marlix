import 'chat.dart';
import 'json_reader.dart';

/// Response of `GET /v1/history`.
class HistoryPage {
  const HistoryPage({required this.messages, required this.nextCursor});

  factory HistoryPage.fromJson(Map<String, Object?> json) => HistoryPage(
    messages: json.requireList('messages', ChatMessage.fromJson),
    nextCursor: json.optionalString('nextCursor'),
  );

  /// Oldest first, ready to render.
  final List<ChatMessage> messages;

  /// Opaque: sent back as `before` to load the older page. Null at the end.
  final String? nextCursor;
}

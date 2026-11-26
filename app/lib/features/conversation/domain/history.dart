import '../../../shared/json_reader.dart';
import 'chat.dart';

class HistoryPage {
  const HistoryPage({required this.messages, required this.nextCursor});

  factory HistoryPage.fromJson(Map<String, Object?> json) => HistoryPage(
    messages: json.requireList('messages', ChatMessage.fromJson),
    nextCursor: json.optionalString('nextCursor'),
  );

  final List<ChatMessage> messages;

  /// Opaque cursor for the next page of older messages.
  final String? nextCursor;
}

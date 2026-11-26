import '../domain/chat.dart';
import '../domain/history.dart';
import '../domain/usage.dart';

abstract interface class ConversationGateway {
  Future<ChatResponse> sendMessage(String message, {ChatMode mode = ChatMode.text});
  Future<ChatResponse> sendVoiceMessage(
    String message, {
    required void Function(String sentence) onSentence,
  });
  Future<HistoryPage> history({String? before, int limit = 50});
  Future<Usage> usage();
}

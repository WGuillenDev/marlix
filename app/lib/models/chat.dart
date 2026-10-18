import 'help_resource.dart';
import 'json_reader.dart';
import 'usage.dart';

enum ChatMode { text, voice }

enum MessageRole { user, assistant }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.interrupted = false,
  });

  factory ChatMessage.fromJson(Map<String, Object?> json) {
    final role = json.requireString('role');
    return ChatMessage(
      id: json.requireString('id'),
      role: MessageRole.values.firstWhere(
        (value) => value.name == role,
        orElse: () => throw InvalidJsonException('Unknown message role: $role'),
      ),
      content: json.requireString('content'),
      createdAt: json.requireDateTime('createdAt'),
      interrupted: json.optionalBool('interrupted') ?? false,
    );
  }

  final String id;
  final MessageRole role;
  final String content;
  final DateTime createdAt;
  final bool interrupted;
}

/// Response of `POST /v1/chat`. A crisis is a reply, not an error: the app
/// must show it right away and never offer a retry.
sealed class ChatResponse {
  const ChatResponse({required this.userMessage, required this.reply, this.usage});

  factory ChatResponse.fromJson(Map<String, Object?> json) {
    final userMessage = ChatMessage.fromJson(json.requireObject('userMessage'));
    final reply = ChatMessage.fromJson(json.requireObject('reply'));
    final usageJson = json['usage'];
    final usage = usageJson == null ? null : Usage.fromJson(json.requireObject('usage'));
    return switch (json.requireString('type')) {
      'reply' => ChatReply(userMessage: userMessage, reply: reply, usage: usage),
      'crisis' => CrisisReply(
        userMessage: userMessage,
        reply: reply,
        usage: usage,
        resources: json.requireList('resources', HelpResource.fromJson),
      ),
      final type => throw InvalidJsonException('Unknown chat response type: $type'),
    };
  }

  final ChatMessage userMessage;
  final ChatMessage reply;

  /// Missing when the backend could not read the count; the app keeps the last one.
  final Usage? usage;
}

class ChatReply extends ChatResponse {
  const ChatReply({required super.userMessage, required super.reply, super.usage});
}

/// The crisis filter detected risk: [reply] is the fixed crisis text and
/// [resources] are the help lines to dial, the primary one first.
class CrisisReply extends ChatResponse {
  const CrisisReply({
    required super.userMessage,
    required super.reply,
    super.usage,
    required this.resources,
  });

  final List<HelpResource> resources;
}

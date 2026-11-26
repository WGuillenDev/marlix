import '../../../shared/json_reader.dart';
import '../../safety/domain/help_resource.dart';
import 'usage.dart';

enum ChatMode { text, voice }

enum MessageRole { user, assistant }

enum MessageTone { positive, neutral }

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

/// A crisis result is a normal response so the app can show help immediately.
sealed class ChatResponse {
  const ChatResponse({
    required this.userMessage,
    required this.reply,
    this.tone = MessageTone.neutral,
    this.usage,
  });

  factory ChatResponse.fromJson(Map<String, Object?> json) {
    final userMessage = ChatMessage.fromJson(json.requireObject('userMessage'));
    final reply = ChatMessage.fromJson(json.requireObject('reply'));
    final usageJson = json['usage'];
    final usage = usageJson == null ? null : Usage.fromJson(json.requireObject('usage'));
    // Older backends may omit the tone. Only an explicit positive tone animates joy.
    final tone = json.optionalString('tone') == 'positive'
        ? MessageTone.positive
        : MessageTone.neutral;
    return switch (json.requireString('type')) {
      'reply' => ChatReply(userMessage: userMessage, reply: reply, tone: tone, usage: usage),
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

  final MessageTone tone;

  /// Null keeps the last known usage when the backend cannot read the counter.
  final Usage? usage;
}

class ChatReply extends ChatResponse {
  const ChatReply({required super.userMessage, required super.reply, super.tone, super.usage});
}

class CrisisReply extends ChatResponse {
  const CrisisReply({
    required super.userMessage,
    required super.reply,
    super.usage,
    required this.resources,
  });

  final List<HelpResource> resources;
}

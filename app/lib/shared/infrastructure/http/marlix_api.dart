import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../features/account/application/account_gateway.dart';
import '../../../features/account/domain/profile.dart';
import '../../../features/conversation/application/conversation_gateway.dart';
import '../../../features/conversation/domain/chat.dart';
import '../../../features/conversation/domain/history.dart';
import '../../../features/conversation/domain/usage.dart';
import '../../../features/conversation/infrastructure/chat_event_stream.dart';
import '../../../features/memory/application/memory_gateway.dart';
import '../../../features/memory/domain/memory.dart';
import '../../../features/safety/application/safety_gateway.dart';
import '../../../features/safety/domain/help_resource.dart';
import '../../../features/voice/application/voice_gateway.dart';
import '../../application/api_exception.dart';
import '../../json_reader.dart';
import 'http_transport.dart';

class MarlixApi
    implements
        ConversationGateway,
        AccountGateway,
        MemoryGateway,
        HelpResourcesGateway,
        TranscriptionGateway {
  MarlixApi({
    required http.Client client,
    required Uri baseUrl,
    String? Function()? accessToken,
    Duration timeout = defaultTimeout,
  }) : _transport = HttpTransport(
         client: client,
         baseUrl: baseUrl,
         accessToken: accessToken,
         timeout: timeout,
       );

  static const defaultTimeout = HttpTransport.defaultTimeout;

  final HttpTransport _transport;

  Future<bool> health() =>
      _transport.send('GET', '/health', parse: (json) => json.requireString('status') == 'ok');

  /// Available before sign-in so the help screen can load without a session.
  @override
  Future<HelpResources> helpResources() =>
      _transport.send('GET', '/v1/help-resources', parse: HelpResources.fromJson);

  @override
  Future<ChatResponse> sendMessage(String message, {ChatMode mode = ChatMode.text}) =>
      _transport.send(
        'POST',
        '/v1/chat',
        body: {'message': message, 'mode': mode.name},
        authenticated: true,
        parse: ChatResponse.fromJson,
      );

  /// Delivers each reviewed sentence as it arrives, followed by the final reply.
  @override
  Future<ChatResponse> sendVoiceMessage(
    String message, {
    required void Function(String sentence) onSentence,
  }) async {
    const label = 'POST /v1/chat';
    final streamed = await _transport.open(
      'POST',
      '/v1/chat',
      body: {'message': message, 'mode': ChatMode.voice.name},
      authenticated: true,
      accept: 'text/event-stream',
    );
    if (!(streamed.headers['content-type'] ?? '').startsWith('text/event-stream')) {
      return _transport.finish(streamed, label, ChatResponse.fromJson);
    }

    return readChatEventStream(
      streamed.stream,
      label: label,
      timeout: _transport.timeout,
      onSentence: onSentence,
    );
  }

  /// Sends WAV audio as 16 kHz mono PCM.
  @override
  Future<String> transcribe(Uint8List wav) => _transport.send(
    'POST',
    '/v1/transcribe',
    bytes: wav,
    contentType: 'audio/wav',
    authenticated: true,
    parse: (json) => json.requireString('text'),
  );

  /// `GET /v1/history`: the newest page, or the one before [before], a cursor
  /// from the previous page.
  @override
  Future<HistoryPage> history({String? before, int limit = 50}) => _transport.send(
    'GET',
    '/v1/history',
    query: {'limit': '$limit', 'before': ?before},
    authenticated: true,
    parse: HistoryPage.fromJson,
  );

  @override
  Future<Usage> usage() =>
      _transport.send('GET', '/v1/usage', authenticated: true, parse: Usage.fromJson);

  @override
  Future<List<Memory>> memories() => _transport.send(
    'GET',
    '/v1/memories',
    authenticated: true,
    parse: (json) => json.requireList('memories', Memory.fromJson),
  );

  @override
  Future<Memory> editMemory(String id, String fact) => _transport.send(
    'PATCH',
    '/v1/memories/$id',
    body: {'fact': fact},
    authenticated: true,
    parse: Memory.fromJson,
  );

  @override
  Future<void> deleteMemory(String id) =>
      _transport.send('DELETE', '/v1/memories/$id', authenticated: true, parse: null);

  @override
  Future<void> deleteAllMemories() =>
      _transport.send('DELETE', '/v1/memories', authenticated: true, parse: null);

  @override
  Future<Profile> me() =>
      _transport.send('GET', '/v1/me', authenticated: true, parse: Profile.fromJson);

  /// `POST /v1/onboarding`: records the explicit consent and the answer to the
  /// reminders offer, and marks onboarding as done. Throws
  /// [OnboardingAlreadyCompletedException] if it was already done.
  @override
  Future<Profile> completeOnboarding({required bool remindersEnabled}) => _transport.send(
    'POST',
    '/v1/onboarding',
    body: {'dataConsent': true, 'remindersEnabled': remindersEnabled},
    authenticated: true,
    parse: Profile.fromJson,
  );

  @override
  Future<void> deleteAccount() =>
      _transport.send('DELETE', '/v1/account', authenticated: true, parse: null);
}

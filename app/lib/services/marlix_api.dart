import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/chat.dart';
import '../models/help_resource.dart';
import '../models/history.dart';
import '../models/json_reader.dart';
import '../models/memory.dart';
import '../models/profile.dart';
import '../models/usage.dart';
import 'api_exception.dart';
import 'auth_service.dart';

/// The only way the app talks to the backend (docs/api-contract.md). It never
/// talks to the LLM provider and holds no API key.
class MarlixApi {
  MarlixApi({
    required this._client,
    required this._baseUrl,
    this._accessToken,
    this.timeout = defaultTimeout,
  });

  /// The free Render plan takes up to a minute to wake up, and a chat reply
  /// can take the LLM timeout plus one retry on top of that.
  static const defaultTimeout = Duration(seconds: 75);

  final http.Client _client;
  final Uri _baseUrl;

  /// Read on every request: Supabase refreshes the session token in the
  /// background, so it can change between two messages.
  final String? Function()? _accessToken;
  final Duration timeout;

  /// `GET /health`. Public.
  Future<bool> health() =>
      _send('GET', '/health', parse: (json) => json.requireString('status') == 'ok');

  /// `GET /v1/help-resources`. Public, so the help screen works without a session.
  Future<HelpResources> helpResources() =>
      _send('GET', '/v1/help-resources', parse: HelpResources.fromJson);

  /// `POST /v1/chat`. Returns a [CrisisReply] when the crisis filter detects risk.
  Future<ChatResponse> sendMessage(String message, {ChatMode mode = ChatMode.text}) => _send(
    'POST',
    '/v1/chat',
    body: {'message': message, 'mode': mode.name},
    authenticated: true,
    parse: ChatResponse.fromJson,
  );

  /// `POST /v1/chat` in voice mode as a stream (S6-10): [onSentence] gets each
  /// sentence of the reply as soon as the backend has reviewed it, and the
  /// result is the complete reply, like [sendMessage]'s. A backend that answers
  /// with plain JSON works too; it just never calls [onSentence].
  Future<ChatResponse> sendVoiceMessage(
    String message, {
    required void Function(String sentence) onSentence,
  }) async {
    const label = 'POST /v1/chat';
    final streamed = await _open(
      'POST',
      '/v1/chat',
      body: {'message': message, 'mode': ChatMode.voice.name},
      authenticated: true,
      accept: 'text/event-stream',
    );
    if (!(streamed.headers['content-type'] ?? '').startsWith('text/event-stream')) {
      return _finish(streamed, label, ChatResponse.fromJson);
    }

    final result = Completer<ChatResponse>();
    void fail(Object error) {
      if (!result.isCompleted) result.completeError(error);
    }

    var eventName = 'message';
    final eventData = <String>[];
    void handle(String name, String raw) {
      try {
        final data = _decodeEvent(raw, label);
        switch (name) {
          case 'sentence':
            onSentence(data.requireString('text'));
          case 'done' || 'crisis':
            if (!result.isCompleted) result.complete(ChatResponse.fromJson(data));
          case 'error':
            fail(_toError(data, statusCode: 503));
        }
      } on InvalidJsonException catch (error) {
        fail(InvalidResponseException('$label: $error'));
      } on ApiException catch (error) {
        fail(error);
      }
    }

    // A silence longer than [timeout] between two pieces fails it, so a lost
    // connection does not wait for ever.
    final subscription = streamed.stream
        .timeout(timeout, onTimeout: (sink) => sink.addError(TimeoutException('quiet')))
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) {
            if (line.isEmpty) {
              if (eventData.isNotEmpty) handle(eventName, eventData.join('\n'));
              eventName = 'message';
              eventData.clear();
            } else if (line.startsWith('event:')) {
              eventName = line.substring(6).trim();
            } else if (line.startsWith('data:')) {
              eventData.add(line.substring(5).trimLeft());
            }
          },
          onError: (Object error) => fail(switch (error) {
            TimeoutException() => ApiTimeoutException(
              '$label went quiet for more than ${timeout.inSeconds} s',
            ),
            SocketException(:final message) => NetworkException('$label: $message'),
            http.ClientException(:final message) => NetworkException('$label: $message'),
            _ => error,
          }),
          onDone: () =>
              fail(NetworkException('$label: the stream ended before the reply was complete')),
          cancelOnError: true,
        );
    try {
      return await result.future;
    } finally {
      // Not awaited: cancelling the subscription of a stream that already ended
      // may never answer.
      unawaited(subscription.cancel());
    }
  }

  Map<String, Object?> _decodeEvent(String data, String request) {
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, Object?>) return decoded;
    } on FormatException {
      // Falls through to the error below.
    }
    throw InvalidResponseException('$request sent an event that is not a JSON object');
  }

  /// `POST /v1/transcribe` (S6-9): the text of what the person said. [wav] is
  /// 16 kHz mono 16-bit PCM in a WAV file. Empty when nothing was understood.
  Future<String> transcribe(Uint8List wav) => _send(
    'POST',
    '/v1/transcribe',
    bytes: wav,
    contentType: 'audio/wav',
    authenticated: true,
    parse: (json) => json.requireString('text'),
  );

  /// `GET /v1/history`: the newest page, or the one before [before], a cursor
  /// from the previous page.
  Future<HistoryPage> history({String? before, int limit = 50}) => _send(
    'GET',
    '/v1/history',
    query: {'limit': '$limit', 'before': ?before},
    authenticated: true,
    parse: HistoryPage.fromJson,
  );

  /// `GET /v1/usage`.
  Future<Usage> usage() => _send('GET', '/v1/usage', authenticated: true, parse: Usage.fromJson);

  /// `GET /v1/memories`, newest first.
  Future<List<Memory>> memories() => _send(
    'GET',
    '/v1/memories',
    authenticated: true,
    parse: (json) => json.requireList('memories', Memory.fromJson),
  );

  /// `PATCH /v1/memories/:id`: rewrites the text; the backend keeps the rest.
  Future<Memory> editMemory(String id, String fact) => _send(
    'PATCH',
    '/v1/memories/$id',
    body: {'fact': fact},
    authenticated: true,
    parse: Memory.fromJson,
  );

  /// `DELETE /v1/memories/:id`.
  Future<void> deleteMemory(String id) =>
      _send('DELETE', '/v1/memories/$id', authenticated: true, parse: null);

  /// `DELETE /v1/memories`: everything marlix remembers.
  Future<void> deleteAllMemories() =>
      _send('DELETE', '/v1/memories', authenticated: true, parse: null);

  /// `GET /v1/me`: the profile, which says whether onboarding must be shown.
  Future<Profile> me() => _send('GET', '/v1/me', authenticated: true, parse: Profile.fromJson);

  /// `POST /v1/onboarding`: records the explicit consent and the answer to the
  /// reminders offer, and marks onboarding as done. Throws
  /// [OnboardingAlreadyCompletedException] if it was already done.
  Future<Profile> completeOnboarding({required bool remindersEnabled}) => _send(
    'POST',
    '/v1/onboarding',
    body: {'dataConsent': true, 'remindersEnabled': remindersEnabled},
    authenticated: true,
    parse: Profile.fromJson,
  );

  /// `DELETE /v1/account`: the account and all its data. Throws
  /// [ReauthenticationRequiredException] if the last sign-in is too old.
  Future<void> deleteAccount() => _send('DELETE', '/v1/account', authenticated: true, parse: null);

  /// With a null [parse] the answer is `204 No Content` and has no body.
  Future<T> _send<T>(
    String method,
    String path, {
    required T Function(Map<String, Object?> json)? parse,
    Map<String, Object?>? body,
    Uint8List? bytes,
    String? contentType,
    Map<String, String>? query,
    bool authenticated = false,
  }) async => _finish(
    await _open(
      method,
      path,
      body: body,
      bytes: bytes,
      contentType: contentType,
      query: query,
      authenticated: authenticated,
    ),
    '$method $path',
    parse,
  );

  /// Sends the request and returns the answer as soon as its headers arrive.
  Future<http.StreamedResponse> _open(
    String method,
    String path, {
    Map<String, Object?>? body,
    Uint8List? bytes,
    String? contentType,
    Map<String, String>? query,
    bool authenticated = false,
    String accept = 'application/json',
  }) async {
    final request = http.Request(method, _baseUrl.resolve(path).replace(queryParameters: query))
      ..headers['Accept'] = accept;
    if (authenticated) {
      if (_accessToken?.call() case final token?) {
        request.headers['Authorization'] = 'Bearer $token';
      }
    }
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    } else if (bytes != null) {
      request.headers['Content-Type'] = contentType ?? 'application/octet-stream';
      request.bodyBytes = bytes;
    }

    try {
      return await _client.send(request).timeout(timeout);
    } on TimeoutException {
      throw ApiTimeoutException('$method $path took more than ${timeout.inSeconds} s');
    } on SocketException catch (error) {
      throw NetworkException('$method $path: ${error.message}');
    } on http.ClientException catch (error) {
      throw NetworkException('$method $path: ${error.message}');
    }
  }

  /// Reads a whole answer and turns it into the result, or the error it carries.
  Future<T> _finish<T>(
    http.StreamedResponse streamed,
    String label,
    T Function(Map<String, Object?> json)? parse,
  ) async {
    final http.Response response;
    try {
      response = await http.Response.fromStream(streamed);
    } on SocketException catch (error) {
      throw NetworkException('$label: ${error.message}');
    } on http.ClientException catch (error) {
      throw NetworkException('$label: ${error.message}');
    }

    final failed = response.statusCode < 200 || response.statusCode >= 300;
    if (parse == null && !failed) return null as T;
    final json = _decode(response, label);
    if (failed) {
      throw _toError(json, statusCode: response.statusCode, retryAfter: _retryAfter(response));
    }
    try {
      return parse!(json);
    } on InvalidJsonException catch (error) {
      throw InvalidResponseException('$label: $error');
    }
  }

  Map<String, Object?> _decode(http.Response response, String request) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, Object?>) return decoded;
    } on FormatException {
      // Falls through: a proxy or the host can answer with HTML.
    }
    throw InvalidResponseException(
      '$request answered ${response.statusCode} without a JSON object',
    );
  }

  ApiErrorException _toError(
    Map<String, Object?> json, {
    required int statusCode,
    Duration? retryAfter,
  }) {
    try {
      final error = json.requireObject('error');
      final code = error.requireString('code');
      final message = error.requireString('message');
      final details = error['details'] is Map<String, Object?>
          ? error['details']! as Map<String, Object?>
          : const <String, Object?>{};
      return switch (code) {
        'VALIDATION_ERROR' => ValidationException(message: message, fields: _fields(details)),
        'UNAUTHORIZED' => UnauthorizedException(message: message),
        'REAUTHENTICATION_REQUIRED' => ReauthenticationRequiredException(message: message),
        'NOT_FOUND' => NotFoundException(message: message),
        'ONBOARDING_ALREADY_COMPLETED' => OnboardingAlreadyCompletedException(message: message),
        'DAILY_LIMIT_REACHED' => DailyLimitReachedException(
          message: message,
          resetsAt: details.requireDateTime('resetsAt'),
        ),
        'RATE_LIMITED' => RateLimitedException(
          message: message,
          retryAfter: retryAfter ?? const Duration(seconds: 60),
        ),
        'LLM_UNAVAILABLE' => LlmUnavailableException(message: message, retryAfter: retryAfter),
        _ => UnexpectedApiException(statusCode: statusCode, code: code, message: message),
      };
    } on InvalidJsonException catch (error) {
      throw InvalidResponseException('Error $statusCode with an invalid body: $error');
    }
  }

  static Duration? _retryAfter(http.Response response) {
    final seconds = int.tryParse(response.headers['retry-after'] ?? '');
    return seconds == null ? null : Duration(seconds: seconds);
  }

  static Map<String, String> _fields(Map<String, Object?> details) {
    final fields = details['fields'];
    if (fields is! List<Object?>) return const {};
    return {
      for (final field in fields.whereType<Map<String, Object?>>())
        if (field['field'] case final String name) name: field['message'] as String? ?? '',
    };
  }
}

/// Overridable in tests; the HTTP client is closed with the provider.
final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final marlixApiProvider = Provider<MarlixApi>((ref) {
  final config = ref.watch(appConfigProvider);
  final auth = ref.watch(authServiceProvider);
  return MarlixApi(
    client: ref.watch(httpClientProvider),
    baseUrl: config.apiBaseUrl,
    accessToken: () => auth.accessToken,
  );
});

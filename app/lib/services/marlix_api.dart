import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/chat.dart';
import '../models/help_resource.dart';
import '../models/history.dart';
import '../models/json_reader.dart';
import '../models/memory.dart';
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

  /// With a null [parse] the answer is `204 No Content` and has no body.
  Future<T> _send<T>(
    String method,
    String path, {
    required T Function(Map<String, Object?> json)? parse,
    Map<String, Object?>? body,
    Map<String, String>? query,
    bool authenticated = false,
  }) async {
    final request = http.Request(method, _baseUrl.resolve(path).replace(queryParameters: query))
      ..headers['Accept'] = 'application/json';
    if (authenticated) {
      if (_accessToken?.call() case final token?) {
        request.headers['Authorization'] = 'Bearer $token';
      }
    }
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    final http.Response response;
    try {
      response = await http.Response.fromStream(await _client.send(request).timeout(timeout));
    } on TimeoutException {
      throw ApiTimeoutException('$method $path took more than ${timeout.inSeconds} s');
    } on SocketException catch (error) {
      throw NetworkException('$method $path: ${error.message}');
    } on http.ClientException catch (error) {
      throw NetworkException('$method $path: ${error.message}');
    }

    final failed = response.statusCode < 200 || response.statusCode >= 300;
    if (parse == null && !failed) return null as T;
    final json = _decode(response, '$method $path');
    if (failed) throw _toError(response, json);
    try {
      return parse!(json);
    } on InvalidJsonException catch (error) {
      throw InvalidResponseException('$method $path: $error');
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

  ApiErrorException _toError(http.Response response, Map<String, Object?> json) {
    try {
      final error = json.requireObject('error');
      final code = error.requireString('code');
      final message = error.requireString('message');
      final details = error['details'] is Map<String, Object?>
          ? error['details']! as Map<String, Object?>
          : const <String, Object?>{};
      final retryAfter = _retryAfter(response);

      return switch (code) {
        'VALIDATION_ERROR' => ValidationException(message: message, fields: _fields(details)),
        'UNAUTHORIZED' => UnauthorizedException(message: message),
        'NOT_FOUND' => NotFoundException(message: message),
        'DAILY_LIMIT_REACHED' => DailyLimitReachedException(
          message: message,
          resetsAt: details.requireDateTime('resetsAt'),
        ),
        'RATE_LIMITED' => RateLimitedException(
          message: message,
          retryAfter: retryAfter ?? const Duration(seconds: 60),
        ),
        'LLM_UNAVAILABLE' => LlmUnavailableException(message: message, retryAfter: retryAfter),
        _ => UnexpectedApiException(statusCode: response.statusCode, code: code, message: message),
      };
    } on InvalidJsonException catch (error) {
      throw InvalidResponseException('Error ${response.statusCode} with an invalid body: $error');
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

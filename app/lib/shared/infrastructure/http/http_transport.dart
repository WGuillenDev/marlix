import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../application/api_exception.dart';
import '../../json_reader.dart';
import 'api_error_decoder.dart';

class HttpTransport {
  HttpTransport({
    required this._client,
    required this._baseUrl,
    this._accessToken,
    this.timeout = defaultTimeout,
  });

  // Allow for both a cold backend and the model retry window.
  static const defaultTimeout = Duration(seconds: 75);

  final http.Client _client;
  final Uri _baseUrl;

  /// Read a fresh token per request because Supabase refreshes sessions asynchronously.
  final String? Function()? _accessToken;
  final Duration timeout;

  /// With a null [parse] the answer is `204 No Content` and has no body.
  Future<T> send<T>(
    String method,
    String path, {
    required T Function(Map<String, Object?> json)? parse,
    Map<String, Object?>? body,
    Uint8List? bytes,
    String? contentType,
    Map<String, String>? query,
    bool authenticated = false,
  }) async => finish(
    await open(
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

  Future<http.StreamedResponse> open(
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

  Future<T> finish<T>(
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
      throw decodeApiError(
        json,
        statusCode: response.statusCode,
        retryAfter: _retryAfter(response),
      );
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
      // A proxy can respond with HTML instead of the API error body.
    }
    throw InvalidResponseException(
      '$request answered ${response.statusCode} without a JSON object',
    );
  }

  static Duration? _retryAfter(http.Response response) {
    final seconds = int.tryParse(response.headers['retry-after'] ?? '');
    return seconds == null ? null : Duration(seconds: seconds);
  }
}

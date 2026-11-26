import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../shared/application/api_exception.dart';
import '../../../shared/infrastructure/http/api_error_decoder.dart';
import '../../../shared/json_reader.dart';
import '../domain/chat.dart';

Future<ChatResponse> readChatEventStream(
  Stream<List<int>> bytes, {
  required String label,
  required Duration timeout,
  required void Function(String sentence) onSentence,
}) async {
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
          fail(decodeApiError(data, statusCode: 503));
      }
    } on InvalidJsonException catch (error) {
      fail(InvalidResponseException('$label: $error'));
    } on ApiException catch (error) {
      fail(error);
    }
  }

  /// Fail on prolonged stream inactivity, even after the headers arrive.
  final subscription = bytes
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
    // A closed source can leave cancellation pending.
    unawaited(subscription.cancel());
  }
}

Map<String, Object?> _decodeEvent(String data, String request) {
  try {
    final decoded = jsonDecode(data);
    if (decoded is Map<String, Object?>) return decoded;
  } on FormatException {
    // Report malformed JSON and non-object payloads as the same API error.
  }
  throw InvalidResponseException('$request sent an event that is not a JSON object');
}

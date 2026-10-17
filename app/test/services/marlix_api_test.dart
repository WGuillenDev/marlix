import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:marlix/models/chat.dart';
import 'package:marlix/services/api_exception.dart';
import 'package:marlix/services/marlix_api.dart';

const token = 'session-access-token';
final baseUrl = Uri.parse('https://api.test');

const resource = {
  'id': '911',
  'name': '9-1-1, Despacho de Apoyo Psicológico',
  'phone': '911',
  'hours': '24/7, gratuito',
  'primary': true,
};
const usage = {'used': 13, 'limit': 100, 'remaining': 87, 'resetsAt': '2026-10-16T06:00:00Z'};

Map<String, Object?> message(String role, String content) => {
  'id': 'c2a7e9b0-4f3d-4a1e-9b8c-7d6e5f4a3b21',
  'role': role,
  'content': content,
  'createdAt': '2026-10-15T18:00:00Z',
  if (role == 'assistant') 'interrupted': false,
};

http.Response jsonResponse(Object body, int status, {Map<String, String> headers = const {}}) =>
    http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8', ...headers},
    );

http.Response errorResponse(
  int status,
  String code, {
  Map<String, Object?>? details,
  Map<String, String> headers = const {},
}) => jsonResponse(
  {
    'error': {'code': code, 'message': 'Developer message.', 'details': ?details},
  },
  status,
  headers: headers,
);

MarlixApi apiReturning(
  FutureOr<http.Response> Function(http.Request request) handler, {
  String? accessToken = token,
  Duration timeout = MarlixApi.defaultTimeout,
}) => MarlixApi(
  client: MockClient((request) async => handler(request)),
  baseUrl: baseUrl,
  accessToken: () => accessToken,
  timeout: timeout,
);

void main() {
  group('endpoints', () {
    test('GET /health is public', () async {
      late http.Request sent;
      final api = apiReturning((request) {
        sent = request;
        return jsonResponse({'status': 'ok'}, 200);
      });

      expect(await api.health(), isTrue);
      expect(sent.method, 'GET');
      expect(sent.url, Uri.parse('https://api.test/health'));
      expect(sent.headers.containsKey('Authorization'), isFalse);
    });

    test('GET /v1/help-resources is public and parses the resources', () async {
      late http.Request sent;
      final api = apiReturning((request) {
        sent = request;
        return jsonResponse({
          'updatedAt': '2026-10-14T00:00:00Z',
          'resources': [resource],
        }, 200);
      });

      final help = await api.helpResources();

      expect(sent.url.path, '/v1/help-resources');
      expect(sent.headers.containsKey('Authorization'), isFalse);
      expect(help.updatedAt, DateTime.utc(2026, 10, 14));
      expect(help.resources.single.phone, '911');
      expect(help.resources.single.primary, isTrue);
    });

    test('POST /v1/chat sends the message with the token and parses a reply', () async {
      late http.Request sent;
      final api = apiReturning((request) {
        sent = request;
        return jsonResponse({
          'type': 'reply',
          'userMessage': message('user', 'Hoy me fue mejor'),
          'reply': message('assistant', '¡Qué dicha!'),
          'usage': usage,
        }, 200);
      });

      final response = await api.sendMessage('Hoy me fue mejor');

      expect(sent.method, 'POST');
      expect(sent.url.path, '/v1/chat');
      expect(sent.headers['Authorization'], 'Bearer $token');
      expect(sent.headers['Content-Type'], startsWith('application/json'));
      expect(jsonDecode(sent.body), {'message': 'Hoy me fue mejor', 'mode': 'text'});
      expect(response, isA<ChatReply>());
      expect(response.reply.content, '¡Qué dicha!');
      expect(response.reply.role, MessageRole.assistant);
      expect(response.usage.remaining, 87);
    });

    test('POST /v1/chat recognizes a crisis reply with its resources', () async {
      final api = apiReturning(
        (_) => jsonResponse({
          'type': 'crisis',
          'userMessage': message('user', '…'),
          'reply': message('assistant', 'Por favor llamá al 9-1-1 ahora.'),
          'resources': [resource],
          'usage': usage,
        }, 200),
      );

      final response = await api.sendMessage('…', mode: ChatMode.voice);

      expect(response, isA<CrisisReply>());
      expect((response as CrisisReply).resources.single.id, '911');
    });

    test('GET /v1/usage sends the token', () async {
      late http.Request sent;
      final api = apiReturning((request) {
        sent = request;
        return jsonResponse({'plan': 'personal', ...usage}, 200);
      });

      final result = await api.usage();

      expect(sent.headers['Authorization'], 'Bearer $token');
      expect(result.plan, 'personal');
      expect(result.resetsAt, DateTime.utc(2026, 10, 16, 6));
    });

    test('GET /v1/history sends the token, the limit and the cursor, and parses a page', () async {
      late http.Request sent;
      final api = apiReturning((request) {
        sent = request;
        return jsonResponse({
          'messages': [message('user', 'Hola'), message('assistant', '¡Hola!')],
          'nextCursor': 'abc_-123',
        }, 200);
      });

      final page = await api.history(before: 'previous', limit: 20);

      expect(sent.method, 'GET');
      expect(sent.url.path, '/v1/history');
      expect(sent.url.queryParameters, {'limit': '20', 'before': 'previous'});
      expect(sent.headers['Authorization'], 'Bearer $token');
      expect(page.messages.map((m) => m.content), ['Hola', '¡Hola!']);
      expect(page.messages.last.role, MessageRole.assistant);
      expect(page.nextCursor, 'abc_-123');
    });

    test(
      'GET /v1/history leaves out the cursor of the first page and reads the last one',
      () async {
        late http.Request sent;
        final api = apiReturning((request) {
          sent = request;
          return jsonResponse({'messages': <Object?>[], 'nextCursor': null}, 200);
        });

        final page = await api.history();

        expect(sent.url.queryParameters, {'limit': '50'});
        expect(page.messages, isEmpty);
        expect(page.nextCursor, isNull);
      },
    );

    test('sends no Authorization header without a token', () async {
      late http.Request sent;
      final api = apiReturning((request) {
        sent = request;
        return jsonResponse({'plan': 'personal', ...usage}, 200);
      }, accessToken: null);

      await api.usage();

      expect(sent.headers.containsKey('Authorization'), isFalse);
    });

    test('reads the token on every request, so a refreshed one is used', () async {
      final sent = <String?>[];
      var current = 'first-token';
      final api = MarlixApi(
        client: MockClient((request) async {
          sent.add(request.headers['Authorization']);
          return jsonResponse({'plan': 'personal', ...usage}, 200);
        }),
        baseUrl: baseUrl,
        accessToken: () => current,
      );

      await api.usage();
      current = 'refreshed-token';
      await api.usage();

      expect(sent, ['Bearer first-token', 'Bearer refreshed-token']);
    });

    test('GET /v1/memories with the token, newest first as the backend sends them', () async {
      late http.Request sent;
      final api = apiReturning((request) {
        sent = request;
        return jsonResponse({
          'memories': [
            {
              'id': 'm2',
              'fact': 'Le gusta el café',
              'category': null,
              'createdAt': '2026-10-02T12:00:00Z',
              'updatedAt': '2026-10-02T12:00:00Z',
            },
            {
              'id': 'm1',
              'fact': 'Tiene un perro llamado Coco',
              'category': 'pets',
              'createdAt': '2026-10-01T12:00:00Z',
              'updatedAt': '2026-10-03T12:00:00Z',
            },
          ],
        }, 200);
      });

      final memories = await api.memories();

      expect(sent.method, 'GET');
      expect(sent.url.path, '/v1/memories');
      expect(sent.headers['Authorization'], 'Bearer $token');
      expect(memories.map((m) => m.id), ['m2', 'm1']);
      expect(memories.first.category, isNull);
      expect(memories.last.category, 'pets');
      expect(memories.last.updatedAt, DateTime.utc(2026, 10, 3, 12));
    });

    test('PATCH /v1/memories/:id sends only the text and returns the saved memory', () async {
      late http.Request sent;
      final api = apiReturning((request) {
        sent = request;
        return jsonResponse({
          'id': 'm1',
          'fact': 'Tiene una perrita llamada Coco',
          'category': 'pets',
          'createdAt': '2026-10-01T12:00:00Z',
          'updatedAt': '2026-10-17T12:00:00Z',
        }, 200);
      });

      final memory = await api.editMemory('m1', 'Tiene una perrita llamada Coco');

      expect(sent.method, 'PATCH');
      expect(sent.url.path, '/v1/memories/m1');
      expect(jsonDecode(sent.body), {'fact': 'Tiene una perrita llamada Coco'});
      expect(memory.fact, 'Tiene una perrita llamada Coco');
    });

    test('DELETE one memory or all of them accepts 204 without a body', () async {
      final sent = <String>[];
      final api = apiReturning((request) {
        sent.add('${request.method} ${request.url.path} ${request.headers['Authorization']}');
        return http.Response('', 204);
      });

      await api.deleteMemory('m1');
      await api.deleteAllMemories();

      expect(sent, ['DELETE /v1/memories/m1 Bearer $token', 'DELETE /v1/memories Bearer $token']);
    });

    test('DELETE /v1/account with the token accepts 204', () async {
      late http.Request sent;
      final api = apiReturning((request) {
        sent = request;
        return http.Response('', 204);
      });

      await api.deleteAccount();

      expect(sent.method, 'DELETE');
      expect(sent.url.path, '/v1/account');
      expect(sent.headers['Authorization'], 'Bearer $token');
    });

    test('a failed DELETE still reads the error body', () async {
      final api = apiReturning((_) => errorResponse(500, 'INTERNAL_ERROR'));

      await expectLater(api.deleteAllMemories(), throwsA(isA<UnexpectedApiException>()));
    });
  });

  group('error codes', () {
    test('REAUTHENTICATION_REQUIRED is not an ended session', () async {
      final api = apiReturning((_) => errorResponse(401, 'REAUTHENTICATION_REQUIRED'));

      await expectLater(
        api.deleteAccount(),
        throwsA(
          allOf(
            isA<ReauthenticationRequiredException>().having((e) => e.statusCode, 'statusCode', 401),
            isNot(isA<UnauthorizedException>()),
          ),
        ),
      );
    });

    test('NOT_FOUND', () async {
      final api = apiReturning((_) => errorResponse(404, 'NOT_FOUND'));

      await expectLater(api.deleteMemory('m9'), throwsA(isA<NotFoundException>()));
    });

    test('DAILY_LIMIT_REACHED carries resetsAt', () async {
      final api = apiReturning(
        (_) => errorResponse(
          429,
          'DAILY_LIMIT_REACHED',
          details: {'resetsAt': '2026-10-16T06:00:00Z'},
          headers: {'retry-after': '3600'},
        ),
      );

      await expectLater(
        api.sendMessage('hola'),
        throwsA(
          isA<DailyLimitReachedException>()
              .having((e) => e.resetsAt, 'resetsAt', DateTime.utc(2026, 10, 16, 6))
              .having((e) => e.statusCode, 'statusCode', 429),
        ),
      );
    });

    test('RATE_LIMITED carries Retry-After', () async {
      final api = apiReturning(
        (_) => errorResponse(429, 'RATE_LIMITED', headers: {'retry-after': '42'}),
      );

      await expectLater(
        api.sendMessage('hola'),
        throwsA(
          isA<RateLimitedException>().having(
            (e) => e.retryAfter,
            'retryAfter',
            const Duration(seconds: 42),
          ),
        ),
      );
    });

    test('LLM_UNAVAILABLE carries Retry-After when Groq sends it', () async {
      final api = apiReturning(
        (_) => errorResponse(503, 'LLM_UNAVAILABLE', headers: {'retry-after': '7'}),
      );

      await expectLater(
        api.sendMessage('hola'),
        throwsA(
          isA<LlmUnavailableException>().having(
            (e) => e.retryAfter,
            'retryAfter',
            const Duration(seconds: 7),
          ),
        ),
      );
    });

    test('VALIDATION_ERROR lists the invalid fields', () async {
      final api = apiReturning(
        (_) => errorResponse(
          400,
          'VALIDATION_ERROR',
          details: {
            'fields': [
              {'field': 'message', 'message': 'Must be at most 2000 characters'},
            ],
          },
        ),
      );

      await expectLater(
        api.sendMessage('x' * 2001),
        throwsA(
          isA<ValidationException>().having((e) => e.fields, 'fields', {
            'message': 'Must be at most 2000 characters',
          }),
        ),
      );
    });

    test('UNAUTHORIZED', () async {
      final api = apiReturning((_) => errorResponse(401, 'UNAUTHORIZED'));

      await expectLater(api.usage(), throwsA(isA<UnauthorizedException>()));
    });

    test('an unknown code keeps its status and code', () async {
      final api = apiReturning((_) => errorResponse(500, 'INTERNAL_ERROR'));

      await expectLater(
        api.usage(),
        throwsA(
          isA<UnexpectedApiException>()
              .having((e) => e.statusCode, 'statusCode', 500)
              .having((e) => e.code, 'code', 'INTERNAL_ERROR'),
        ),
      );
    });
  });

  group('failures', () {
    test('no connection is a NetworkException', () async {
      final api = apiReturning((_) => throw const SocketException('Failed host lookup'));

      await expectLater(api.health(), throwsA(isA<NetworkException>()));
    });

    test('a dropped connection is a NetworkException', () async {
      final api = apiReturning((_) => throw http.ClientException('Connection closed'));

      await expectLater(api.health(), throwsA(isA<NetworkException>()));
    });

    test('a slow backend is an ApiTimeoutException', () async {
      final api = apiReturning(
        (_) => Completer<http.Response>().future,
        timeout: const Duration(milliseconds: 10),
      );

      await expectLater(api.health(), throwsA(isA<ApiTimeoutException>()));
    });

    test('a body that is not JSON is an InvalidResponseException', () async {
      final api = apiReturning((_) => http.Response('<html>Bad gateway</html>', 502));

      await expectLater(api.health(), throwsA(isA<InvalidResponseException>()));
    });

    test('a reply that breaks the contract is an InvalidResponseException', () async {
      final api = apiReturning(
        (_) => jsonResponse({'type': 'reply', 'reply': 'not an object'}, 200),
      );

      await expectLater(api.sendMessage('hola'), throwsA(isA<InvalidResponseException>()));
    });

    test('an error without the contract body is an InvalidResponseException', () async {
      final api = apiReturning((_) => jsonResponse({'message': 'Not found'}, 404));

      await expectLater(api.usage(), throwsA(isA<InvalidResponseException>()));
    });
  });
}

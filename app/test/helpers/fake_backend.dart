import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:marlix/app.dart';
import 'package:marlix/services/auth_service.dart';
import 'package:marlix/services/dialer.dart';
import 'package:marlix/services/help_resources.dart';
import 'package:marlix/services/marlix_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Relative to now, so the limit logic behaves the same on any date.
Map<String, Object?> usageJson({int remaining = 87}) => {
  'used': 100 - remaining,
  'limit': 100,
  'remaining': remaining,
  'resetsAt': DateTime.now().toUtc().add(const Duration(hours: 12)).toIso8601String(),
};

var _ids = 0;

Map<String, Object?> messageJson(String role, String content) => {
  'id': 'id-${_ids++}',
  'role': role,
  'content': content,
  'createdAt': '2026-10-15T18:00:00Z',
};

http.Response jsonResponse(
  Object body, [
  int status = 200,
  Map<String, String> headers = const {},
]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8', ...headers},
);

const crisisResources = [
  {
    'id': 'aqui-estoy',
    'name': 'Aquí Estoy, Colegio de Psicólogos',
    'phone': '8002737869',
    'hours': 'Horario limitado',
    'primary': false,
  },
  {
    'id': '911',
    'name': '9-1-1, Despacho de Apoyo Psicológico',
    'phone': '911',
    'hours': '24/7, gratuito',
    'primary': true,
  },
];

/// A backend whose chat replies wait for [reply] to complete, so the test
/// controls when, and how, marlix answers. Set a new [reply] before each send.
class FakeBackend {
  Completer<http.Response> reply = Completer();
  final sent = <String>[];
  int usageRemaining = 87;

  /// `GET /v1/help-resources` fails as if there were no connection.
  bool offline = false;

  /// Authorization headers of every request, in order.
  final authorizations = <String?>[];

  /// What `GET /v1/history` serves, newest page first. The cursor of a page is
  /// the index of the next one.
  List<List<Map<String, Object?>>> historyPages = [];

  /// `GET /v1/history` fails as if there were no connection.
  bool historyOffline = false;

  /// `GET /v1/history` answers when this completes; replace it to keep it pending.
  Completer<void> historyGate = Completer()..complete();

  /// The `before` of every `GET /v1/history`, in order (null for the first page).
  final historyRequests = <String?>[];

  MarlixApi api(FakeAuthService auth) => MarlixApi(
    accessToken: () => auth.accessToken,
    client: MockClient((request) async {
      authorizations.add(request.headers['Authorization']);
      if (request.url.path == '/v1/help-resources') {
        if (offline) throw http.ClientException('No connection');
        return jsonResponse({'updatedAt': '2026-10-14T00:00:00Z', 'resources': crisisResources});
      }
      if (request.url.path == '/v1/history') {
        await historyGate.future;
        if (historyOffline) throw http.ClientException('No connection');
        final before = request.url.queryParameters['before'];
        historyRequests.add(before);
        final index = int.parse(before ?? '0');
        return jsonResponse({
          'messages': index < historyPages.length ? historyPages[index] : [],
          'nextCursor': index + 1 < historyPages.length ? '${index + 1}' : null,
        });
      }
      if (request.url.path == '/v1/usage') {
        return jsonResponse({'plan': 'personal', ...usageJson(remaining: usageRemaining)});
      }
      sent.add((jsonDecode(request.body) as Map)['message'] as String);
      return reply.future;
    }),
    baseUrl: Uri.parse('https://api.test'),
  );

  void answer(String userText, String replyText, {int remaining = 86}) => reply.complete(
    jsonResponse({
      'type': 'reply',
      'userMessage': messageJson('user', userText),
      'reply': messageJson('assistant', replyText),
      'usage': usageJson(remaining: remaining),
    }),
  );

  void answerCrisis(String userText, String crisisText) => reply.complete(
    jsonResponse({
      'type': 'crisis',
      'userMessage': messageJson('user', userText),
      'reply': messageJson('assistant', crisisText),
      'resources': crisisResources,
      'usage': usageJson(),
    }),
  );

  void fail(
    int status,
    String code, {
    Map<String, Object?>? details,
    Map<String, String>? headers,
  }) => reply.complete(
    jsonResponse(
      {
        'error': {'code': code, 'message': 'Developer message.', 'details': ?details},
      },
      status,
      headers ?? const {},
    ),
  );

  void dropConnection() => reply.completeError(http.ClientException('Connection closed'));
}

/// Supabase Auth without the network: accounts live in memory.
class FakeAuthService implements AuthService {
  FakeAuthService({this.userId});

  /// email -> password of the accounts that exist.
  final accounts = <String, String>{'ana@example.com': 'contraseña-de-ana'};

  /// Every sign-up, with the birth date sent.
  final signUps = <({String email, DateTime birthDate})>[];

  /// When set, the next sign-in or sign-up fails with it.
  AuthFailure? nextFailure;

  /// Completes sign-in and sign-up; replace it to keep them pending.
  Completer<void> gate = Completer()..complete();

  final _changes = StreamController<String?>.broadcast();

  @override
  String? userId;

  @override
  String? get accessToken => userId == null ? null : 'token-of-$userId';

  @override
  Stream<String?> get userIdChanges => _changes.stream;

  void _setUser(String? id) {
    userId = id;
    _changes.add(id);
  }

  Future<void> _check() async {
    await gate.future;
    if (nextFailure case final failure?) {
      nextFailure = null;
      throw AuthFailureException(failure);
    }
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _check();
    if (accounts[email.trim()] != password) {
      throw const AuthFailureException(AuthFailure.invalidCredentials);
    }
    _setUser('user-${email.trim()}');
  }

  @override
  Future<void> signUp({
    required String email,
    required String password,
    required DateTime birthDate,
  }) async {
    await _check();
    if (accounts.containsKey(email.trim())) {
      throw const AuthFailureException(AuthFailure.emailTaken);
    }
    signUps.add((email: email.trim(), birthDate: birthDate));
    accounts[email.trim()] = password;
    _setUser('user-${email.trim()}');
  }

  @override
  Future<void> signOut() async => _setUser(null);
}

/// Records the numbers instead of opening the dialer.
class FakeDialer implements Dialer {
  final dialed = <String>[];

  /// False simulates a device without a dialer.
  bool available = true;

  @override
  Future<bool> dial(String phone) async {
    dialed.add(phone);
    return available;
  }
}

/// Opens the app signed in as Ana, on the chat. With [auth] signed out, it
/// opens on the sign-in screen.
Future<FakeBackend> openChat(
  WidgetTester tester, {
  Size size = const Size(360, 800),
  FakeBackend? backend,
  FakeAuthService? auth,
  FakeDialer? dialer,
  Map<String, Object> savedPreferences = const {},
}) async {
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  final fake = backend ?? FakeBackend();
  final session = auth ?? FakeAuthService(userId: 'user-ana@example.com');
  SharedPreferences.setMockInitialValues(savedPreferences);
  final preferences = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(session),
        marlixApiProvider.overrideWithValue(fake.api(session)),
        sharedPreferencesProvider.overrideWithValue(preferences),
        dialerProvider.overrideWithValue(dialer ?? FakeDialer()),
      ],
      child: const MarlixApp(),
    ),
  );
  await tester.pump();
  return fake;
}

Future<void> type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
}

/// Lets the response arrive and the list settle.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Finder get sendButton => find.byTooltip('Enviar');

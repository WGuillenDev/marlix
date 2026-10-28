import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:marlix/app.dart';
import 'package:marlix/models/reminder_config.dart';
import 'package:marlix/services/auth_service.dart';
import 'package:marlix/services/dialer.dart';
import 'package:marlix/services/help_resources.dart';
import 'package:marlix/services/marlix_api.dart';
import 'package:marlix/services/microphone_permission.dart';
import 'package:marlix/services/reminder_scheduler.dart';
import 'package:marlix/services/reminders.dart';
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

  /// The `mode` of every chat request, in order.
  final modes = <String?>[];
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

  /// What `/v1/memories` holds, newest first, as `{id, fact}`.
  List<Map<String, String>> memories = [];

  /// When set, every `/v1/memories` request fails with it.
  http.Response? Function()? memoriesFailure;

  /// `METHOD path body` of every `/v1/memories` request, in order.
  final memoryRequests = <String>[];

  http.Response _memories(http.Request request) {
    memoryRequests.add('${request.method} ${request.url.path} ${request.body}'.trim());
    if (memoriesFailure?.call() case final failure?) return failure;
    final id = request.url.pathSegments.length > 2 ? request.url.pathSegments[2] : null;
    final found = memories.where((m) => m['id'] == id).firstOrNull;
    Map<String, Object?> json(Map<String, String> m) => {
      ...m,
      'category': null,
      'createdAt': '2026-10-15T18:00:00Z',
      'updatedAt': '2026-10-15T18:00:00Z',
    };
    final notFound = jsonResponse({
      'error': {'code': 'NOT_FOUND', 'message': 'The memory does not exist.'},
    }, 404);
    switch ((request.method, id)) {
      case ('GET', null):
        return jsonResponse({'memories': memories.map(json).toList()});
      case ('DELETE', null):
        memories = [];
        return http.Response('', 204);
      case ('PATCH', _):
        if (found == null) return notFound;
        found['fact'] = (jsonDecode(request.body) as Map)['fact'] as String;
        return jsonResponse(json(found));
      case ('DELETE', _):
        if (found == null) return notFound;
        memories = [...memories]..remove(found);
        return http.Response('', 204);
    }
    return notFound;
  }

  /// Whether onboarding is done; `POST /v1/onboarding` sets it. Tests open on the chat.
  bool onboardingDone = true;

  /// When set, `GET /v1/me` answers with it instead of the profile.
  http.Response? Function()? meFailure;

  /// `GET /v1/me` waits for this to complete; replace it to keep it pending.
  Completer<void> meGate = Completer()..complete();

  /// What was sent to `POST /v1/onboarding`, in order.
  final onboardingRequests = <Map<String, Object?>>[];

  /// When set, `POST /v1/onboarding` fails with it.
  http.Response? Function()? onboardingFailure;

  /// The `layersPath` that `GET /v1/me` sends for the avatar (null: not sent). The seed's value.
  String? avatarLayersPath = 'assets/avatars/marlix/';

  /// The `voiceConfig` that `GET /v1/me` sends for the avatar (null: not sent, like an older
  /// backend). The seed's value.
  Map<String, Object?>? avatarVoiceConfig = {
    'engine': 'supertonic-3',
    'voice': 'F4',
    'language': 'es',
    'steps': 5,
    'rate': 1.05,
    'fallback': {'voice': 'default', 'pitch': 1.0, 'rate': 1.0},
  };

  /// How many times `GET /v1/me` was called.
  int meRequests = 0;

  bool _remindersAnswer = false;

  Map<String, Object?> _profile() => {
    'id': 'user-ana',
    'plan': 'personal',
    'avatar': {
      'id': 'avatar-1',
      'slug': 'marlix',
      'name': 'marlix',
      'layersPath': ?avatarLayersPath,
      'voiceConfig': ?avatarVoiceConfig,
    },
    'onboardingCompleted': onboardingDone,
    'dataConsentAt': onboardingDone ? '2026-10-19T20:00:00Z' : null,
    'settings': {'remindersEnabled': _remindersAnswer},
  };

  /// The session is too old to delete the account until the person signs in again.
  bool sessionIsOld = false;

  /// When set, `DELETE /v1/account` fails with it.
  http.Response? Function()? accountFailure;

  /// Authorization header of every `DELETE /v1/account`, in order.
  final accountDeletions = <String?>[];

  http.Response _deleteAccount(http.Request request, FakeAuthService auth) {
    accountDeletions.add(request.headers['Authorization']);
    if (accountFailure?.call() case final failure?) return failure;
    if (sessionIsOld && auth.signInCalls == 0) {
      return jsonResponse({
        'error': {'code': 'REAUTHENTICATION_REQUIRED', 'message': 'Sign in again.'},
      }, 401);
    }
    return http.Response('', 204);
  }

  MarlixApi api(FakeAuthService auth) => MarlixApi(
    accessToken: () => auth.accessToken,
    client: MockClient((request) async {
      authorizations.add(request.headers['Authorization']);
      if (request.url.path == '/v1/account') return _deleteAccount(request, auth);
      if (request.url.path == '/v1/me') {
        meRequests++;
        await meGate.future;
        return meFailure?.call() ?? jsonResponse(_profile());
      }
      if (request.url.path == '/v1/onboarding') {
        if (onboardingFailure?.call() case final failure?) return failure;
        final body = jsonDecode(request.body) as Map<String, Object?>;
        onboardingRequests.add(body);
        onboardingDone = true;
        _remindersAnswer = body['remindersEnabled'] == true;
        return jsonResponse(_profile());
      }
      if (request.url.path.startsWith('/v1/memories')) return _memories(request);
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
      final body = jsonDecode(request.body) as Map;
      sent.add(body['message'] as String);
      modes.add(body['mode'] as String?);
      return reply.future;
    }),
    baseUrl: Uri.parse('https://api.test'),
  );

  void answer(String userText, String replyText, {int remaining = 86, String tone = 'neutral'}) =>
      reply.complete(
        jsonResponse({
          'type': 'reply',
          'tone': tone,
          'userMessage': messageJson('user', userText),
          'reply': messageJson('assistant', replyText),
          'usage': usageJson(remaining: remaining),
        }),
      );

  void answerCrisis(String userText, String crisisText) => reply.complete(
    jsonResponse({
      'type': 'crisis',
      'tone': 'neutral',
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

  /// How many sign-ins succeeded.
  int signInCalls = 0;

  /// Completes sign-in and sign-up; replace it to keep them pending.
  Completer<void> gate = Completer()..complete();

  final _changes = StreamController<String?>.broadcast();

  @override
  String? userId;

  @override
  String? get email => userId?.replaceFirst('user-', '');

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
    signInCalls++;
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

/// The microphone dialog of the system: the test decides what the person answers.
class FakeMicrophone implements MicrophonePermission {
  bool allows = true;

  /// When it does not allow: the system will not show its dialog again.
  bool blocked = false;
  int asked = 0;
  int settingsOpened = 0;

  @override
  Future<bool> request() async => (await ask()) == MicrophoneAccess.granted;

  @override
  Future<MicrophoneAccess> ask() async {
    asked++;
    if (allows) return MicrophoneAccess.granted;
    return blocked ? MicrophoneAccess.blocked : MicrophoneAccess.denied;
  }

  @override
  Future<void> openSettings() async => settingsOpened++;
}

/// A reminder as the phone would hold it, repeating every week until cancelled.
typedef ScheduledReminder = ({int id, DateTime at, String title, String body});

class FakeReminderScheduler implements ReminderScheduler {
  /// What the user answers to the system permission dialog.
  bool grantsPermission = true;
  final scheduled = <ScheduledReminder>[];
  final _taps = StreamController<void>.broadcast();

  /// The user taps a reminder.
  void tap() => _taps.add(null);

  @override
  Stream<void> get taps => _taps.stream;

  @override
  Future<bool> requestPermission() async => grantsPermission;

  @override
  Future<bool> hasPermission() async => grantsPermission;

  @override
  Future<void> scheduleWeekly({
    required int id,
    required DateTime at,
    required String title,
    required String body,
  }) async {
    scheduled.add((id: id, at: at, title: title, body: body));
  }

  @override
  Future<void> cancelAll() async => scheduled.clear();
}

final testReminderConfig = ReminderConfig(
  defaultTime: (hour: 19, minute: 0),
  messages: const ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'],
);

/// Opens the app signed in as Ana, on the chat. With [auth] signed out, it
/// opens on the sign-in screen.
Future<FakeBackend> openChat(
  WidgetTester tester, {
  Size size = const Size(360, 800),
  FakeBackend? backend,
  FakeAuthService? auth,
  FakeDialer? dialer,
  FakeReminderScheduler? reminders,
  FakeMicrophone? microphone,
  Map<String, Object> savedPreferences = const {},
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  // The avatar floats for ever; with animations removed it rests, so
  // pumpAndSettle can finish. A test of the avatar's movement turns it back on.
  tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
    disableAnimations: true,
  );
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
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
        reminderSchedulerProvider.overrideWithValue(reminders ?? FakeReminderScheduler()),
        reminderConfigProvider.overrideWithValue(testReminderConfig),
        microphonePermissionProvider.overrideWithValue(microphone ?? FakeMicrophone()),
        ...overrides,
      ],
      child: const MarlixApp(),
    ),
  );
  // The profile loads first (S5-5); a second frame shows what it decides.
  await tester.pump();
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

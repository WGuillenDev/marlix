import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:marlix/config/app_config.dart';
import 'package:marlix/models/chat.dart';
import 'package:marlix/screens/chat/avatar_controller.dart';
import 'package:marlix/services/api_exception.dart';
import 'package:marlix/services/auth_service.dart';
import 'package:marlix/services/marlix_api.dart';

/// Calls the real backend from the app on a device or emulator, with the same
/// configuration file as `flutter run`. It signs up its own throwaway account
/// and deletes it at the end, so a run leaves no data behind (S5-6). It sends
/// two chat messages: one uses the model (and the Groq quota), the other is
/// caught by the crisis filter.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final random = Random.secure();
  final email =
      'it-${DateTime.now().millisecondsSinceEpoch}-${random.nextInt(1 << 32)}@marlix.test';
  final password = List.generate(24, (_) => random.nextInt(36).toRadixString(36)).join();
  var accountDeleted = false;
  final config = AppConfig.fromEnvironment();
  final client = http.Client();
  late SupabaseAuthService auth;
  late MarlixApi api;

  setUpAll(() async {
    auth = await SupabaseAuthService.initialize(config);
    await auth.signUp(email: email, password: password, birthDate: DateTime(1990, 1, 1));
    api = MarlixApi(
      client: client,
      baseUrl: config.apiBaseUrl,
      accessToken: () => auth.accessToken,
    );
  });
  tearDownAll(() async {
    // Also when a test failed halfway: the account must not stay in production.
    if (!accountDeleted) {
      await auth.signIn(email: email, password: password);
      await api.deleteAccount();
    }
    await auth.signOut();
    client.close();
  });

  testWidgets('a wrong password is invalidCredentials, never "unknown email"', (_) async {
    await expectLater(
      auth.signIn(email: email, password: '$password-wrong'),
      throwsA(
        isA<AuthFailureException>().having(
          (error) => error.failure,
          'failure',
          AuthFailure.invalidCredentials,
        ),
      ),
    );
  });

  testWidgets('GET /health', (_) async {
    expect(await api.health(), isTrue);
  });

  testWidgets('GET /v1/help-resources', (_) async {
    final help = await api.helpResources();
    expect(help.resources.where((resource) => resource.primary).single.phone, '911');
  });

  testWidgets('GET /v1/me returns the avatar with the folder of its layers', (_) async {
    final profile = await api.me();
    expect(profile.avatarSlug, 'marlix');
    expect(avatarFolderFrom(profile.avatarLayersPath), 'assets/avatars/marlix');
    expect(profile.avatarLayersPath, isNotNull, reason: 'the backend must send layersPath');
  });

  testWidgets('GET /v1/usage', (_) async {
    final usage = await api.usage();
    expect(usage.limit, greaterThan(0));
  });

  testWidgets('POST /v1/chat answers a normal message and saves it in the history', (_) async {
    final response = await api.sendMessage('Hola marlix, hoy fue un buen día.');
    expect(response, isA<ChatReply>());
    expect(response.reply.content, isNotEmpty);

    final history = (await api.history(limit: 2)).messages;
    expect(history.map((message) => message.id), [response.userMessage.id, response.reply.id]);
    expect(history.first.content, 'Hola marlix, hoy fue un buen día.');
  });

  testWidgets('POST /v1/chat recognizes a crisis and keeps it in the history', (_) async {
    final response = await api.sendMessage('me quiero morir');
    expect(response, isA<CrisisReply>());
    expect((response as CrisisReply).resources.first.phone, '911');

    final history = (await api.history(limit: 2)).messages;
    expect(history.map((message) => message.id), [response.userMessage.id, response.reply.id]);
  });

  testWidgets('GET /v1/history pages back without repeating messages', (_) async {
    final first = await api.history(limit: 2);
    expect(first.messages, hasLength(2));
    expect(first.nextCursor, isNotNull);

    final second = await api.history(limit: 2, before: first.nextCursor);
    final ids = {...first.messages, ...second.messages}.map((message) => message.id);
    expect(ids, hasLength(first.messages.length + second.messages.length));
    expect(
      second.messages.last.createdAt.isBefore(first.messages.first.createdAt) ||
          second.messages.last.createdAt == first.messages.first.createdAt,
      isTrue,
    );
  });

  // Leaves the account's memories as they were: deleting them is covered by
  // the backend and widget tests, and checked by hand on the emulator.
  testWidgets('GET, PATCH and DELETE /v1/memories', (_) async {
    final memories = await api.memories();
    for (var i = 1; i < memories.length; i++) {
      expect(memories[i].createdAt.isAfter(memories[i - 1].createdAt), isFalse);
    }
    if (memories.isNotEmpty) {
      final saved = await api.editMemory(memories.first.id, memories.first.fact);
      expect(saved.fact, memories.first.fact);
    }

    const missing = '00000000-0000-4000-8000-000000000000';
    await expectLater(api.editMemory(missing, 'x'), throwsA(isA<NotFoundException>()));
    await expectLater(api.deleteMemory(missing), throwsA(isA<NotFoundException>()));
  });

  testWidgets('a request without a session is a typed UnauthorizedException', (_) async {
    final anonymous = MarlixApi(client: client, baseUrl: config.apiBaseUrl);
    await expectLater(anonymous.usage(), throwsA(isA<UnauthorizedException>()));
  });

  testWidgets('DELETE /v1/account without a session deletes nothing', (_) async {
    final anonymous = MarlixApi(client: client, baseUrl: config.apiBaseUrl);
    await expectLater(anonymous.deleteAccount(), throwsA(isA<UnauthorizedException>()));
  });

  // Last on purpose: it removes the account the other tests use. A new sign-in
  // makes the session recent enough for the deletion (5 minutes).
  testWidgets('DELETE /v1/account removes the test account and its data', (_) async {
    await auth.signIn(email: email, password: password);
    await api.deleteAccount();
    accountDeleted = true;

    await expectLater(
      auth.signIn(email: email, password: password),
      throwsA(
        isA<AuthFailureException>().having(
          (error) => error.failure,
          'failure',
          AuthFailure.invalidCredentials,
        ),
      ),
    );
  });
}

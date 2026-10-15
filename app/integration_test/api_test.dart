import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:marlix/config/app_config.dart';
import 'package:marlix/models/chat.dart';
import 'package:marlix/services/api_exception.dart';
import 'package:marlix/services/marlix_api.dart';

/// Calls the real backend from the app on a device or emulator, with the same
/// configuration files as `flutter run`. It sends two chat messages: one uses
/// the model (and the Groq quota), the other is caught by the crisis filter.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final config = AppConfig.fromEnvironment();
  final client = http.Client();
  final api = MarlixApi(
    client: client,
    baseUrl: config.apiBaseUrl,
    accessToken: config.devAccessToken,
  );
  tearDownAll(client.close);

  testWidgets('GET /health', (_) async {
    expect(await api.health(), isTrue);
  });

  testWidgets('GET /v1/help-resources', (_) async {
    final help = await api.helpResources();
    expect(help.resources.where((resource) => resource.primary).single.phone, '911');
  });

  testWidgets('GET /v1/usage', (_) async {
    final usage = await api.usage();
    expect(usage.limit, greaterThan(0));
  });

  testWidgets('POST /v1/chat answers a normal message', (_) async {
    final response = await api.sendMessage('Hola marlix, hoy fue un buen día.');
    expect(response, isA<ChatReply>());
    expect(response.reply.content, isNotEmpty);
  });

  testWidgets('POST /v1/chat recognizes a crisis', (_) async {
    final response = await api.sendMessage('me quiero morir');
    expect(response, isA<CrisisReply>());
    expect((response as CrisisReply).resources.first.phone, '911');
  });

  testWidgets('a request without the token is a typed UnauthorizedException', (_) async {
    final anonymous = MarlixApi(client: client, baseUrl: config.apiBaseUrl);
    await expectLater(anonymous.usage(), throwsA(isA<UnauthorizedException>()));
  });
}

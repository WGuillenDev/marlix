import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../features/account/application/account_gateway.dart';
import '../features/account/presentation/session_state.dart';
import '../features/conversation/application/conversation_gateway.dart';
import '../features/memory/application/memory_gateway.dart';
import '../features/safety/application/safety_gateway.dart';
import '../features/voice/application/voice_gateway.dart';
import '../shared/infrastructure/http/marlix_api.dart';
import 'app_config.dart';

// The provider owns the HTTP client's lifetime.
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

final conversationGatewayProvider = Provider<ConversationGateway>(
  (ref) => ref.watch(marlixApiProvider),
);
final accountGatewayProvider = Provider<AccountGateway>((ref) => ref.watch(marlixApiProvider));
final memoryGatewayProvider = Provider<MemoryGateway>((ref) => ref.watch(marlixApiProvider));
final helpResourcesGatewayProvider = Provider<HelpResourcesGateway>(
  (ref) => ref.watch(marlixApiProvider),
);
final transcriptionGatewayProvider = Provider<TranscriptionGateway>(
  (ref) => ref.watch(marlixApiProvider),
);

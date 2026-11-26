import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.supabaseUrl,
    required this.supabasePublishableKey,
  });

  final Uri apiBaseUrl;

  // The app connects to Supabase for authentication only.
  final Uri supabaseUrl;

  /// Use the publishable key. Its data access is limited by RLS.
  final String supabasePublishableKey;

  factory AppConfig.fromEnvironment() => AppConfig.parse(
    apiBaseUrl: const String.fromEnvironment('API_BASE_URL'),
    supabaseUrl: const String.fromEnvironment('SUPABASE_URL'),
    supabasePublishableKey: const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
    allowInsecure: kDebugMode,
  );

  // Allow local HTTP only in debug builds.
  factory AppConfig.parse({
    required String apiBaseUrl,
    required String supabaseUrl,
    required String supabasePublishableKey,
    required bool allowInsecure,
  }) {
    if (apiBaseUrl.isEmpty || supabaseUrl.isEmpty || supabasePublishableKey.isEmpty) {
      throw const AppConfigException(
        'API_BASE_URL, SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY are required. Run with '
        '--dart-define-from-file=config/production.json (see app/README.md).',
      );
    }
    final apiUri = Uri.tryParse(apiBaseUrl);
    final schemes = allowInsecure ? const {'https', 'http'} : const {'https'};
    if (apiUri == null || !apiUri.hasAuthority || !schemes.contains(apiUri.scheme)) {
      throw AppConfigException(
        'API_BASE_URL must be an absolute ${schemes.join(' or ')} URL: "$apiBaseUrl".',
      );
    }
    if (!RegExp(r'^https://[a-z0-9]+\.supabase\.co/?$').hasMatch(supabaseUrl)) {
      throw AppConfigException(
        'SUPABASE_URL must be the project URL, https://<project-ref>.supabase.co: "$supabaseUrl".',
      );
    }
    // APK values are extractable. A service key here would bypass RLS.
    if (!supabasePublishableKey.startsWith('sb_publishable_')) {
      throw const AppConfigException(
        'SUPABASE_PUBLISHABLE_KEY must be the publishable key (sb_publishable_...). '
        'Never put the secret key in the app.',
      );
    }
    return AppConfig(
      apiBaseUrl: apiUri,
      supabaseUrl: Uri.parse(supabaseUrl),
      supabasePublishableKey: supabasePublishableKey,
    );
  }
}

class AppConfigException implements Exception {
  const AppConfigException(this.message);

  final String message;

  @override
  String toString() => 'AppConfigException: $message';
}

final appConfigProvider = Provider<AppConfig>(
  (ref) => throw UnimplementedError('appConfigProvider must be overridden'),
);

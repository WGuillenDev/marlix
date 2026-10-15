import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Settings that change per environment. They come from
/// `--dart-define-from-file=config/<environment>.json`, never from the code.
class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.supabaseUrl,
    required this.supabasePublishableKey,
  });

  final Uri apiBaseUrl;

  /// The Supabase project, for sign-up and sign-in only (S4-3): the app never
  /// reads the database directly, it goes through the backend.
  final Uri supabaseUrl;

  /// Public by design: it identifies the project and grants nothing beyond
  /// what RLS allows. Never the secret key, which only the backend holds.
  final String supabasePublishableKey;

  /// Reads the values compiled in with `--dart-define-from-file`.
  factory AppConfig.fromEnvironment() => AppConfig.parse(
    apiBaseUrl: const String.fromEnvironment('API_BASE_URL'),
    supabaseUrl: const String.fromEnvironment('SUPABASE_URL'),
    supabasePublishableKey: const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
    allowInsecure: kDebugMode,
  );

  /// Plain `http` is only accepted in debug builds, for a backend on the
  /// developer's computer; a release build always talks over HTTPS.
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
    // Same rule as the backend (api/src/config/env.ts): the project's base URL.
    if (!RegExp(r'^https://[a-z0-9]+\.supabase\.co/?$').hasMatch(supabaseUrl)) {
      throw AppConfigException(
        'SUPABASE_URL must be the project URL, https://<project-ref>.supabase.co: "$supabaseUrl".',
      );
    }
    // Anything compiled into an APK can be extracted: the secret key here
    // would let anyone skip RLS. The error never repeats the value.
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

/// Overridden in `main` with the validated configuration, and in tests.
final appConfigProvider = Provider<AppConfig>(
  (ref) => throw UnimplementedError('appConfigProvider must be overridden'),
);

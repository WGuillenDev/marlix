import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Settings that change per environment. They come from
/// `--dart-define-from-file=config/<environment>.json`, never from the code.
class AppConfig {
  const AppConfig({required this.apiBaseUrl});

  final Uri apiBaseUrl;

  /// Reads the values compiled in with `--dart-define-from-file`.
  factory AppConfig.fromEnvironment() => AppConfig.parse(
    apiBaseUrl: const String.fromEnvironment('API_BASE_URL'),
    allowInsecure: kDebugMode,
  );

  /// Plain `http` is only accepted in debug builds, for a backend on the
  /// developer's computer; a release build always talks over HTTPS.
  factory AppConfig.parse({required String apiBaseUrl, required bool allowInsecure}) {
    if (apiBaseUrl.isEmpty) {
      throw const AppConfigException(
        'API_BASE_URL is missing. Run with '
        '--dart-define-from-file=config/production.json (see app/README.md).',
      );
    }
    final uri = Uri.tryParse(apiBaseUrl);
    final schemes = allowInsecure ? const {'https', 'http'} : const {'https'};
    if (uri == null || !uri.hasAuthority || !schemes.contains(uri.scheme)) {
      throw AppConfigException(
        'API_BASE_URL must be an absolute ${schemes.join(' or ')} URL: "$apiBaseUrl".',
      );
    }
    return AppConfig(apiBaseUrl: uri);
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

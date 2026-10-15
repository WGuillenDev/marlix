import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Settings that change per environment. They come from
/// `--dart-define-from-file=config/<environment>.json`, never from the code.
class AppConfig {
  const AppConfig({required this.apiBaseUrl, this.devAccessToken});

  final Uri apiBaseUrl;

  /// Development token for `/v1` until accounts exist (S4-3). It comes from
  /// `config/dev-token.json`, which Git ignores; builds without it have none.
  final String? devAccessToken;

  /// Reads the values compiled in with `--dart-define-from-file`.
  ///
  /// A release build never reads the token's value, so the compiler leaves it
  /// out of the APK; it only checks whether one was passed, to refuse it.
  factory AppConfig.fromEnvironment() => AppConfig.parse(
    apiBaseUrl: const String.fromEnvironment('API_BASE_URL'),
    devAccessToken: kReleaseMode
        ? (const bool.hasEnvironment('DEV_ACCESS_TOKEN') ? _passedInRelease : '')
        : const String.fromEnvironment('DEV_ACCESS_TOKEN'),
    allowInsecure: kDebugMode,
    isRelease: kReleaseMode,
  );

  /// Stands in for a token passed to a release build, so [parse] refuses it
  /// without the real value ever being compiled in.
  static const _passedInRelease = 'passed-to-a-release-build';

  /// Plain `http` is only accepted in debug builds, for a backend on the
  /// developer's computer; a release build always talks over HTTPS.
  factory AppConfig.parse({
    required String apiBaseUrl,
    required bool allowInsecure,
    String devAccessToken = '',
    bool isRelease = false,
  }) {
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
    // A release APK can be shared, and anything compiled into it can be
    // extracted, so the token is only accepted in debug and profile builds.
    if (devAccessToken.isNotEmpty && isRelease) {
      throw const AppConfigException(
        'DEV_ACCESS_TOKEN is not allowed in a release build: anyone with the APK could '
        'extract it. Build release without config/dev-token.json.',
      );
    }
    // Same minimum as the backend (api/src/config/env.ts).
    if (devAccessToken.isNotEmpty && devAccessToken.length < 32) {
      throw const AppConfigException('DEV_ACCESS_TOKEN must be at least 32 characters.');
    }
    return AppConfig(
      apiBaseUrl: uri,
      devAccessToken: devAccessToken.isEmpty ? null : devAccessToken,
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

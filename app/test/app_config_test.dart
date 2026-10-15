import 'package:flutter_test/flutter_test.dart';
import 'package:marlix/config/app_config.dart';

void main() {
  group('AppConfig.parse', () {
    test('accepts an https URL', () {
      final config = AppConfig.parse(
        apiBaseUrl: 'https://marlix-api.onrender.com',
        allowInsecure: false,
      );
      expect(config.apiBaseUrl, Uri.parse('https://marlix-api.onrender.com'));
    });

    test('accepts http only when insecure URLs are allowed', () {
      final config = AppConfig.parse(apiBaseUrl: 'http://10.0.2.2:3000', allowInsecure: true);
      expect(config.apiBaseUrl.port, 3000);
      expect(
        () => AppConfig.parse(apiBaseUrl: 'http://10.0.2.2:3000', allowInsecure: false),
        throwsA(isA<AppConfigException>()),
      );
    });

    test('rejects a missing URL with a hint to the config file', () {
      expect(
        () => AppConfig.parse(apiBaseUrl: '', allowInsecure: true),
        throwsA(
          isA<AppConfigException>().having(
            (error) => error.message,
            'message',
            contains('config/production.json'),
          ),
        ),
      );
    });

    for (final invalid in ['marlix-api.onrender.com', '/v1', 'ftp://example.com']) {
      test('rejects "$invalid"', () {
        expect(
          () => AppConfig.parse(apiBaseUrl: invalid, allowInsecure: true),
          throwsA(isA<AppConfigException>()),
        );
      });
    }
  });
}

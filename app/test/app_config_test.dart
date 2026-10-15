import 'package:flutter_test/flutter_test.dart';
import 'package:marlix/config/app_config.dart';

const supabaseUrl = 'https://abcdefghijklmnop.supabase.co';
const publishableKey = 'sb_publishable_test-key';

AppConfig parse({
  String apiBaseUrl = 'https://marlix-api.onrender.com',
  String supabaseUrl = supabaseUrl,
  String supabasePublishableKey = publishableKey,
  bool allowInsecure = false,
}) => AppConfig.parse(
  apiBaseUrl: apiBaseUrl,
  supabaseUrl: supabaseUrl,
  supabasePublishableKey: supabasePublishableKey,
  allowInsecure: allowInsecure,
);

Matcher configError(String text) =>
    throwsA(isA<AppConfigException>().having((error) => error.message, 'message', contains(text)));

void main() {
  group('AppConfig.parse', () {
    test('accepts https URLs and the publishable key', () {
      final config = parse();
      expect(config.apiBaseUrl, Uri.parse('https://marlix-api.onrender.com'));
      expect(config.supabaseUrl, Uri.parse(supabaseUrl));
      expect(config.supabasePublishableKey, publishableKey);
    });

    test('accepts an http backend only when insecure URLs are allowed', () {
      final config = parse(apiBaseUrl: 'http://10.0.2.2:3000', allowInsecure: true);
      expect(config.apiBaseUrl.port, 3000);
      expect(() => parse(apiBaseUrl: 'http://10.0.2.2:3000'), throwsA(isA<AppConfigException>()));
    });

    test('rejects a missing value with a hint to the config file', () {
      expect(() => parse(apiBaseUrl: ''), configError('config/production.json'));
      expect(() => parse(supabaseUrl: ''), configError('config/production.json'));
      expect(() => parse(supabasePublishableKey: ''), configError('config/production.json'));
    });

    test('accepts only a Supabase project URL, even in debug', () {
      for (final url in [
        'http://abcdefghijklmnop.supabase.co',
        'https://example.com',
        '$supabaseUrl/rest/v1',
      ]) {
        expect(() => parse(supabaseUrl: url, allowInsecure: true), configError('SUPABASE_URL'));
      }
    });

    test('refuses the secret key without repeating it', () {
      const secret = 'sb_secret_never-in-the-app';
      expect(
        () => parse(supabasePublishableKey: secret),
        throwsA(
          isA<AppConfigException>()
              .having((error) => error.message, 'message', contains('Never put the secret key'))
              .having((error) => error.message, 'message', isNot(contains(secret))),
        ),
      );
    });
  });
}

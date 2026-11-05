import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:marlix/screens/auth_screen.dart';
import 'package:marlix/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

Map<String, Object?> sessionJson() => {
  'access_token': 'header.payload.signature',
  'token_type': 'bearer',
  'expires_in': 3600,
  'expires_at': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
  'refresh_token': 'refresh',
  'user': {
    'id': '00000000-0000-4000-8000-00000000000a',
    'aud': 'authenticated',
    'role': 'authenticated',
    'email': 'ana@example.com',
    'app_metadata': <String, Object?>{},
    'user_metadata': <String, Object?>{},
    'created_at': '2026-10-15T18:00:00Z',
  },
};

http.Response authError(int status, String code) => http.Response(
  jsonEncode({'code': status, 'error_code': code, 'msg': 'Developer message.'}),
  status,
  headers: {'content-type': 'application/json'},
);

/// The real Supabase client, with its HTTP answered by [handler].
SupabaseAuthService serviceAnswering(Future<http.Response> Function(http.Request) handler) =>
    SupabaseAuthService(
      supabase.GoTrueClient(
        url: 'https://abcdefghijklmnop.supabase.co/auth/v1',
        httpClient: MockClient(handler),
        autoRefreshToken: false,
        flowType: supabase.AuthFlowType.implicit,
      ),
      recoveryClient: () => supabase.GoTrueClient(
        url: 'https://abcdefghijklmnop.supabase.co/auth/v1',
        httpClient: MockClient(handler),
        autoRefreshToken: false,
        flowType: supabase.AuthFlowType.implicit,
      ),
    );

Matcher failsWith(AuthFailure failure) =>
    throwsA(isA<AuthFailureException>().having((error) => error.failure, 'failure', failure));

void main() {
  group('minimum age', () {
    test('is 18, counted to the day', () {
      final today = DateTime(2026, 10, 15);
      expect(isOldEnough(DateTime(2008, 10, 15), today), isTrue);
      expect(isOldEnough(DateTime(2008, 10, 16), today), isFalse);
      expect(isOldEnough(DateTime(1950, 1, 1), today), isTrue);
    });

    test('someone born on 29 February turns 18 on 1 March in a common year', () {
      expect(isOldEnough(DateTime(2008, 2, 29), DateTime(2026, 2, 28)), isFalse);
      expect(isOldEnough(DateTime(2008, 2, 29), DateTime(2026, 3, 1)), isTrue);
    });
  });

  group('birth date input', () {
    test('reads DD/MM/AAAA and refuses dates that do not exist', () {
      expect(parseBirthDate('02/11/1985'), DateTime(1985, 11, 2));
      expect(parseBirthDate('31/02/1990'), isNull);
      expect(parseBirthDate('1985-11-02'), isNull);
      expect(parseBirthDate('2/11/1985'), isNull);
    });

    test('is sent as YYYY-MM-DD, the format the database accepts', () {
      expect(formatBirthDate(DateTime(1985, 11, 2)), '1985-11-02');
    });

    test('the field adds the slashes and keeps at most 8 digits', () {
      const formatter = BirthDateInputFormatter();
      String format(String text) =>
          formatter.formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: text)).text;

      expect(format('0211'), '02/11');
      expect(format('021119851'), '02/11/1985');
      expect(format('02/1a1'), '02/11');
    });
  });

  group('SupabaseAuthService', () {
    test('confirmation exchanges the email code for the normal session', () async {
      final service = serviceAnswering((request) async {
        expect(request.url.path, '/auth/v1/verify');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['email'], 'ana@example.com');
        expect(body['token'], '123456');
        expect(body['type'], 'email');
        return http.Response(jsonEncode(sessionJson()), 200);
      });
      await service.verifyEmail(email: ' ana@example.com ', code: '123456');
      expect(service.accessToken, isNotNull);
    });

    test('recovery never publishes or persists the app session', () async {
      final paths = <String>[];
      final service = serviceAnswering((request) async {
        paths.add(request.url.path);
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (request.url.path.endsWith('/verify')) {
          expect(body['type'], 'recovery');
          return http.Response(jsonEncode(sessionJson()), 200);
        }
        expect(request.url.path, '/auth/v1/user');
        expect(request.headers['Authorization'], 'Bearer header.payload.signature');
        expect(body['password'], 'new-password');
        return http.Response(jsonEncode(sessionJson()['user']), 200);
      });
      final events = <String?>[];
      final subscription = service.userIdChanges.listen(events.add);
      await service.verifyRecovery(email: 'ana@example.com', code: '123456');
      expect(service.userId, isNull);
      expect(service.accessToken, isNull);
      await service.changeRecoveredPassword('new-password');
      expect(paths, ['/auth/v1/verify', '/auth/v1/user']);
      expect(events.whereType<String>(), isEmpty);
      await subscription.cancel();
      await expectLater(
        service.changeRecoveredPassword('again'),
        failsWith(AuthFailure.invalidCode),
      );
    });

    test('failed password update can be retried without reusing the OTP', () async {
      var updates = 0;
      final service = serviceAnswering((request) async {
        if (request.url.path.endsWith('/verify')) {
          return http.Response(jsonEncode(sessionJson()), 200);
        }
        if (updates++ == 0) return authError(422, 'weak_password');
        return http.Response(jsonEncode(sessionJson()['user']), 200);
      });
      await service.verifyRecovery(email: 'ana@example.com', code: '123456');
      await expectLater(
        service.changeRecoveredPassword('weak'),
        failsWith(AuthFailure.weakPassword),
      );
      await service.changeRecoveredPassword('stronger-password');
      expect(service.userId, isNull);
    });

    test('canceling recovery removes permission to update the password', () async {
      final service = serviceAnswering((_) async => http.Response(jsonEncode(sessionJson()), 200));
      await service.verifyRecovery(email: 'ana@example.com', code: '123456');
      service.cancelRecovery();
      await expectLater(service.changeRecoveredPassword('new'), failsWith(AuthFailure.invalidCode));
    });

    test('expired codes are reported without exposing an account', () async {
      final service = serviceAnswering((_) async => authError(403, 'otp_expired'));
      await expectLater(
        service.verifyEmail(email: 'ana@example.com', code: '000000'),
        failsWith(AuthFailure.invalidCode),
      );
      await expectLater(
        service.verifyRecovery(email: 'ana@example.com', code: '000000'),
        failsWith(AuthFailure.invalidCode),
      );
      expect(service.accessToken, isNull);
    });

    for (final code in ['user_not_found', 'user_already_exists']) {
      test('email requests hide $code', () async {
        final service = serviceAnswering((_) async => authError(400, code));
        await service.requestPasswordReset('unknown@example.com');
        await service.resendConfirmation('unknown@example.com');
      });
    }

    test('signs up with the birth date as user metadata', () async {
      late Map<String, Object?> body;
      final service = serviceAnswering((request) async {
        expect(request.url.path, '/auth/v1/signup');
        body = jsonDecode(request.body) as Map<String, Object?>;
        return http.Response(jsonEncode(sessionJson()), 200);
      });

      await service.signUp(
        email: ' ana@example.com ',
        password: 'una-contraseña-larga',
        birthDate: DateTime(1990, 5, 20),
      );

      expect(body['email'], 'ana@example.com');
      expect(body['data'], {'birth_date': '1990-05-20'});
      expect(service.userId, '00000000-0000-4000-8000-00000000000a');
      expect(service.accessToken, 'header.payload.signature');
    });

    test('a sign-up without a session waits for email confirmation', () async {
      final service = serviceAnswering(
        (_) async => http.Response(jsonEncode(sessionJson()['user']), 200),
      );

      await service.signUp(
        email: 'a@example.com',
        password: 'una-larga',
        birthDate: DateTime(1990),
      );
      expect(service.userId, isNull);
    });

    for (final (status, code, failure) in [
      (400, 'invalid_credentials', AuthFailure.invalidCredentials),
      (422, 'user_already_exists', AuthFailure.emailTaken),
      (400, 'email_address_invalid', AuthFailure.invalidEmail),
      (429, 'over_request_rate_limit', AuthFailure.tooManyAttempts),
      (500, 'unexpected_failure', AuthFailure.unexpected),
    ]) {
      test('translates $code into ${failure.name}', () async {
        final service = serviceAnswering((_) async => authError(status, code));
        expect(service.signIn(email: 'a@example.com', password: 'x'), failsWith(failure));
      });
    }

    test('a missing connection is a network failure', () async {
      final service = serviceAnswering((_) async => throw http.ClientException('offline'));
      expect(service.signIn(email: 'a@example.com', password: 'x'), failsWith(AuthFailure.network));
    });

    test('a weak password is reported as such', () async {
      final service = serviceAnswering(
        (_) async => http.Response(
          jsonEncode({
            'code': 422,
            'error_code': 'weak_password',
            'msg': 'Password is too weak.',
            'weak_password': {
              'reasons': ['length'],
            },
          }),
          422,
        ),
      );
      expect(
        service.signUp(email: 'a@example.com', password: 'x', birthDate: DateTime(1990)),
        failsWith(AuthFailure.weakPassword),
      );
    });
  });
}

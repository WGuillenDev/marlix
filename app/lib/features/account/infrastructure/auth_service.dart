import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../bootstrap/app_config.dart';
import '../application/auth_service.dart';

class SupabaseAuthService implements AuthService {
  SupabaseAuthService(this._auth, {required this.recoveryClient});

  final supabase.GoTrueClient _auth;
  final supabase.GoTrueClient Function() recoveryClient;
  supabase.GoTrueClient? _recovery;

  static Future<SupabaseAuthService> initialize(AppConfig config) async {
    final client = await supabase.Supabase.initialize(
      url: config.supabaseUrl.toString(),
      publishableKey: config.supabasePublishableKey,
      authOptions: const supabase.FlutterAuthClientOptions(
        localStorage: SecureSessionStorage(),
        detectSessionInUri: false,
      ),
    );
    return SupabaseAuthService(
      client.client.auth,
      // Keep password-recovery sessions out of persistent session storage.
      recoveryClient: () => supabase.GoTrueClient(
        url: '${config.supabaseUrl}/auth/v1',
        headers: {
          'apikey': config.supabasePublishableKey,
          'Authorization': 'Bearer ${config.supabasePublishableKey}',
        },
        autoRefreshToken: false,
        flowType: supabase.AuthFlowType.implicit,
      ),
    );
  }

  @override
  String? get userId => _auth.currentUser?.id;

  @override
  String? get email => _auth.currentUser?.email;

  @override
  String? get accessToken => _auth.currentSession?.accessToken;

  @override
  Stream<String?> get userIdChanges =>
      _auth.onAuthStateChange.map((state) => state.session?.user.id).distinct();

  @override
  Future<void> signIn({required String email, required String password}) =>
      _guard(() => _auth.signInWithPassword(email: email.trim(), password: password));

  @override
  Future<void> signUp({
    required String email,
    required String password,
    required DateTime birthDate,
  }) => _guard(() async {
    await _auth.signUp(
      email: email.trim(),
      password: password,
      data: {'birth_date': formatBirthDate(birthDate)},
    );
  });

  @override
  Future<void> verifyEmail({required String email, required String code}) =>
      _guard(() => _auth.verifyOTP(email: email.trim(), token: code, type: supabase.OtpType.email));

  @override
  Future<void> resendConfirmation(String email) =>
      _privateRequest(() => _auth.resend(email: email.trim(), type: supabase.OtpType.signup));

  @override
  Future<void> requestPasswordReset(String email) =>
      _privateRequest(() => _auth.resetPasswordForEmail(email.trim()));

  @override
  Future<void> verifyRecovery({required String email, required String code}) async {
    cancelRecovery();
    final recovery = _recovery = recoveryClient();
    try {
      await _guard(
        () => recovery.verifyOTP(email: email.trim(), token: code, type: supabase.OtpType.recovery),
      );
    } catch (_) {
      cancelRecovery();
      rethrow;
    }
  }

  @override
  Future<void> changeRecoveredPassword(String password) async {
    final recovery = _recovery;
    if (recovery?.currentSession == null) {
      throw const AuthFailureException(AuthFailure.invalidCode);
    }
    await _guard(() => recovery!.updateUser(supabase.UserAttributes(password: password)));
    cancelRecovery();
  }

  @override
  void cancelRecovery() {
    _recovery?.dispose();
    _recovery = null;
  }

  static Future<void> _privateRequest(Future<void> Function() action) async {
    try {
      await _guard(action);
    } on AuthFailureException catch (error) {
      if (error.failure != AuthFailure.emailTaken &&
          error.failure != AuthFailure.invalidCredentials) {
        rethrow;
      }
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  static Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on supabase.AuthException catch (error) {
      throw AuthFailureException(failureOf(error));
    }
  }

  /// Codes from https://supabase.com/docs/guides/auth/debugging/error-codes
  static AuthFailure failureOf(supabase.AuthException error) {
    // Without a status, the request failed before Supabase answered.
    if (error is supabase.AuthRetryableFetchException) {
      return error.statusCode == null ? AuthFailure.network : AuthFailure.unexpected;
    }
    if (error is supabase.AuthWeakPasswordException) return AuthFailure.weakPassword;
    return switch (error.code) {
      'invalid_credentials' || 'email_not_confirmed' => AuthFailure.invalidCredentials,
      'user_already_exists' || 'email_exists' => AuthFailure.emailTaken,
      'email_address_invalid' || 'validation_failed' => AuthFailure.invalidEmail,
      'weak_password' => AuthFailure.weakPassword,
      'otp_expired' || 'otp_disabled' => AuthFailure.invalidCode,
      'user_not_found' => AuthFailure.invalidCredentials,
      'over_request_rate_limit' => AuthFailure.tooManyAttempts,
      _ when error.statusCode == '429' => AuthFailure.tooManyAttempts,
      _ => AuthFailure.unexpected,
    };
  }
}

String formatBirthDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// Store sessions using Android Keystore-backed encryption.
class SecureSessionStorage extends supabase.LocalStorage {
  const SecureSessionStorage();

  static const _key = 'marlix.supabase.session';
  static const _storage = FlutterSecureStorage();

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() => _storage.containsKey(key: _key);

  @override
  Future<String?> accessToken() => _storage.read(key: _key);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _storage.write(key: _key, value: persistSessionString);

  @override
  Future<void> removePersistedSession() => _storage.delete(key: _key);
}

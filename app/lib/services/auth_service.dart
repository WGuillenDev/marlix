import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../config/app_config.dart';

/// Decided on 2026-10-15 (docs/decisions.md). The database refuses younger
/// sign-ups too (`handle_new_auth_user` in docs/schema.sql), whatever the app does.
const minimumAge = 18;

/// Whether someone born on [birthDate] is old enough on [today].
bool isOldEnough(DateTime birthDate, DateTime today) {
  final birthday = DateTime(birthDate.year + minimumAge, birthDate.month, birthDate.day);
  return !birthday.isAfter(DateTime(today.year, today.month, today.day));
}

/// Why sign-up or sign-in failed; each one gets its own copy on screen.
enum AuthFailure {
  /// Wrong email or password. Never says which, so it does not reveal
  /// whether the email has an account (US-01).
  invalidCredentials,
  emailTaken,
  invalidEmail,
  weakPassword,
  tooManyAttempts,
  network,
  unexpected,
}

class AuthFailureException implements Exception {
  const AuthFailureException(this.failure);

  final AuthFailure failure;

  @override
  String toString() => 'AuthFailureException: ${failure.name}';
}

/// Sign-up, sign-in and the session (S4-3). Screens use this, never the
/// Supabase client, so tests can replace it.
abstract interface class AuthService {
  /// The signed-in user's id, or null when there is no session.
  String? get userId;

  /// The current session token, sent to the backend as `Authorization: Bearer`.
  String? get accessToken;

  /// Emits the user id on sign-in and null on sign-out or when the session ends.
  Stream<String?> get userIdChanges;

  /// Throws [AuthFailureException].
  Future<void> signIn({required String email, required String password});

  /// [birthDate] is checked by the database too. Throws [AuthFailureException].
  Future<void> signUp({
    required String email,
    required String password,
    required DateTime birthDate,
  });

  Future<void> signOut();
}

class SupabaseAuthService implements AuthService {
  SupabaseAuthService(this._auth);

  final supabase.GoTrueClient _auth;

  /// Starts Supabase and restores the saved session before the first frame,
  /// so a signed-in user goes straight to the chat.
  static Future<SupabaseAuthService> initialize(AppConfig config) async {
    final client = await supabase.Supabase.initialize(
      url: config.supabaseUrl.toString(),
      publishableKey: config.supabasePublishableKey,
      authOptions: const supabase.FlutterAuthClientOptions(
        localStorage: SecureSessionStorage(),
        // Email and password only: no links open the app (S4-3).
        detectSessionInUri: false,
      ),
    );
    return SupabaseAuthService(client.client.auth);
  }

  @override
  String? get userId => _auth.currentUser?.id;

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
    final response = await _auth.signUp(
      email: email.trim(),
      password: password,
      // Read by the sign-up trigger, which stores it on the profile.
      data: {'birth_date': formatBirthDate(birthDate)},
    );
    // "Confirm email" is off (S4-3), so a new account is signed in at once.
    // Without a session the project settings changed: nothing to show the user.
    if (response.session == null) throw const AuthFailureException(AuthFailure.unexpected);
  });

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
    // Retryable without a status: the request never got an answer. With a
    // 5xx status, Supabase answered with an error (a refused sign-up too).
    if (error is supabase.AuthRetryableFetchException) {
      return error.statusCode == null ? AuthFailure.network : AuthFailure.unexpected;
    }
    if (error is supabase.AuthWeakPasswordException) return AuthFailure.weakPassword;
    return switch (error.code) {
      'invalid_credentials' || 'email_not_confirmed' => AuthFailure.invalidCredentials,
      'user_already_exists' || 'email_exists' => AuthFailure.emailTaken,
      'email_address_invalid' || 'validation_failed' => AuthFailure.invalidEmail,
      'weak_password' => AuthFailure.weakPassword,
      'over_request_rate_limit' => AuthFailure.tooManyAttempts,
      _ when error.statusCode == '429' => AuthFailure.tooManyAttempts,
      _ => AuthFailure.unexpected,
    };
  }
}

/// `YYYY-MM-DD`, the format the sign-up trigger accepts.
String formatBirthDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// Keeps the session encrypted with a key from the Android Keystore, instead
/// of the plain SharedPreferences Supabase uses by default (S4-3). Backups
/// already exclude the app's data (S4-11).
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

/// Overridden in `main` with the started service, and in tests.
final authServiceProvider = Provider<AuthService>(
  (ref) => throw UnimplementedError('authServiceProvider must be overridden'),
);

/// The signed-in user's id; null shows the sign-in screen.
final signedInUserProvider = NotifierProvider<SignedInUser, String?>(SignedInUser.new);

class SignedInUser extends Notifier<String?> {
  @override
  String? build() {
    final auth = ref.watch(authServiceProvider);
    final subscription = auth.userIdChanges.listen((id) => state = id);
    ref.onDispose(subscription.cancel);
    return auth.userId;
  }
}

/// True after the backend rejected the session, so the sign-in screen can
/// say why it appeared. Cleared on the next sign-in.
final sessionEndedProvider = NotifierProvider<SessionEnded, bool>(SessionEnded.new);

class SessionEnded extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool ended) => state = ended;
}

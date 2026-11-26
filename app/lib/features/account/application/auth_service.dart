enum AuthFailure {
  /// Keep credential errors generic to avoid disclosing whether an account exists.
  invalidCredentials,
  emailTaken,
  invalidEmail,
  weakPassword,
  tooManyAttempts,
  network,
  unexpected,
  invalidCode,
}

class AuthFailureException implements Exception {
  const AuthFailureException(this.failure);

  final AuthFailure failure;

  @override
  String toString() => 'AuthFailureException: ${failure.name}';
}

/// Email/password authentication and the session. Screens use this, never the
/// Supabase client, so tests can replace it.
abstract interface class AuthService {
  String? get userId;

  /// The signed-in user's email, to confirm the password before an action
  /// that cannot be undone.
  String? get email;

  String? get accessToken;

  Stream<String?> get userIdChanges;

  Future<void> signIn({required String email, required String password});

  /// [birthDate] is checked by the database too. Throws [AuthFailureException].
  Future<void> signUp({
    required String email,
    required String password,
    required DateTime birthDate,
  });

  Future<void> signOut();

  Future<void> verifyEmail({required String email, required String code});
  Future<void> resendConfirmation(String email);
  Future<void> requestPasswordReset(String email);
  Future<void> verifyRecovery({required String email, required String code});
  Future<void> changeRecoveredPassword(String password);
  void cancelRecovery();
}

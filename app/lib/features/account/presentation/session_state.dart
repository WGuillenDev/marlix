import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/auth_service.dart';

final authServiceProvider = Provider<AuthService>(
  (ref) => throw UnimplementedError('authServiceProvider must be overridden'),
);

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

/// True after the person deleted their account, so the sign-in screen can
/// confirm it. Cleared on the next sign-in or sign-up.
final accountDeletedProvider = NotifierProvider<AccountDeleted, bool>(AccountDeleted.new);

class AccountDeleted extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool deleted) => state = deleted;
}

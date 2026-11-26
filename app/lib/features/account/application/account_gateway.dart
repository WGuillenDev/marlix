import '../domain/profile.dart';

abstract interface class AccountGateway {
  Future<Profile> me();
  Future<Profile> completeOnboarding({required bool remindersEnabled});
  Future<void> deleteAccount();
}

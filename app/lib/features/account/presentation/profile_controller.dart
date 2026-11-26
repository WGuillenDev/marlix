import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/api_providers.dart';
import '../../../shared/application/api_exception.dart';
import '../application/account_gateway.dart';
import '../domain/profile.dart';
import 'session_state.dart';

class ProfileController extends AsyncNotifier<Profile> {
  /// Starts over for every session: another account has its own onboarding.
  @override
  Future<Profile> build() {
    // Nothing to read without a session: a request now would come back 401 and
    // make a sign-out look like an expired session.
    if (ref.watch(signedInUserProvider) == null) return Completer<Profile>().future;
    return _guarded(_api.me);
  }

  AccountGateway get _api => ref.read(accountGatewayProvider);

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _guarded(_api.me));
  }

  /// Records the consent and the answer to the reminders offer. Throws the
  /// [ApiException] if the backend refused, and onboarding stays open.
  Future<void> completeOnboarding({required bool remindersEnabled}) async {
    final Profile profile;
    try {
      profile = await _guarded(() => _api.completeOnboarding(remindersEnabled: remindersEnabled));
    } on OnboardingAlreadyCompletedException {
      await reload();
      return;
    }
    if (ref.mounted) state = AsyncData(profile);
  }

  Future<T> _guarded<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on UnauthorizedException {
      ref.read(sessionEndedProvider.notifier).set(true);
      await ref.read(authServiceProvider).signOut();
      rethrow;
    }
  }
}

final profileControllerProvider = AsyncNotifierProvider<ProfileController, Profile>(
  ProfileController.new,
  retry: (_, _) => null,
);

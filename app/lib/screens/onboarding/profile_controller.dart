import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/profile.dart';
import '../../services/api_exception.dart';
import '../../services/auth_service.dart';
import '../../services/marlix_api.dart';

/// The signed-in user's profile (S5-5): it decides between onboarding and the
/// chat, so the app never shows the chat before the consent is on record.
class ProfileController extends AsyncNotifier<Profile> {
  /// Starts over for every session: another account has its own onboarding.
  @override
  Future<Profile> build() {
    // Nothing to read without a session: a request now would come back 401 and
    // make a sign-out look like an expired session.
    if (ref.watch(signedInUserProvider) == null) return Completer<Profile>().future;
    return _guarded(_api.me);
  }

  MarlixApi get _api => ref.read(marlixApiProvider);

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
      // Finished on another phone first: the profile says so, nothing is lost.
      await reload();
      return;
    }
    if (ref.mounted) state = AsyncData(profile);
  }

  /// A rejected session ends it, like the chat does.
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

// No automatic retries: a failure shows the retry button, and the person decides.
final profileControllerProvider = AsyncNotifierProvider<ProfileController, Profile>(
  ProfileController.new,
  retry: (_, _) => null,
);

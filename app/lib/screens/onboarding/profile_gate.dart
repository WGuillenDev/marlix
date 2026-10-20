import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../chat/chat_screen.dart';
import '../help_screen.dart';
import 'onboarding_screen.dart';
import 'profile_controller.dart';

/// What a signed-in user sees first: onboarding until the consent is on
/// record, then the chat. While the profile loads, or if it cannot, the chat
/// stays closed: without the consent the app must not be used.
class ProfileGate extends ConsumerWidget {
  const ProfileGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(profileControllerProvider)) {
      AsyncData(:final value) when value.onboardingCompleted => const ChatScreen(),
      AsyncData() => const OnboardingScreen(),
      AsyncError() => const _LoadFailed(),
      _ => const _Loading(),
    };
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.tan),
            SizedBox(height: 16),
            Text('Un momento…', style: AppText.body),
          ],
        ),
      ),
    );
  }
}

class _LoadFailed extends ConsumerWidget {
  const _LoadFailed();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'No se pudo abrir tu cuenta',
                  style: AppText.title,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Revisá tu conexión a internet e intentalo de nuevo.',
                  style: AppText.body,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: ref.read(profileControllerProvider.notifier).reload,
                  child: const Text('Reintentar'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => ref.read(authServiceProvider).signOut(),
                  child: const Text('Cerrar sesión'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).push(HelpScreen.route()),
                  child: const Text('Ayuda: 9-1-1 y otros recursos'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

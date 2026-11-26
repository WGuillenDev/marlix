import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/presentation/app_theme.dart';
import '../../../avatar/presentation/avatar_controller.dart';
import '../../../avatar/presentation/avatar_marlix.dart';
import 'step_layout.dart';

class WelcomeStep extends ConsumerWidget {
  const WelcomeStep({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OnboardingStep(
      actions: [OnboardingButton(label: 'Continuar', onPressed: onContinue)],
      children: [
        Center(
          child: DecoratedBox(
            decoration: const BoxDecoration(color: AppColors.tanLight, shape: BoxShape.circle),
            child: SizedBox.square(
              dimension: 260,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: AvatarMarlix(
                  state: AvatarState.happy,
                  folder: ref.watch(avatarFolderProvider),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text('¡Hola! Soy marlix', style: AppText.display, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        const Text(
          'Estoy aquí para conversar contigo y acompañarte en tu día, por texto o por voz. '
          'Me inspiré en Marley, una perrita muy querida.',
          style: AppText.body,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        const OnboardingCard(
          color: AppColors.tanLight,
          child: Text(
            'Soy una inteligencia artificial, no una persona. '
            'Mi voz también la genera una máquina.',
            style: AppText.bodyStrong,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Te voy a contar cómo funciono antes de empezar.',
          style: AppText.body.copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

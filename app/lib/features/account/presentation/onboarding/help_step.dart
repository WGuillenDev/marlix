import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/presentation/app_theme.dart';
import '../../../avatar/presentation/avatar_controller.dart';
import '../../../avatar/presentation/avatar_marlix.dart';
import 'step_layout.dart';

class HelpStep extends ConsumerWidget {
  const HelpStep({
    super.key,
    required this.finishing,
    required this.failed,
    required this.onFinish,
  });

  final bool finishing;
  final bool failed;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OnboardingStep(
      actions: [
        if (failed) ...[
          Semantics(
            liveRegion: true,
            child: Text(
              'No se pudo guardar. Revisa tu conexión e inténtalo de nuevo.',
              style: AppText.bodyStrong.copyWith(color: AppColors.crisis),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
        ],
        OnboardingButton(label: '¡Empecemos!', onPressed: onFinish, busy: finishing),
      ],
      children: [
        Semantics(
          header: true,
          child: const Text('Si no estás bien, aquí hay ayuda', style: AppText.title),
        ),
        const SizedBox(height: 16),
        OnboardingCard(
          child: Row(
            children: [
              const Expanded(child: Text('marlix', style: AppText.heading)),
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.crisis, width: 2.5),
                  color: AppColors.white,
                ),
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(Icons.support_rounded, size: 28, color: AppColors.crisis),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Toca el salvavidas en cualquier momento, en el chat o en modo voz. Ahí verás el '
          '9-1-1 y otros números de apoyo en Costa Rica.',
          style: AppText.body,
        ),
        const SizedBox(height: 12),
        const Text('También funciona sin internet.', style: AppText.bodyStrong),
        const SizedBox(height: 16),
        Center(
          child: SizedBox.square(
            dimension: 180,
            child: AvatarMarlix(state: AvatarState.idle, folder: ref.watch(avatarFolderProvider)),
          ),
        ),
      ],
    );
  }
}

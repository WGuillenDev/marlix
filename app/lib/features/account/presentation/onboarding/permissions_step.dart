import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/presentation/app_theme.dart';
import '../../../settings/presentation/reminders.dart';
import '../../../settings/presentation/reminders_toggle.dart';
import 'step_layout.dart';

enum MicrophoneChoice { unasked, allowed, later }

class PermissionsStep extends ConsumerWidget {
  const PermissionsStep({
    super.key,
    required this.microphone,
    required this.onAllowMicrophone,
    required this.onLaterMicrophone,
    required this.onContinue,
    required this.remindersDenied,
    required this.onToggleReminders,
  });

  final MicrophoneChoice microphone;
  final VoidCallback onAllowMicrophone;
  final VoidCallback onLaterMicrophone;
  final VoidCallback onContinue;
  final bool remindersDenied;
  final ValueChanged<bool> onToggleReminders;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remindersOn = ref.watch(remindersProvider).enabled;
    return OnboardingStep(
      actions: [OnboardingButton(label: 'Continuar', onPressed: onContinue)],
      children: [
        Semantics(
          header: true,
          child: const Text('Hablemos también por voz', style: AppText.title),
        ),
        const SizedBox(height: 16),
        OnboardingCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.tanLight,
                    child: Icon(Icons.mic_rounded, size: 30, color: AppColors.tanDark),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(child: Text('Micrófono', style: AppText.heading)),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Lo uso solo cuando estás en modo voz, para escucharte y responderte con mi voz.',
                style: AppText.body,
              ),
              const SizedBox(height: 8),
              Text(
                'Lo que dices viaja a nuestro servidor para pasarlo a texto y no se guarda.',
                style: AppText.caption.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              switch (microphone) {
                // Wrap actions when larger text no longer fits side by side.
                MicrophoneChoice.unasked => Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton(
                      onPressed: onAllowMicrophone,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        backgroundColor: AppColors.tanDark,
                        foregroundColor: AppColors.white,
                        textStyle: AppText.button,
                      ),
                      child: const Text('Permitir'),
                    ),
                    TextButton(onPressed: onLaterMicrophone, child: const Text('Ahora no')),
                  ],
                ),
                MicrophoneChoice.allowed => const _Answer(
                  icon: Icons.check_circle_rounded,
                  color: AppColors.success,
                  text: 'Micrófono permitido.',
                ),
                MicrophoneChoice.later => const _Answer(
                  icon: Icons.schedule_rounded,
                  color: AppColors.textSecondary,
                  text: 'Sin problema: te lo pido cuando abras el modo voz.',
                ),
              },
            ],
          ),
        ),
        const SizedBox(height: 16),
        OnboardingCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(child: Text('¿Te saludo todos los días?', style: AppText.heading)),
                  Switch(
                    value: remindersOn,
                    activeThumbColor: AppColors.tan,
                    onChanged: onToggleReminders,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Te escribo una vez al día, a la hora que elijas, para charlar un ratito. '
                'Sin culpas ni rachas.',
                style: AppText.body,
              ),
              const SizedBox(height: 12),
              Text(
                'Si dices que no, no pasa nada. Puedes cambiarlo en Ajustes.',
                style: AppText.caption.copyWith(color: AppColors.textSecondary),
              ),
              if (remindersDenied) ...[
                const SizedBox(height: 12),
                const Text(remindersDeniedNotice, style: AppText.bodyStrong),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Answer extends StatelessWidget {
  const _Answer({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: AppText.bodyStrong)),
      ],
    );
  }
}

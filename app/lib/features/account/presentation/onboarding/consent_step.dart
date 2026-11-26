import 'package:flutter/material.dart';

import '../../../../shared/presentation/app_theme.dart';
import 'step_layout.dart';

class ConsentStep extends StatelessWidget {
  const ConsentStep({
    super.key,
    required this.accepted,
    required this.onChanged,
    required this.onContinue,
    required this.onDecline,
  });

  final bool accepted;
  final ValueChanged<bool> onChanged;
  final VoidCallback onContinue;
  final VoidCallback onDecline;

  // Keep this notice in sync with docs/memory.md and MESSAGE_RETENTION_DAYS.
  static const _data = [
    'Guardo tus mensajes 90 días para seguir la conversación.',
    'Guardo datos clave que me cuentes para conocerte. Puedes verlos, editarlos y borrarlos.',
    'Nunca guardo cédula, tarjetas ni diagnósticos.',
    'Puedes eliminar tu cuenta y todo se borra.',
  ];

  @override
  Widget build(BuildContext context) {
    return OnboardingStep(
      actions: [
        // Pin consent next to the button to keep both visible.
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onChanged(!accepted),
          child: Row(
            children: [
              Checkbox(
                value: accepted,
                onChanged: (value) => onChanged(value ?? false),
                activeColor: AppColors.tanDark,
              ),
              const Expanded(
                child: Text(
                  'Entiendo y acepto cómo marlix usa mis datos.',
                  style: AppText.bodyStrong,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        OnboardingButton(label: 'Aceptar y continuar', onPressed: accepted ? onContinue : null),
        TextButton(onPressed: onDecline, child: const Text('No acepto, cerrar sesión')),
      ],
      children: [
        Semantics(header: true, child: const Text('Antes de empezar', style: AppText.title)),
        const SizedBox(height: 16),
        OnboardingCard(
          color: AppColors.warningBackground,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('No soy terapia', style: AppText.heading),
              const SizedBox(height: 8),
              const Text(
                'Soy compañía para conversar. No doy diagnósticos ni reemplazo a un '
                'profesional de la salud.',
                style: AppText.body,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        OnboardingCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tus datos', style: AppText.heading),
              const SizedBox(height: 12),
              for (final line in _data)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 8, right: 12),
                        child: Icon(Icons.circle, size: 8, color: AppColors.tanDark),
                      ),
                      Expanded(child: Text(line, style: AppText.body)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../models/help_resource.dart';
import '../theme/app_theme.dart';

/// Wireframe 03c: the crisis reply stands out from the conversation, with a
/// red accent and the help lines, the primary one first.
class CrisisCard extends StatelessWidget {
  const CrisisCard({super.key, required this.text, required this.resources});

  final String text;
  final List<HelpResource> resources;

  @override
  Widget build(BuildContext context) {
    final ordered = [...resources]..sort((a, b) => (b.primary ? 1 : 0) - (a.primary ? 1 : 0));
    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(20),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(height: 8, color: AppColors.crisis),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: const Text('No estás solo ni sola en esto', style: AppText.heading),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(text, style: AppText.body),
                    const SizedBox(height: 16),
                    for (final resource in ordered) _ResourceLine(resource: resource),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResourceLine extends StatelessWidget {
  const _ResourceLine({required this.resource});

  final HelpResource resource;

  @override
  Widget build(BuildContext context) {
    final color = resource.primary ? AppColors.crisis : AppColors.charcoal;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.phone_rounded, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${resource.name}\n',
                    style: AppText.bodyStrong.copyWith(color: color),
                  ),
                  TextSpan(
                    text: '${formatPhone(resource.phone)} · ${resource.hours}',
                    style: AppText.caption.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// `911` → `9-1-1`; `8002737869` → `800-273-7869`; `22257511` → `2225-7511`.
String formatPhone(String digits) => switch (digits.length) {
  3 => digits.split('').join('-'),
  8 => '${digits.substring(0, 4)}-${digits.substring(4)}',
  10 => '${digits.substring(0, 3)}-${digits.substring(3, 6)}-${digits.substring(6)}',
  _ => digits,
};

/// Wireframe 03d: the day's messages are used up.
class DailyLimitCard extends StatelessWidget {
  const DailyLimitCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border.all(color: AppColors.line, width: 1.5),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              ExcludeSemantics(
                child: CircleAvatar(
                  radius: 56,
                  backgroundColor: AppColors.tanLight,
                  foregroundImage: const AssetImage('assets/avatar/marlix-happy.png'),
                ),
              ),
              const SizedBox(height: 16),
              Semantics(
                header: true,
                child: const Text(
                  'Por hoy llegamos al límite',
                  style: AppText.heading,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Mañana volvemos a conversar: los mensajes se renuevan a medianoche.',
                style: AppText.body,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.support_rounded, color: AppColors.crisis),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'La ayuda sigue disponible',
                      style: AppText.bodyStrong.copyWith(color: AppColors.crisis),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wireframe 03b: the free Render plan sleeps, so the first reply after a
/// pause can take up to a minute.
class WakingUpBanner extends StatelessWidget {
  const WakingUpBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.warningBackground,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppColors.tanDark,
                  backgroundColor: AppColors.tanLight,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'marlix se está despertando… esto puede tardar unos segundos.',
                  style: AppText.caption.copyWith(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Under a message that could not be sent: why, and a way to try again.
class SendFailedNotice extends StatelessWidget {
  const SendFailedNotice({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.end,
          style: AppText.caption.copyWith(color: AppColors.crisis, fontWeight: FontWeight.w700),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.tanDark,
              side: const BorderSide(color: AppColors.tanDark, width: 2),
              textStyle: AppText.button,
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 28),
            ),
            child: const Text('Reintentar'),
          ),
        ],
      ],
    );
  }
}

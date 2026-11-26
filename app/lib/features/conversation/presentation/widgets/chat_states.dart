import 'package:flutter/material.dart';

import '../../../../shared/presentation/app_theme.dart';
import '../../../safety/domain/help_resource.dart';
import '../../../safety/presentation/call_buttons.dart';

class CrisisCard extends StatelessWidget {
  const CrisisCard({
    super.key,
    required this.text,
    required this.resources,
    required this.onMoreHelp,
  });

  final String text;
  final List<HelpResource> resources;
  final VoidCallback onMoreHelp;

  @override
  Widget build(BuildContext context) {
    final primary = resources.where((line) => line.primary).firstOrNull ?? emergencyLine;
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      header: true,
                      child: const Text('No estás solo ni sola en esto', style: AppText.heading),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(text, style: AppText.body),
                    const SizedBox(height: 20),
                    EmergencyCallButton(line: primary),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: onMoreHelp,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.crisis,
                        side: const BorderSide(color: AppColors.crisis, width: 2),
                        textStyle: AppText.button,
                        minimumSize: const Size.fromHeight(52),
                        shape: const StadiumBorder(),
                      ),
                      child: const Text('Ver más ayuda'),
                    ),
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

class DailyLimitCard extends StatelessWidget {
  const DailyLimitCard({super.key, required this.onHelp});

  final VoidCallback onHelp;

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
              TextButton.icon(
                onPressed: onHelp,
                icon: const Icon(Icons.support_rounded),
                label: const Text('La ayuda sigue disponible'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.crisis,
                  textStyle: AppText.bodyStrong,
                  minimumSize: const Size(0, 48),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Explain the delay when the backend is likely waking from idle.
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

class HistoryLoadingNotice extends StatelessWidget {
  const HistoryLoadingNotice({super.key, this.message = 'Cargando mensajes anteriores…'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppColors.tanDark,
                backgroundColor: AppColors.tanLight,
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(message, style: AppText.caption.copyWith(color: AppColors.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }
}

class HistoryFailedNotice extends StatelessWidget {
  const HistoryFailedNotice({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Column(
        children: [
          const Text(
            'No pudimos cargar tus mensajes anteriores. Revisá tu conexión a internet.',
            textAlign: TextAlign.center,
            style: AppText.caption,
          ),
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
      ),
    );
  }
}

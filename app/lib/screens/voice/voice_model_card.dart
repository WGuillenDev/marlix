import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/voice/device_facts.dart';
import '../../theme/app_theme.dart';
import 'voice_controller.dart';

/// Offers the download of the Supertonic voice (401 MB) and shows how it goes.
/// It shows nothing while the voice works: the person only sees it when there is
/// something to decide or to know. Until the model is on the phone, replies are
/// spoken with the phone's own voice.
class VoiceModelCard extends ConsumerWidget {
  const VoiceModelCard({super.key});

  static String megabytes(int bytes) => '${(bytes / 1000000).round()} MB';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(voiceControllerProvider);
    final voice = ref.read(voiceControllerProvider.notifier);

    return switch (status) {
      VoiceNeedsDownload(:final totalBytes, :final connection, :final failure) => _Card(
        title: 'Dale a marlix su voz',
        message:
            'Para que suene más natural hay que descargar su voz (${megabytes(totalBytes)}). '
            'Mientras tanto habla con la voz de tu teléfono.',
        notice: switch ((failure, connection)) {
          (final String reason?, _) => 'Se detuvo la descarga: $reason',
          (_, ConnectionKind.none) => 'No hay conexión a internet.',
          (_, ConnectionKind.mobile) =>
            'Estás con datos móviles: la descarga gasta ${megabytes(totalBytes)} de tu plan.',
          _ => null,
        },
        action: switch (connection) {
          ConnectionKind.mobile => FilledButton(
            onPressed: () => unawaited(voice.download(allowMobileData: true)),
            child: const Text('Descargar con datos móviles'),
          ),
          ConnectionKind.none => null,
          ConnectionKind.unmetered => FilledButton(
            onPressed: () => unawaited(voice.download()),
            child: Text(failure == null ? 'Descargar con wifi' : 'Continuar la descarga'),
          ),
        },
      ),
      VoiceDownloading(:final progress) => _Card(
        title: 'Descargando la voz',
        message:
            '${megabytes(progress.receivedBytes)} de ${megabytes(progress.totalBytes)}. '
            'Puedes seguir conversando: marlix habla con la voz del teléfono.',
        progress: progress.fraction,
      ),
      VoiceUnavailable() => const _Card(
        title: 'Este teléfono no puede hablar',
        message:
            'No tiene una voz en español que funcione. El chat de texto sigue '
            'funcionando igual.',
      ),
      VoiceIdle() || VoiceChecking() || VoiceReady() => const SizedBox.shrink(),
    };
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.title,
    required this.message,
    this.notice,
    this.progress,
    this.action,
  });

  final String title;
  final String message;

  /// Something to know right now: a failure, no connection, mobile data.
  final String? notice;
  final double? progress;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Semantics(
        container: true,
        liveRegion: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.white,
            border: Border.all(color: AppColors.line, width: 1.5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.bodyStrong),
                const SizedBox(height: 4),
                Text(message, style: AppText.caption.copyWith(color: AppColors.textSecondary)),
                if (notice != null) ...[
                  const SizedBox(height: 8),
                  Text(notice!, style: AppText.caption.copyWith(fontWeight: FontWeight.w700)),
                ],
                if (progress != null) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      color: AppColors.tanDark,
                      backgroundColor: AppColors.line,
                    ),
                  ),
                ],
                if (action != null) ...[
                  const SizedBox(height: 12),
                  SizedBox(width: double.infinity, child: action),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

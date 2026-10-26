import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/voice_config.dart';
import '../../services/voice/device_facts.dart';
import '../../services/voice/voice_planner.dart';
import '../../theme/app_theme.dart';
import 'voice_controller.dart';

/// Development screen to hear the avatar's voice and see which engine the phone
/// uses and why (S6-2). Only reachable from Settings in debug builds: voice mode
/// itself arrives in S6-7.
class VoiceTestScreen extends ConsumerStatefulWidget {
  const VoiceTestScreen({super.key});

  static Route<void> route() => MaterialPageRoute(builder: (_) => const VoiceTestScreen());

  @override
  ConsumerState<VoiceTestScreen> createState() => _VoiceTestScreenState();
}

class _VoiceTestScreenState extends ConsumerState<VoiceTestScreen> {
  static const phrases = [
    'Buenas, qué gusto saludarte. ¿Cómo amaneciste hoy?',
    'Uy, cuánto lo siento. Sentirse sola pesa mucho. ¿Querés contarme qué te tiene así?',
    'Qué bonito que hablaste con tu hermana. ¿Y cómo se encuentra ella?',
    'Eso no te lo puedo decir yo, pero lo que sí puedo es escucharte con calma.',
  ];

  StreamSubscription<VoiceEvent>? _speech;
  String? _result;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    // After the first frame: a provider cannot change while the tree builds.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(voiceControllerProvider) is VoiceIdle) {
        unawaited(ref.read(voiceControllerProvider.notifier).start());
      }
    });
  }

  @override
  void dispose() {
    unawaited(_speech?.cancel());
    super.dispose();
  }

  void _speak(String text) {
    final clock = Stopwatch()..start();
    var lastEvent = 0;
    var longestSilence = 0;
    var firstWord = '';
    unawaited(_speech?.cancel());
    setState(() {
      _result = 'Preparando…';
      _progress = 0;
    });
    _speech = ref
        .read(voiceControllerProvider.notifier)
        .speak(text)
        .listen(
          (event) {
            if (!mounted) return;
            // While a sentence plays, progress arrives every 50 ms: a longer
            // gap is silence between two sentences.
            final now = clock.elapsedMilliseconds;
            if (firstWord.isNotEmpty && now - lastEvent > longestSilence) {
              longestSilence = now - lastEvent;
            }
            lastEvent = now;
            switch (event) {
              case VoiceStarted(:final engine):
                firstWord = '${_engineName(engine)}: empezó a hablar en $now ms';
                setState(() => _result = firstWord);
              case VoiceProgress(:final fraction):
                setState(() => _progress = fraction);
              case VoiceLevel():
                break;
              case VoiceFinished():
                setState(() {
                  _progress = 1;
                  _result = '$firstWord. Silencio más largo entre eventos: $longestSilence ms';
                });
            }
          },
          onError: (Object error) {
            if (mounted) setState(() => _result = 'No se pudo hablar: $error');
          },
        );
  }

  static String _engineName(VoiceEngineKind engine) =>
      engine == VoiceEngineKind.supertonic ? 'Supertonic' : 'Voz del teléfono';

  static String _reasonText(NativeReason reason) => switch (reason) {
    NativeReason.configured => 'la configuración del avatar lo pide',
    NativeReason.lowRam => 'el teléfono tiene poca memoria',
    NativeReason.loadFailed => 'el modelo no cargó en este teléfono',
    NativeReason.noSpace => 'no hay espacio para el modelo',
    NativeReason.tooSlow => 'el teléfono es lento para el modelo',
  };

  static String _megabytes(int bytes) => '${(bytes / 1000000).round()} MB';

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(voiceControllerProvider);
    final controller = ref.read(voiceControllerProvider.notifier);
    final config = ref.watch(voiceConfigProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('Probar la voz', style: AppText.title),
        backgroundColor: AppColors.cream,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Configuración: ${config.voice}, ${config.steps} pasos, velocidad ${config.rate}',
              style: AppText.caption,
            ),
            const SizedBox(height: 12),
            Text(switch (status) {
              VoiceIdle() => 'Sin empezar',
              VoiceChecking() => 'Revisando el teléfono…',
              VoiceNeedsDownload(:final totalBytes, :final connection, :final failure) =>
                'Falta el modelo de Supertonic (${_megabytes(totalBytes)}). '
                    '${connection == ConnectionKind.mobile ? 'Estás con datos móviles. ' : ''}'
                    '${connection == ConnectionKind.none ? 'Sin conexión. ' : ''}'
                    '${failure == null ? '' : 'Se detuvo: $failure. '}'
                    'Mientras, habla la voz del teléfono.',
              VoiceDownloading(:final progress) =>
                'Descargando ${_megabytes(progress.receivedBytes)} de ${_megabytes(progress.totalBytes)}',
              VoiceReady(:final engine, :final reason) =>
                '${_engineName(engine)}${reason == null ? '' : ' porque ${_reasonText(reason)}'}',
              VoiceUnavailable() => 'El teléfono no tiene una voz en español que funcione. El chat de texto sigue funcionando.',
            }, style: AppText.bodyStrong),
            const SizedBox(height: 12),
            if (status is VoiceDownloading)
              LinearProgressIndicator(value: status.progress.fraction),
            if (status is VoiceNeedsDownload) ...[
              FilledButton(
                onPressed: () => unawaited(controller.download()),
                child: const Text('Descargar con wifi'),
              ),
              if (status.connection == ConnectionKind.mobile)
                TextButton(
                  onPressed: () => unawaited(controller.download(allowMobileData: true)),
                  child: const Text('Descargar con datos móviles'),
                ),
            ],
            TextButton(
              onPressed: () => unawaited(controller.start()),
              child: const Text('Revisar de nuevo'),
            ),
            const Divider(),
            for (final phrase in phrases)
              ListTile(
                title: Text(phrase, style: AppText.body),
                trailing: const Icon(Icons.volume_up),
                onTap: () => _speak(phrase),
              ),
            const SizedBox(height: 8),
            if (_result != null) Text(_result!, style: AppText.bodyStrong),
            LinearProgressIndicator(value: _progress),
            TextButton(onPressed: () => unawaited(controller.stop()), child: const Text('Parar')),
          ],
        ),
      ),
    );
  }
}

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../bootstrap/api_providers.dart';
import '../../../bootstrap/storage_providers.dart';
import '../application/device_facts.dart';
import '../application/speech_recognizer.dart';
import '../application/voice_engine.dart';
import '../application/voice_memory.dart';
import '../application/voice_model.dart';
import '../domain/voice_config.dart';
import '../infrastructure/audio_capture.dart';
import '../infrastructure/call_audio_player.dart';
import '../infrastructure/device_facts.dart';
import '../infrastructure/native_voice_engine.dart';
import '../infrastructure/server_speech_recognizer.dart';
import '../infrastructure/silero_voice_activity.dart';
import '../infrastructure/supertonic_voice_engine.dart';
import '../infrastructure/voice_memory.dart';
import '../infrastructure/voice_model_store.dart';

final voiceModelManifestProvider = Provider<VoiceModelManifest>(
  (ref) => throw UnimplementedError('voiceModelManifestProvider must be overridden'),
);

final voiceModelDirectoryProvider = Provider<Directory>(
  (ref) => throw UnimplementedError('voiceModelDirectoryProvider must be overridden'),
);

final deviceFactsProvider = Provider<DeviceFacts>((ref) => const AndroidDeviceFacts());

final voiceMemoryProvider = Provider<VoiceMemory>(
  (ref) => LocalVoiceMemory(ref.watch(preferencesProvider)),
);

final voiceModelProvider = Provider<VoiceModel>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return VoiceModelStore(
    manifest: ref.watch(voiceModelManifestProvider),
    directory: ref.watch(voiceModelDirectoryProvider),
    client: client,
  );
});

final callRouteProvider = Provider<CallRoute>((ref) => CallRoute());

final supertonicEngineFactoryProvider =
    Provider<MeasurableVoiceEngine Function(VoiceConfig config)>((ref) {
      final route = ref.watch(callRouteProvider);
      return (config) => SupertonicVoiceEngine(
        config: config,
        player: CallAudioPlayer(route: route),
      );
    });

final speechRecognizerProvider = Provider<SpeechRecognizer>((ref) {
  final activity = SileroVoiceActivity();
  final recognizer = ServerSpeechRecognizer(
    capture: RecordAudioCapture(),
    activity: activity,
    transcribe: ref.watch(transcriptionGatewayProvider).transcribe,
  );
  ref.onDispose(() async {
    await recognizer.cancel();
    await activity.dispose();
  });
  return recognizer;
});

final nativeEngineFactoryProvider = Provider<VoiceEngine Function(VoiceConfig config)>(
  (ref) =>
      (config) => NativeVoiceEngine(config: config.fallback, language: config.language),
);

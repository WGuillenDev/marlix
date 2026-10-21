import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../help_resources.dart';
import 'device_facts.dart';
import 'native_voice_engine.dart';
import 'supertonic_voice_engine.dart';
import 'voice_engine.dart';
import 'voice_memory.dart';
import 'voice_model_store.dart';
import '../../models/voice_config.dart';

/// Overridden in `main` with `assets/config/voice-model.json`, and in tests.
final voiceModelManifestProvider = Provider<VoiceModelManifest>(
  (ref) => throw UnimplementedError('voiceModelManifestProvider must be overridden'),
);

/// Overridden in `main` with the folder where the Supertonic package looks for
/// the model, which needs an async lookup, and in tests with a temporary one.
final voiceModelDirectoryProvider = Provider<Directory>(
  (ref) => throw UnimplementedError('voiceModelDirectoryProvider must be overridden'),
);

final deviceFactsProvider = Provider<DeviceFacts>((ref) => const AndroidDeviceFacts());

final voiceMemoryProvider = Provider<VoiceMemory>(
  (ref) => VoiceMemory(ref.watch(sharedPreferencesProvider)),
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

/// The engines are created through these, so a test hands over fakes and the
/// screens never name an engine.
final supertonicEngineFactoryProvider =
    Provider<MeasurableVoiceEngine Function(VoiceConfig config)>(
      (ref) =>
          (config) => SupertonicVoiceEngine(config: config),
    );

final nativeEngineFactoryProvider = Provider<VoiceEngine Function(VoiceConfig config)>(
  (ref) =>
      (config) => NativeVoiceEngine(config: config.fallback, language: config.language),
);

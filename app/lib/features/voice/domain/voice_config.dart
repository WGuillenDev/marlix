import '../../../shared/json_reader.dart';

enum VoiceEngineKind { supertonic, native }

class NativeVoiceConfig {
  const NativeVoiceConfig({required this.voice, required this.pitch, required this.rate});

  factory NativeVoiceConfig.fromJson(Map<String, Object?> json) => NativeVoiceConfig(
    voice: json.requireString('voice'),
    pitch: json.requireNumber('pitch'),
    rate: json.requireNumber('rate'),
  );

  /// The default voice is selected by the device.
  final String voice;
  final double pitch;
  final double rate;

  @override
  bool operator ==(Object other) =>
      other is NativeVoiceConfig &&
      other.voice == voice &&
      other.pitch == pitch &&
      other.rate == rate;

  @override
  int get hashCode => Object.hash(voice, pitch, rate);
}

class VoiceConfig {
  const VoiceConfig({
    required this.engine,
    required this.voice,
    required this.language,
    required this.steps,
    required this.rate,
    required this.fallback,
  });

  static const defaults = VoiceConfig(
    engine: VoiceEngineKind.supertonic,
    voice: 'F4',
    language: 'es',
    steps: 5,
    rate: 1.05,
    fallback: NativeVoiceConfig(voice: 'default', pitch: 1, rate: 1),
  );

  /// Return null for unrecognized settings so the profile can use defaults.
  static VoiceConfig? tryParse(Object? json) {
    if (json is! Map<String, Object?>) return null;
    try {
      final engine = switch (json.requireString('engine')) {
        'supertonic-3' => VoiceEngineKind.supertonic,
        'native' => VoiceEngineKind.native,
        _ => throw const InvalidJsonException('unknown engine'),
      };
      final steps = json.requireNumber('steps');
      if (steps < 1 || steps != steps.roundToDouble()) {
        throw const InvalidJsonException('steps must be a positive whole number');
      }
      return VoiceConfig(
        engine: engine,
        voice: json.requireString('voice'),
        language: json.requireString('language'),
        steps: steps.round(),
        rate: json.requireNumber('rate'),
        fallback: NativeVoiceConfig.fromJson(json.requireObject('fallback')),
      );
    } on InvalidJsonException {
      return null;
    }
  }

  final VoiceEngineKind engine;

  final String voice;
  final String language;

  final int steps;

  /// 1.0 is the model's natural pace.
  final double rate;
  final NativeVoiceConfig fallback;

  // Stable equality prevents a profile refresh from restarting playback.
  @override
  bool operator ==(Object other) =>
      other is VoiceConfig &&
      other.engine == engine &&
      other.voice == voice &&
      other.language == language &&
      other.steps == steps &&
      other.rate == rate &&
      other.fallback == fallback;

  @override
  int get hashCode => Object.hash(engine, voice, language, steps, rate, fallback);
}

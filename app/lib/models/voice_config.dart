import 'json_reader.dart';

/// Which engine makes the avatar speak.
enum VoiceEngineKind { supertonic, native }

/// How the phone's own voice speaks, used when Supertonic cannot run.
class NativeVoiceConfig {
  const NativeVoiceConfig({required this.voice, required this.pitch, required this.rate});

  factory NativeVoiceConfig.fromJson(Map<String, Object?> json) => NativeVoiceConfig(
    voice: json.requireString('voice'),
    pitch: json.requireNumber('pitch'),
    rate: json.requireNumber('rate'),
  );

  /// `default` leaves the choice to the phone.
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

/// The avatar's `voice_config` (docs/api-contract.md, `GET /v1/me`). It lives in
/// the database so a new avatar brings its own voice without a new release.
class VoiceConfig {
  const VoiceConfig({
    required this.engine,
    required this.voice,
    required this.language,
    required this.steps,
    required this.rate,
    required this.fallback,
  });

  /// What marlix uses when the backend sends nothing or something the app does
  /// not understand (an older backend, a newer shape): the S6-1 decision.
  static const defaults = VoiceConfig(
    engine: VoiceEngineKind.supertonic,
    voice: 'F4',
    language: 'es',
    steps: 5,
    rate: 1.05,
    fallback: NativeVoiceConfig(voice: 'default', pitch: 1, rate: 1),
  );

  /// Null when [json] is not a voice configuration, so the caller keeps the
  /// defaults instead of failing the whole profile over a voice detail.
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

  /// The Supertonic voice, such as `F4`.
  final String voice;
  final String language;

  /// Supertonic's denoising steps: fewer is faster and less natural.
  final int steps;

  /// Supertonic's speed; 1 is the model's natural pace.
  final double rate;
  final NativeVoiceConfig fallback;

  /// So reloading the profile does not restart the voice when nothing changed.
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

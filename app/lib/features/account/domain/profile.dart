import '../../../shared/json_reader.dart';
import '../../voice/domain/voice_config.dart';

class Profile {
  const Profile({
    required this.id,
    required this.avatarSlug,
    this.avatarLayersPath,
    this.avatarVoiceConfig,
    required this.onboardingCompleted,
    required this.remindersEnabled,
  });

  factory Profile.fromJson(Map<String, Object?> json) => Profile(
    id: json.requireString('id'),
    avatarSlug: json.requireObject('avatar').requireString('slug'),
    avatarLayersPath: json.requireObject('avatar').optionalString('layersPath'),
    avatarVoiceConfig: VoiceConfig.tryParse(json.requireObject('avatar')['voiceConfig']),
    onboardingCompleted: json.requireBool('onboardingCompleted'),
    remindersEnabled: json.requireObject('settings').requireBool('remindersEnabled'),
  );

  final String id;

  final String avatarSlug;

  final String? avatarLayersPath;

  /// Missing or unrecognized settings let the app use its default voice.
  final VoiceConfig? avatarVoiceConfig;

  final bool onboardingCompleted;

  final bool remindersEnabled;
}

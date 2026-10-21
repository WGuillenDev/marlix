import 'json_reader.dart';
import 'voice_config.dart';

/// Response of `GET /v1/me` and `POST /v1/onboarding`.
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

  /// Which avatar the user is tied to; there is one in v1.
  final String avatarSlug;

  /// Asset folder of the avatar's layers; null if the backend did not send it.
  final String? avatarLayersPath;

  /// How the avatar speaks; null if the backend did not send it or the app does
  /// not understand it, and then [VoiceConfig.defaults] applies.
  final VoiceConfig? avatarVoiceConfig;

  /// False until the user accepted the consent and finished onboarding.
  final bool onboardingCompleted;

  final bool remindersEnabled;
}

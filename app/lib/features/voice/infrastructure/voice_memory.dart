import 'dart:convert';

import '../../../shared/application/preferences.dart';
import '../application/voice_memory.dart';

/// Key model health and speed measurements by revision.
class LocalVoiceMemory implements VoiceMemory {
  const LocalVoiceMemory(this._preferences);

  final Preferences _preferences;

  static const _loadingKey = 'voice_loading_revision';
  static const _failedKey = 'voice_failed_revision';
  static const _speedKey = 'voice_speed';

  /// An unfinished load marks a revision that may have crashed the app.
  @override
  String? get loadStarted => _preferences.getString(_loadingKey);

  @override
  Future<void> beginLoad(String revision) => _preferences.setString(_loadingKey, revision);

  @override
  Future<void> endLoad() => _preferences.remove(_loadingKey);

  @override
  bool failed(String revision) => _preferences.getString(_failedKey) == revision;

  @override
  Future<void> markFailed(String revision) => _preferences.setString(_failedKey, revision);

  @override
  double? speed(String key) {
    final saved = _preferences.getString(_speedKey);
    if (saved == null) return null;
    try {
      final json = jsonDecode(saved);
      if (json is Map<String, Object?> && json['key'] == key && json['ratio'] is num) {
        return (json['ratio']! as num).toDouble();
      }
    } on FormatException {
      // Ignore a corrupt measurement so the model is benchmarked again.
    }
    return null;
  }

  @override
  Future<void> saveSpeed(String key, double ratio) =>
      _preferences.setString(_speedKey, jsonEncode({'key': key, 'ratio': ratio}));
}

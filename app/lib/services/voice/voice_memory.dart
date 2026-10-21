import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// What the app remembers about how the voice behaved on this phone, so it does
/// not try again what already failed. Everything is tied to the model
/// revision: a new model gets a new chance.
class VoiceMemory {
  const VoiceMemory(this._preferences);

  final SharedPreferences _preferences;

  static const _loadingKey = 'voice_loading_revision';
  static const _failedKey = 'voice_failed_revision';
  static const _speedKey = 'voice_speed';

  /// The revision whose load started and never finished: the app was killed
  /// while loading it, which is what a phone without enough memory does.
  String? get loadStarted => _preferences.getString(_loadingKey);

  Future<void> beginLoad(String revision) => _preferences.setString(_loadingKey, revision);

  Future<void> endLoad() => _preferences.remove(_loadingKey);

  /// True when this phone could not run the model of [revision].
  bool failed(String revision) => _preferences.getString(_failedKey) == revision;

  Future<void> markFailed(String revision) => _preferences.setString(_failedKey, revision);

  /// Seconds of audio per second of work measured for [key], or null.
  double? speed(String key) {
    final saved = _preferences.getString(_speedKey);
    if (saved == null) return null;
    try {
      final json = jsonDecode(saved);
      if (json is Map<String, Object?> && json['key'] == key && json['ratio'] is num) {
        return (json['ratio']! as num).toDouble();
      }
    } on FormatException {
      // A corrupt value is measured again.
    }
    return null;
  }

  Future<void> saveSpeed(String key, double ratio) =>
      _preferences.setString(_speedKey, jsonEncode({'key': key, 'ratio': ratio}));
}

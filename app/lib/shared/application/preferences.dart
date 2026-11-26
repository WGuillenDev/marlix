abstract interface class Preferences {
  bool? getBool(String key);
  String? getString(String key);
  Future<bool> setBool(String key, bool value);
  Future<bool> setString(String key, String value);
  Future<bool> remove(String key);
}

import 'package:shared_preferences/shared_preferences.dart';

import '../../application/preferences.dart';

class LocalPreferences implements Preferences {
  const LocalPreferences(this._store);

  final SharedPreferences _store;

  @override
  bool? getBool(String key) => _store.getBool(key);

  @override
  String? getString(String key) => _store.getString(key);

  @override
  Future<bool> setBool(String key, bool value) => _store.setBool(key, value);

  @override
  Future<bool> setString(String key, String value) => _store.setString(key, value);

  @override
  Future<bool> remove(String key) => _store.remove(key);
}

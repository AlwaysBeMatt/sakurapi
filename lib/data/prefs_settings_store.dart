import 'package:shared_preferences/shared_preferences.dart';

import '../state/settings.dart';

class PrefsSettingsStore implements SettingsStore {
  PrefsSettingsStore(this._prefs);

  final SharedPreferences _prefs;

  @override
  String? getString(String key) => _prefs.getString(key);

  @override
  int? getInt(String key) => _prefs.getInt(key);

  @override
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);

  @override
  Future<void> setInt(String key, int value) => _prefs.setInt(key, value);
}
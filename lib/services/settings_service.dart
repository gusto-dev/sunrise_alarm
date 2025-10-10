import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _tzOverrideKey = 'tz_override';
  static const _timeFormat24hKey = 'time_format_24h'; // bool
  static const _languageOverrideKey = 'language_override'; // 'system'|'ko'|'en'
  static const _themeModeKey = 'theme_mode_pref'; // 'auto'|'light'|'dark'

  static Future<String?> getTzOverride() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tzOverrideKey);
  }

  static Future<void> setTzOverride(String? ianaId) async {
    final prefs = await SharedPreferences.getInstance();
    if (ianaId == null) {
      await prefs.remove(_tzOverrideKey);
    } else {
      await prefs.setString(_tzOverrideKey, ianaId);
    }
  }

  // Time format
  static Future<bool> getTimeFormat24h() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_timeFormat24hKey) ?? true; // default 24h
  }

  static Future<void> setTimeFormat24h(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_timeFormat24hKey, value);
  }

  // Language override
  static Future<String> getLanguageOverride() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_languageOverrideKey) ?? 'system';
  }

  static Future<void> setLanguageOverride(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageOverrideKey, value);
  }

  // Theme mode preference
  static Future<String> getThemeModePref() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_themeModeKey) ?? 'auto';
  }

  static Future<void> setThemeModePref(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, value);
  }
}

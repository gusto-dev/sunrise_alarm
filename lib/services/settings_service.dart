import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _tzOverrideKey = 'tz_override';
  static const _timeFormat24hKey = 'time_format_24h'; // bool
  static const _languageOverrideKey = 'language_override'; // 'system'|'ko'|'en'
  static const _themeModeKey = 'theme_mode_pref'; // 'auto'|'light'|'dark'
  static const _notifSoundKey =
      'notif_sound'; // 'default'|'soft'|'loud'|'good_morning'|'wake_up'|'morning_triumph'
  static const _notifVibrationKey =
      'notif_vibration'; // 'off'|'short'|'long'|'pattern'

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

  // Notification sound
  static Future<String> getNotificationSound() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_notifSoundKey);
    const allowed = {'default', 'good_morning', 'wake_up', 'morning_triumph'};
    if (v == null || !allowed.contains(v)) {
      // Migrate legacy/invalid values like 'soft'/'loud' to 'default'
      return 'default';
    }
    return v;
  }

  static Future<void> setNotificationSound(String value) async {
    final prefs = await SharedPreferences.getInstance();
    const allowed = {'default', 'good_morning', 'wake_up', 'morning_triumph'};
    final v = allowed.contains(value) ? value : 'default';
    await prefs.setString(_notifSoundKey, v);
  }

  // Notification vibration pattern
  static Future<String> getVibrationPattern() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_notifVibrationKey) ?? 'short';
    const allowed = {'off', 'short', 'long'};
    if (!allowed.contains(v)) return 'short';
    return v;
  }

  static Future<void> setVibrationPattern(String value) async {
    final prefs = await SharedPreferences.getInstance();
    const allowed = {'off', 'short', 'long'};
    final v = allowed.contains(value) ? value : 'short';
    await prefs.setString(_notifVibrationKey, v);
  }
}

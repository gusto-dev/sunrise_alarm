import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _tzOverrideKey = 'tz_override';

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
}

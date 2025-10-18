import 'package:shared_preferences/shared_preferences.dart';

class RepeatPrefs {
  static const _enabledKey = 'repeat_enabled_v1';
  static const _offsetKey = 'repeat_offset_minutes_v1';
  static const _latKey = 'repeat_lat_v1';
  static const _lonKey = 'repeat_lon_v1';
  static const _tzKey = 'repeat_tz_v1';
  static const _horizonDaysKey = 'repeat_horizon_days_v1';

  static Future<void> save({
    required bool enabled,
    required int offsetMinutes,
    required double lat,
    required double lon,
    required String tzName,
    int horizonDays = 30,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_enabledKey, enabled);
    await p.setInt(_offsetKey, offsetMinutes);
    await p.setDouble(_latKey, lat);
    await p.setDouble(_lonKey, lon);
    await p.setString(_tzKey, tzName);
    await p.setInt(_horizonDaysKey, horizonDays);
  }

  static Future<void> disable() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_enabledKey, false);
  }

  static Future<bool> isEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_enabledKey) ?? false;
  }

  static Future<int> offsetMinutes() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_offsetKey) ?? 0;
  }

  static Future<(double?, double?)> coords() async {
    final p = await SharedPreferences.getInstance();
    final lat = p.getDouble(_latKey);
    final lon = p.getDouble(_lonKey);
    return (lat, lon);
  }

  static Future<String?> tzName() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_tzKey);
  }

  static Future<int> horizonDays() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_horizonDaysKey) ?? 30;
  }
}

import 'package:shared_preferences/shared_preferences.dart';

class RepeatPrefs {
  static const _enabledKey = 'repeat_enabled_v1';
  static const _offsetKey = 'repeat_offset_minutes_v1';
  static const _latKey = 'repeat_lat_v1';
  static const _lonKey = 'repeat_lon_v1';
  static const _tzKey = 'repeat_tz_v1';
  static const _horizonDaysKey = 'repeat_horizon_days_v1';
  static const _genKey = 'repeat_generation_v1';
  static const _pauseUntilKey = 'repeat_pause_until_ms_v1';

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
    // Clear any pause window when re-saving enabled repeat
    await p.remove(_pauseUntilKey);
    await _bumpGeneration(p);
  }

  static Future<void> disable() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_enabledKey, false);
    // Clear sensitive fields so any in-flight worker cannot schedule
    await p.remove(_latKey);
    await p.remove(_lonKey);
    await p.remove(_tzKey);
    await p.remove(_horizonDaysKey);
    // Set a short pause window to avoid immediate re-scheduling by any in-flight worker
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await p.setInt(_pauseUntilKey, nowMs + const Duration(minutes: 2).inMilliseconds);
    await _bumpGeneration(p);
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

  static Future<int> generation() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_genKey) ?? 0;
  }

  static Future<bool> isPausedNow() async {
    final p = await SharedPreferences.getInstance();
    final until = p.getInt(_pauseUntilKey) ?? 0;
    if (until <= 0) return false;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    return nowMs < until;
  }

  static Future<void> _bumpGeneration(SharedPreferences p) async {
    final cur = p.getInt(_genKey) ?? 0;
    await p.setInt(_genKey, cur + 1);
  }
}

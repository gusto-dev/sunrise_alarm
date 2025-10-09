import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:timezone/timezone.dart' as tz;

/// sunrise-sunset.org API로 (UTC) 일출 시각을 가져옵니다.
/// date는 "그 날짜의 일출"을 의미합니다(보통 내일 날짜를 넣습니다).
class SunriseService {
  static Future<DateTime> fetchSunriseUtc(
    double lat,
    double lon,
    DateTime date,
  ) async {
    // 날짜를 UTC 기준 YYYY-MM-DD 문자열로 변환
    final d = DateTime.utc(
      date.year,
      date.month,
      date.day,
    ).toIso8601String().split('T').first;

    final url = Uri.parse(
      'https://api.sunrise-sunset.org/json?lat=$lat&lng=$lon&date=$d&formatted=0',
    );

    // 네트워크 타임아웃(8초) 적용
    final res = await http.get(url).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw Exception('Sunrise API error: ${res.statusCode}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (data['status'] != 'OK') {
      throw Exception('Sunrise API response not OK: ${data['status']}');
    }

    final iso = (data['results'] as Map<String, dynamic>)['sunrise'] as String;
    // API는 ISO8601(UTC)을 반환하므로 그대로 UTC로 파싱
    return DateTime.parse(iso).toUtc();
  }

  /// 오늘/내일 일출을 조회해서 '현재 시각(UTC)' 이후 가장 가까운 일출(UTC)을 반환합니다.
  static Future<DateTime> fetchNextSunriseUtc(double lat, double lon) async {
    final nowUtc = DateTime.now().toUtc();
    final today = DateTime.now();
    final tomorrow = today.add(const Duration(days: 1));

    DateTime? sToday;
    try {
      sToday = await fetchSunriseUtc(lat, lon, today);
    } catch (_) {
      // 무시하고 내일 값으로 대체
    }
    final sTomorrow = await fetchSunriseUtc(lat, lon, tomorrow);

    final candidates = [
      sToday,
      sTomorrow,
    ].where((e) => e != null).cast<DateTime>().toList()..sort();

    for (final t in candidates) {
      if (t.isAfter(nowUtc)) return t;
    }
    // 모두 과거라면 가장 가까운 미래 후보(보통 내일)를 반환
    return sTomorrow;
  }

  /// 주어진 위치의 '해당 위치 현지 날짜'를 기준으로 오늘/내일 일출을 조회해,
  /// '현재 시각(UTC)' 이후 가장 가까운 일출(UTC)을 반환합니다.
  ///
  /// 위치가 다른 타임존에 있을 때 기기 타임존과의 날짜 차이로 인한 오차를 방지합니다.
  static Future<DateTime> fetchNextSunriseUtcForLocation(
    double lat,
    double lon,
    tz.Location loc,
  ) async {
    final nowUtc = DateTime.now().toUtc();
    final nowLocal = tz.TZDateTime.now(loc);
    final todayLocal = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
    final tomorrowLocal = todayLocal.add(const Duration(days: 1));

    DateTime? sToday;
    try {
      sToday = await fetchSunriseUtc(lat, lon, todayLocal);
    } catch (_) {
      // 무시하고 내일 값으로 대체
    }
    final sTomorrow = await fetchSunriseUtc(lat, lon, tomorrowLocal);

    final candidates = [
      sToday,
      sTomorrow,
    ].where((e) => e != null).cast<DateTime>().toList()..sort();

    for (final t in candidates) {
      if (t.isAfter(nowUtc)) return t;
    }
    return sTomorrow;
  }
}

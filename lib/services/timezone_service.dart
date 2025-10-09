import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

class TimeZoneService {
  /// Fetches an IANA timezone ID for the given coordinates.
  /// Returns null on failure.
  static Future<String?> fetchTimeZoneId(double lat, double lon) async {
    final uri = Uri.parse(
      'https://timeapi.io/api/TimeZone/coordinate?latitude=$lat&longitude=$lon',
    );
    try {
      final resp = await http.get(uri).timeout(const Duration(seconds: 6));
      if (resp.statusCode < 200 || resp.statusCode >= 300) return null;
      final data = jsonDecode(resp.body);
      if (data is Map) {
        // Common keys: timeZone, timezone, ianaTimeZone
        for (final key in const [
          'timeZone',
          'timezone',
          'ianaTimeZone',
          'iana',
          'id',
          'time_zone',
        ]) {
          final v = data[key];
          if (v is String && v.contains('/')) return v;
        }
        // Try nested 'data' object fallback
        final nested = data['data'];
        if (nested is Map) {
          for (final key in const ['timeZone', 'timezone', 'ianaTimeZone']) {
            final v = nested[key];
            if (v is String && v.contains('/')) return v;
          }
        }
      }
      return null;
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
    }
  }
}

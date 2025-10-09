import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../main.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ScheduledAlarm {
  final int id;
  // Store as UTC instant to avoid timezone drift across loads
  final DateTime scheduled; // UTC instant
  final String tzName; // IANA timezone used to schedule
  final String? title;
  final String? body;

  ScheduledAlarm({
    required this.id,
    required DateTime scheduled,
    required this.tzName,
    this.title,
    this.body,
  }) : scheduled = scheduled.toUtc();

  Map<String, dynamic> toJson() => {
    'id': id,
    'epochMsUtc': scheduled.toUtc().millisecondsSinceEpoch,
    'tzName': tzName,
    'title': title,
    'body': body,
  };

  static ScheduledAlarm fromJson(Map<String, dynamic> j) {
    final id = j['id'] as int;
    final tzName = j['tzName'] as String;
    final title = j['title'] as String?;
    final body = j['body'] as String?;

    if (j.containsKey('epochMsUtc')) {
      final ms = (j['epochMsUtc'] as num).toInt();
      return ScheduledAlarm(
        id: id,
        scheduled: DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true),
        tzName: tzName,
        title: title,
        body: body,
      );
    }

    // Backward compatibility: previously stored ISO string without timezone
    final iso = j['scheduled'] as String?;
    if (iso != null) {
      final dt = DateTime.parse(iso);
      // Interpret as wall time in tzName
      try {
        final loc = tz.getLocation(tzName);
        final wall = tz.TZDateTime(
          loc,
          dt.year,
          dt.month,
          dt.day,
          dt.hour,
          dt.minute,
          dt.second,
          dt.millisecond,
          dt.microsecond,
        );
        return ScheduledAlarm(
          id: id,
          scheduled: wall.toUtc(),
          tzName: tzName,
          title: title,
          body: body,
        );
      } catch (_) {
        return ScheduledAlarm(
          id: id,
          scheduled: dt.toUtc(),
          tzName: tzName,
          title: title,
          body: body,
        );
      }
    }

    return ScheduledAlarm(
      id: id,
      scheduled: DateTime.now().toUtc(),
      tzName: tzName,
      title: title,
      body: body,
    );
  }
}

class AlarmService {
  static const String _prefsKeyList = 'scheduled_alarms_v1';
  static const String _prefsKeyLastId = 'scheduled_alarms_last_id_v1';

  // Back-compat single ID (still used by some debug helpers)
  static const int _id = 2025;

  static Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  static Future<int> _nextId() async {
    final p = await _prefs();
    final last = p.getInt(_prefsKeyLastId) ?? 3000;
    final next = last + 1;
    await p.setInt(_prefsKeyLastId, next);
    return next;
  }

  static Future<List<ScheduledAlarm>> list() async {
    final p = await _prefs();
    final raw = p.getString(_prefsKeyList);
    if (raw == null || raw.isEmpty) return [];
    try {
      final arr = jsonDecode(raw) as List<dynamic>;
      return arr
          .map((e) => ScheduledAlarm.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.scheduled.compareTo(b.scheduled));
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveList(List<ScheduledAlarm> items) async {
    final p = await _prefs();
    final raw = jsonEncode(items.map((e) => e.toJson()).toList());
    await p.setString(_prefsKeyList, raw);
  }

  /// 지정된 시간(localTime)에 알람 예약
  static Future<void> scheduleAt(DateTime localTime) async {
    var tzTime = tz.TZDateTime.from(localTime, tz.local);
    final now = tz.TZDateTime.now(tz.local);
    if (!tzTime.isAfter(now)) {
      // 최소 2초 뒤로 보정
      tzTime = now.add(const Duration(seconds: 2));
    }

    await notifications.zonedSchedule(
      _id,
      '일출 알람',
      '좋은 하루 시작해요 ☀️',
      tzTime,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'sunrise_channel_v2',
          'Sunrise',
          channelDescription: 'Sunrise alarms',
          priority: Priority.high,
          importance: Importance.max,
          fullScreenIntent: true, // 화면을 깨우도록
          category: AndroidNotificationCategory.alarm,
          sound: const RawResourceAndroidNotificationSound('alarm'),
        ),
        // iOS에서 기본 사운드 사용. 별도 사운드 파일 추가 시 sound 지정.
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: 'sunrise',
    );

    // Persist/Upsert legacy alarm into list
    final items = await list();
    items.removeWhere((e) => e.id == _id);
    items.add(
      ScheduledAlarm(
        id: _id,
        scheduled: tzTime.toUtc(),
        tzName: tz.local.name,
        title: '일출 알람',
        body: '좋은 하루 시작해요 ☀️',
      ),
    );
    await _saveList(items);
  }

  /// 여러 개 알람 지원: 고유 ID를 생성해 해당 시간대로 예약하고 저장소에 기록한다.
  static Future<int> scheduleNew(
    DateTime localTime, {
    tz.Location? location,
    String title = '일출 알람',
    String body = '좋은 하루 시작해요 ☀️',
  }) async {
    final id = await _nextId();
    final loc = location ?? tz.local;

    var tzTime = tz.TZDateTime.from(localTime, loc);
    final now = tz.TZDateTime.now(loc);
    if (!tzTime.isAfter(now)) {
      tzTime = now.add(const Duration(seconds: 2));
    }

    await notifications.zonedSchedule(
      id,
      title,
      body,
      tzTime,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'sunrise_channel_v2',
          'Sunrise',
          channelDescription: 'Sunrise alarms',
          priority: Priority.high,
          importance: Importance.max,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.alarm,
          sound: const RawResourceAndroidNotificationSound('alarm'),
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: 'sunrise',
    );

    final items = await list();
    items.add(
      ScheduledAlarm(
        id: id,
        scheduled: tzTime.toUtc(),
        tzName: loc.name,
        title: title,
        body: body,
      ),
    );
    await _saveList(items);
    return id;
  }

  /// 지정된 시간([localTime])을 주어진 [location] 시간대로 해석하여 예약
  static Future<void> scheduleAtZoned(
    DateTime localTime,
    tz.Location location,
  ) async {
    var tzTime = tz.TZDateTime.from(localTime, location);
    final now = tz.TZDateTime.now(location);
    if (!tzTime.isAfter(now)) {
      tzTime = now.add(const Duration(seconds: 2));
    }

    await notifications.zonedSchedule(
      _id,
      '일출 알람',
      '좋은 하루 시작해요 ☀️',
      tzTime,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'sunrise_channel_v2',
          'Sunrise',
          channelDescription: 'Sunrise alarms',
          priority: Priority.high,
          importance: Importance.max,
          fullScreenIntent: true, // 화면을 깨우도록
          category: AndroidNotificationCategory.alarm,
          sound: const RawResourceAndroidNotificationSound('alarm'),
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: 'sunrise',
    );

    // Persist/Upsert legacy alarm into list
    final items = await list();
    items.removeWhere((e) => e.id == _id);
    items.add(
      ScheduledAlarm(
        id: _id,
        scheduled: tzTime.toUtc(),
        tzName: location.name,
        title: '일출 알람',
        body: '좋은 하루 시작해요 ☀️',
      ),
    );
    await _saveList(items);
  }

  /// 기존 단일 알람 취소 (레거시)
  static Future<void> cancel() async {
    await notifications.cancel(_id);
    final items = await list();
    items.removeWhere((e) => e.id == _id);
    await _saveList(items);
  }

  /// 특정 ID 알람 취소 및 저장 목록 갱신
  static Future<void> cancelById(int id) async {
    await notifications.cancel(id);
    final items = await list();
    items.removeWhere((e) => e.id == id);
    await _saveList(items);
  }

  /// 모든 알람 취소 및 저장 목록 비우기
  static Future<void> cancelAll() async {
    await notifications.cancelAll();
    await _saveList([]);
  }

  /// [진단] 즉시 알림 표시 (채널/권한 문제 점검용)
  static Future<void> debugShowNow() async {
    await notifications.show(
      _id,
      '테스트 알림',
      '채널/권한 동작 확인',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'sunrise_channel_v2',
          'Sunrise',
          channelDescription: 'Sunrise alarms',
          priority: Priority.high,
          importance: Importance.max,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.alarm,
          sound: const RawResourceAndroidNotificationSound('alarm'),
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: 'debug',
    );
  }

  /// [진단] 예약된 알림 개수 조회
  static Future<int> pendingCount() async {
    final list = await notifications.pendingNotificationRequests();
    return list.length;
  }
}

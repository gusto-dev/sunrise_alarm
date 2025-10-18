import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'settings_service.dart';
import 'dart:typed_data';
import 'foreground_alarm_overlay.dart';
import 'sunrise_service.dart';

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
  // If you add custom iOS notification sounds to the iOS app bundle
  // (Runner target), set this to true and ensure file names match the
  // mapping in _iosSoundFileName(). Recommended formats: .aiff/.caf, <30s.
  static const bool kIosCustomSoundsAvailable = false;
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

  static Future<String> _ensureAndroidChannelForSettings() async {
    final lang =
        appLocale.value?.languageCode ??
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    final channelName = (lang == 'ko') ? '일출 알람' : 'Sunrise Alarm';
    final channelDesc = (lang == 'ko')
        ? '일출 알림'
        : 'Sunrise alarm notifications';

    final soundKey = await SettingsService.getNotificationSound();
    final channelId = 'sunrise_channel_${lang}_$soundKey';

    final androidImpl = notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidImpl != null) {
      try {
        final AndroidNotificationSound? chSound = soundKey == 'default'
            ? null
            : RawResourceAndroidNotificationSound(soundKey);
        await androidImpl.createNotificationChannel(
          AndroidNotificationChannel(
            channelId,
            channelName,
            description: channelDesc,
            importance: Importance.max,
            playSound: true,
            sound: chSound,
            // Keep vibration enabled; pattern can be set per-notification
            enableVibration: true,
          ),
        );
      } catch (e) {
        if (_isInvalidSoundError(e)) {
          // reset to default and create default channel
          await SettingsService.setNotificationSound('default');
          final fallbackId = 'sunrise_channel_${lang}_default';
          await androidImpl.createNotificationChannel(
            AndroidNotificationChannel(
              fallbackId,
              channelName,
              description: channelDesc,
              importance: Importance.max,
              playSound: true,
            ),
          );
          return fallbackId;
        }
        rethrow;
      }
    }
    return channelId;
  }

  static Future<NotificationDetails> _buildDetails({
    bool forceDefaultSound = false,
  }) async {
    // Ensure a channel exists that matches current settings (Android 8+ uses channel sound)
    String channelId;
    if (forceDefaultSound) {
      // Create/ensure a default-sound channel for current locale
      final lang =
          appLocale.value?.languageCode ??
          WidgetsBinding.instance.platformDispatcher.locale.languageCode;
      final androidImpl = notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final channelName = (lang == 'ko') ? '일출 알람' : 'Sunrise Alarm';
      final channelDesc = (lang == 'ko')
          ? '일출 알림'
          : 'Sunrise alarm notifications';
      final fallbackId = 'sunrise_channel_${lang}_default';
      await androidImpl?.createNotificationChannel(
        AndroidNotificationChannel(
          fallbackId,
          channelName,
          description: channelDesc,
          importance: Importance.max,
          playSound: true,
        ),
      );
      channelId = fallbackId;
    } else {
      channelId = await _ensureAndroidChannelForSettings();
    }
    final vibKey = await SettingsService.getVibrationPattern();

    // Do not set per-notification sound on Android 8+; channel controls sound.

    Int64List? vibrationPattern;
    bool enableVibration = vibKey != 'off';
    switch (vibKey) {
      case 'short':
        vibrationPattern = Int64List.fromList([0, 200, 100, 200]);
        break;
      case 'long':
        vibrationPattern = Int64List.fromList([0, 800, 200, 800]);
        break;
      case 'pattern':
        vibrationPattern = Int64List.fromList([
          0,
          300,
          150,
          300,
          400,
          150,
          600,
        ]);
        break;
      case 'off':
      default:
        vibrationPattern = null;
        break;
    }

    final lang2 =
        appLocale.value?.languageCode ??
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    final channelName = (lang2 == 'ko') ? '일출 알람' : 'Sunrise Alarm';
    final channelDesc = (lang2 == 'ko')
        ? '일출 알림'
        : 'Sunrise alarm notifications';

    final android = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDesc,
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: enableVibration,
      vibrationPattern: vibrationPattern,
      category: AndroidNotificationCategory.alarm,
      // Do not auto-open a full-screen activity; keep it as a standard heads-up
      fullScreenIntent: false,
    );
    // iOS: default sound; custom sounds can be added later by bundling files
    // into the Runner target and wiring sound filename here.
    final ios = const DarwinNotificationDetails(
      categoryIdentifier: 'SUNRISE_ALARM',
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    return NotificationDetails(android: android, iOS: ios);
  }

  // Map our logical sound keys to iOS bundle file names (without path).
  // Provide files like good_morning.caf, wake_up.caf, morning_triumph.caf
  // inside the iOS Runner target and ensure they are in the app bundle.
  // static String? _iosSoundFileName(String key) {
  //   switch (key) {
  //     case 'good_morning':
  //       return 'good_morning.caf';
  //     case 'wake_up':
  //       return 'wake_up.caf';
  //     case 'morning_triumph':
  //       return 'morning_triumph.caf';
  //     default:
  //       return null; // use system default sound
  //   }
  // }

  static bool _isInvalidSoundError(Object e) {
    return e is PlatformException && e.code == 'invalid_sound';
  }

  /// 지정된 시간(localTime)에 알람 예약
  static Future<void> scheduleAt(
    DateTime localTime, {
    String? title,
    String? body,
  }) async {
    var tzTime = tz.TZDateTime.from(localTime, tz.local);
    final now = tz.TZDateTime.now(tz.local);
    if (!tzTime.isAfter(now)) {
      // 최소 2초 뒤로 보정
      tzTime = now.add(const Duration(seconds: 2));
    }

    try {
      final details = await _buildDetails();
      final epochMsUtc = tzTime.toUtc().millisecondsSinceEpoch;
      await notifications.zonedSchedule(
        _id,
        title ?? '일출 알람',
        body ?? '좋은 하루 시작해요 ☀️',
        tzTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'sunrise:$_id:$epochMsUtc',
      );
      // Arm foreground overlay timer for the legacy single alarm ID
      ForegroundAlarmOverlay.arm(tzTime, alarmId: _id);
    } catch (e) {
      if (_isInvalidSoundError(e)) {
        // Fallback to default sound and persist preference to avoid future crashes
        await SettingsService.setNotificationSound('default');
        final details = await _buildDetails(forceDefaultSound: true);
        await notifications.zonedSchedule(
          _id,
          title ?? '일출 알람',
          body ?? '좋은 하루 시작해요 ☀️',
          tzTime,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: 'sunrise:$_id:${tzTime.toUtc().millisecondsSinceEpoch}',
        );
        ForegroundAlarmOverlay.arm(tzTime, alarmId: _id);
      } else {
        rethrow;
      }
    }

    // Persist/Upsert legacy alarm into list
    final items = await list();
    items.removeWhere((e) => e.id == _id);
    items.add(
      ScheduledAlarm(
        id: _id,
        scheduled: tzTime.toUtc(),
        tzName: tz.local.name,
        title: title ?? '일출 알람',
        body: body ?? '좋은 하루 시작해요 ☀️',
      ),
    );
    await _saveList(items);
  }

  /// 여러 개 알람 지원: 고유 ID를 생성해 해당 시간대로 예약하고 저장소에 기록한다.
  static Future<int> scheduleNew(
    DateTime localTime, {
    tz.Location? location,
    String? title,
    String? body,
  }) async {
    final id = await _nextId();
    final loc = location ?? tz.local;

    var tzTime = tz.TZDateTime.from(localTime, loc);
    final now = tz.TZDateTime.now(loc);
    if (!tzTime.isAfter(now)) {
      tzTime = now.add(const Duration(seconds: 2));
    }

    try {
      final details = await _buildDetails();
      final epochMsUtc = tzTime.toUtc().millisecondsSinceEpoch;
      await notifications.zonedSchedule(
        id,
        title ?? '일출 알람',
        body ?? '좋은 하루 시작해요 ☀️',
        tzTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'sunrise:$id:$epochMsUtc',
      );
      ForegroundAlarmOverlay.arm(tzTime, alarmId: id);
    } catch (e) {
      if (_isInvalidSoundError(e)) {
        await SettingsService.setNotificationSound('default');
        final details = await _buildDetails(forceDefaultSound: true);
        await notifications.zonedSchedule(
          id,
          title ?? '일출 알람',
          body ?? '좋은 하루 시작해요 ☀️',
          tzTime,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: 'sunrise:$id:${tzTime.toUtc().millisecondsSinceEpoch}',
        );
        ForegroundAlarmOverlay.arm(tzTime, alarmId: id);
      } else {
        rethrow;
      }
    }

    final items = await list();
    items.add(
      ScheduledAlarm(
        id: id,
        scheduled: tzTime.toUtc(),
        tzName: loc.name,
        title: title ?? '일출 알람',
        body: body ?? '좋은 하루 시작해요 ☀️',
      ),
    );
    await _saveList(items);
    return id;
  }

  /// 일출 기준으로 [days]일 동안 매일 한 번씩 알람을 예약합니다.
  /// 각 날짜에 대해 위치 타임존의 '그 날짜' 일출 시각을 조회하고 [offsetMinutes]을 적용합니다.
  /// 이미 지난 시각은 건너뜁니다. 생성된 알람 ID 목록을 반환합니다.
  static Future<List<int>> scheduleSunriseSeries({
    required int days,
    required int offsetMinutes,
    required double lat,
    required double lon,
    required tz.Location location,
    String? title,
    String? body,
    tz.TZDateTime? startLocalDate,
  }) async {
    final created = <int>[];
    final nowLocal = tz.TZDateTime.now(location);
    // 시작 기준: 위치의 '오늘 00:00' 또는 지정된 시작 현지 날짜 00:00
    var baseLocalDate = startLocalDate != null
        ? tz.TZDateTime(
            location,
            startLocalDate.year,
            startLocalDate.month,
            startLocalDate.day,
          )
        : tz.TZDateTime(location, nowLocal.year, nowLocal.month, nowLocal.day);
    for (var i = 0; i < days; i++) {
      final dayLocal = baseLocalDate.add(Duration(days: i));
      // SunriseService.fetchSunriseUtc는 "그 날짜의 일출"을 반환 (UTC)
      DateTime sunriseUtc;
      try {
        sunriseUtc = await SunriseService.fetchSunriseUtc(
          lat,
          lon,
          DateTime(dayLocal.year, dayLocal.month, dayLocal.day),
        );
      } catch (_) {
        // 이 날짜는 건너뜀
        continue;
      }
      var sunriseLocal = tz.TZDateTime.from(sunriseUtc, location);
      var scheduled = sunriseLocal.add(Duration(minutes: offsetMinutes));
      // 과거라면 건너뜀
      if (!scheduled.isAfter(nowLocal)) continue;
      final id = await scheduleNew(
        scheduled,
        location: location,
        title: title,
        body: body,
      );
      created.add(id);
    }
    return created;
  }

  /// 지정된 시간([localTime])을 주어진 [location] 시간대로 해석하여 예약
  static Future<void> scheduleAtZoned(
    DateTime localTime,
    tz.Location location, {
    String? title,
    String? body,
  }) async {
    var tzTime = tz.TZDateTime.from(localTime, location);
    final now = tz.TZDateTime.now(location);
    if (!tzTime.isAfter(now)) {
      tzTime = now.add(const Duration(seconds: 2));
    }

    try {
      final details = await _buildDetails();
      final epochMsUtc = tzTime.toUtc().millisecondsSinceEpoch;
      await notifications.zonedSchedule(
        _id,
        title ?? '일출 알람',
        body ?? '좋은 하루 시작해요 ☀️',
        tzTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'sunrise:$_id:$epochMsUtc',
      );
      ForegroundAlarmOverlay.arm(tzTime, alarmId: _id);
    } catch (e) {
      if (_isInvalidSoundError(e)) {
        await SettingsService.setNotificationSound('default');
        final details = await _buildDetails(forceDefaultSound: true);
        await notifications.zonedSchedule(
          _id,
          title ?? '일출 알람',
          body ?? '좋은 하루 시작해요 ☀️',
          tzTime,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: 'sunrise:$_id:${tzTime.toUtc().millisecondsSinceEpoch}',
        );
        ForegroundAlarmOverlay.arm(tzTime, alarmId: _id);
      } else {
        rethrow;
      }
    }

    // Persist/Upsert legacy alarm into list
    final items = await list();
    items.removeWhere((e) => e.id == _id);
    items.add(
      ScheduledAlarm(
        id: _id,
        scheduled: tzTime.toUtc(),
        tzName: location.name,
        title: title ?? '일출 알람',
        body: body ?? '좋은 하루 시작해요 ☀️',
      ),
    );
    await _saveList(items);
  }

  /// 기존 단일 알람 취소 (레거시)
  static Future<void> cancel() async {
    await notifications.cancel(_id);
    ForegroundAlarmOverlay.cancel();
    final items = await list();
    items.removeWhere((e) => e.id == _id);
    await _saveList(items);
  }

  /// 특정 ID 알람 취소 및 저장 목록 갱신
  static Future<void> cancelById(int id) async {
    await notifications.cancel(id);
    ForegroundAlarmOverlay.cancel();
    final items = await list();
    items.removeWhere((e) => e.id == id);
    await _saveList(items);
  }

  /// 모든 알람 취소 및 저장 목록 비우기
  static Future<void> cancelAll() async {
    await notifications.cancelAll();
    ForegroundAlarmOverlay.cancel();
    await _saveList([]);
  }

  /// [진단] 즉시 알림 표시 (채널/권한 문제 점검용)
  static Future<void> debugShowNow({String? title, String? body}) async {
    try {
      final details = await _buildDetails();
      final nowUtc = DateTime.now().toUtc().millisecondsSinceEpoch;
      await notifications.show(
        _id,
        title ?? '테스트 알림',
        body ?? '채널/권한 동작 확인',
        details,
        payload: 'sunrise:$_id:$nowUtc',
      );
    } catch (e) {
      if (_isInvalidSoundError(e)) {
        await SettingsService.setNotificationSound('default');
        final details = await _buildDetails(forceDefaultSound: true);
        final nowUtc = DateTime.now().toUtc().millisecondsSinceEpoch;
        await notifications.show(
          _id,
          title ?? '테스트 알림',
          body ?? '채널/권한 동작 확인',
          details,
          payload: 'sunrise:$_id:$nowUtc',
        );
      } else {
        rethrow;
      }
    }
  }

  /// [진단] 예약된 알림 개수 조회
  static Future<int> pendingCount() async {
    final list = await notifications.pendingNotificationRequests();
    return list.length;
  }
}

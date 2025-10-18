import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

import 'screens/home_screen.dart';
// Removed AlarmScreen; we now use a simple stop dialog on HomeScreen
import 'screens/settings_screen.dart';
import 'services/settings_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'services/ringtone_service.dart';
import 'services/alarm_service.dart';
import 'widgets/stop_overlay.dart';
// Show our in-app modal overlay on alarm interactions (no system alert)
import 'package:google_fonts/google_fonts.dart';
import 'package:workmanager/workmanager.dart';
import 'services/repeat_prefs.dart';

final navigatorKey = GlobalKey<NavigatorState>();
final notifications = FlutterLocalNotificationsPlugin();
// 앱 전역 테마 모드 (라이트/다크 동적 전환)
final appThemeMode = ValueNotifier<ThemeMode>(ThemeMode.light);
// 앱 전역 로케일 (위치 기반으로 동적 전환). null이면 시스템 기본
final appLocale = ValueNotifier<Locale?>(null);
// 앱 전역 시간 형식 (true: 24시간, false: 12시간)
final appTime24h = ValueNotifier<bool>(true);

Future<void> initTimeZone() async {
  tzdata.initializeTimeZones();
  final override = await SettingsService.getTzOverride();
  if (override != null && override.isNotEmpty) {
    tz.setLocalLocation(tz.getLocation(override));
  } else {
    try {
      final tzResult = await FlutterTimezone.getLocalTimezone();
      String? tzName;
      // Some versions return a String, others may return objects.
      // Try String first, then dynamic.identifier if available.
      if (tzResult is String) {
        tzName = tzResult as String;
      } else {
        try {
          final dyn = tzResult as dynamic;
          final id = dyn.identifier;
          if (id is String) tzName = id;
        } catch (_) {}
      }
      if (tzName != null && tzName.isNotEmpty) {
        tz.setLocalLocation(tz.getLocation(tzName));
      }
    } catch (_) {
      // Fallback: keep default tz.local as packaged by tzdata
    }
  }
}

Future<void> _initNotifications() async {
  final l10nCtx = navigatorKey.currentContext;
  // Fallbacks if context is not yet available
  final channelName = l10nCtx != null
      ? AppLocalizations.of(l10nCtx).notifChannelName
      : 'Sunrise Alarm';
  final channelDesc = l10nCtx != null
      ? AppLocalizations.of(l10nCtx).notifChannelDesc
      : 'Sunrise alarm notifications';

  final lang = l10nCtx != null
      ? Localizations.localeOf(l10nCtx).languageCode
      : 'en';
  final channelId = 'sunrise_channel_$lang';

  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  final iosInit = DarwinInitializationSettings(
    notificationCategories: [
      DarwinNotificationCategory(
        'SUNRISE_ALARM',
        actions: [
          DarwinNotificationAction.plain(
            'STOP',
            l10nCtx != null
                ? AppLocalizations.of(l10nCtx).alarmActionStop
                : 'Stop',
            options: {DarwinNotificationActionOption.foreground},
          ),
        ],
      ),
    ],
  );
  final initSettings = InitializationSettings(
    android: androidInit,
    iOS: iosInit,
  );

  await notifications.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (resp) async {
      final (id, whenUtc) = _parseIdAndMs(resp.payload);
      // Handle explicit Stop action (iOS). Android uses in-app stop.
      if ((resp.actionId ?? '').toUpperCase() == 'STOP') {
        await RingtoneService.stop();
        if (id != null) {
          try {
            await AlarmService.cancelById(id);
          } catch (_) {}
        }
        // Ensure any visible overlay is dismissed after stopping
        if (StopOverlay.isShowing) {
          StopOverlay.hide();
        }
        return;
      }
      // Default tap: just ensure playback continues; no popup UI
      RingtoneService.ensureStarted(scheduledEpochMsUtc: whenUtc);
      // Show our modal stop overlay (does not interrupt audio)
      StopOverlay.show(alarmId: id);
    },
  );

  // Android 13+ notifications permission and exact alarm permission
  final androidImpl = notifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  await androidImpl?.requestNotificationsPermission();
  await androidImpl?.requestExactAlarmsPermission();

  // Create localized channel per locale (Android)
  await androidImpl?.createNotificationChannel(
    AndroidNotificationChannel(
      channelId,
      channelName,
      description: channelDesc,
      importance: Importance.max,
    ),
  );

  // iOS notifications permission
  final iosImpl = notifications
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();
  await iosImpl?.requestPermissions(alert: true, badge: true, sound: true);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initTimeZone();
  await _initNotifications();
  // 미리 사운드 소스를 준비해, 알림 탭 시 시작 지연/끊김 최소화
  await RingtoneService.ensurePrepared();

  // 백그라운드 작업 초기화: 매일 새벽 자동 보충(선예약)용
  await Workmanager().initialize(_onBackgroundTask);

  // Load saved user preferences before building UI
  final langPref = await SettingsService.getLanguageOverride();
  if (langPref != 'system') {
    appLocale.value = Locale(langPref);
  }
  final themePref = await SettingsService.getThemeModePref();
  switch (themePref) {
    case 'light':
      appThemeMode.value = ThemeMode.light;
      break;
    case 'dark':
      appThemeMode.value = ThemeMode.dark;
      break;
    default:
      appThemeMode.value = ThemeMode.system;
  }
  appTime24h.value = await SettingsService.getTimeFormat24h();

  // 알람(알림)으로 인해 앱이 실행되었는지 확인하고, 실행 직후 알람 화면으로 이동
  final launchDetails = await notifications.getNotificationAppLaunchDetails();

  runApp(const MyApp());

  // 프레임이 그려진 직후 내비게이션 수행 (navigatorKey 사용 가능 상태)
  if (launchDetails?.didNotificationLaunchApp == true) {
    final payload = launchDetails!.notificationResponse?.payload;
    final (id, whenUtc) = _parseIdAndMs(payload);
    // 앱이 알림으로 시작될 때도 즉시 재생 시작 후 다이얼로그 표시
    RingtoneService.ensureStarted(scheduledEpochMsUtc: whenUtc);
    // Show modal stop overlay on launch via notification
    StopOverlay.show(alarmId: id);
  }
}

// 백그라운드에서 호출되는 작업: 예약 선행분이 부족하면 앞으로 horizon까지 채운다.
@pragma('vm:entry-point')
void _onBackgroundTask() {
  Workmanager().executeTask((task, inputData) async {
    try {
      // 선예약 설정이 켜져 있는지 확인
      if (!await RepeatPrefs.isEnabled()) return true;
      final off = await RepeatPrefs.offsetMinutes();
      final (lat, lon) = await RepeatPrefs.coords();
      final tzName = await RepeatPrefs.tzName();
      if (lat == null || lon == null || tzName == null) return true;
      final loc = tz.getLocation(tzName);
      // 현재 펜딩 개수가 horizon보다 적으면 보충
      final horizon = await RepeatPrefs.horizonDays();
      final pending = await notifications.pendingNotificationRequests();
      if (pending.length < horizon) {
        await AlarmService.scheduleSunriseSeries(
          days: horizon,
          offsetMinutes: off,
          lat: lat,
          lon: lon,
          location: loc,
          title: '일출 알람',
          body: '좋은 하루 시작해요 ☀️',
          startLocalDate: tz.TZDateTime.now(loc),
        );
      }
    } catch (_) {}
    return true;
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Primary color per request
    const primaryBlue = Color(0xFF3795E8);

    // Use primary for both primary/secondary accents to unify look
    final lightScheme = ColorScheme.highContrastLight(
      primary: primaryBlue,
      onPrimary: Colors.white,
      secondary: primaryBlue,
      onSecondary: Colors.white,
      surface: Colors.white,
      onSurface: Colors.black,
      error: const Color(0xFFB00020),
      onError: Colors.white,
    );
    final darkScheme = ColorScheme.highContrastDark(
      primary: primaryBlue,
      onPrimary: Colors.white,
      secondary: primaryBlue,
      onSecondary: Colors.white,
      surface: const Color(0xFF121212),
      onSurface: Colors.white,
      error: const Color(0xFFFF5252),
      onError: Colors.black,
    );

    final light = ThemeData.from(colorScheme: lightScheme, useMaterial3: true)
        .copyWith(
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              foregroundColor: lightScheme.onPrimary,
              backgroundColor: lightScheme.primary,
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: lightScheme.primary, width: 1.5),
              foregroundColor: lightScheme.primary,
            ),
          ),
          appBarTheme: AppBarTheme(
            titleTextStyle: GoogleFonts.notoSansKr(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: lightScheme.onSurface,
              letterSpacing: 0.4,
            ),
            toolbarTextStyle: GoogleFonts.notoSansKr(
              fontSize: 14,
              color: lightScheme.onSurface,
            ),
          ),
        );
    final dark = ThemeData.from(colorScheme: darkScheme, useMaterial3: true)
        .copyWith(
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              foregroundColor: darkScheme.onPrimary,
              backgroundColor: darkScheme.primary,
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: darkScheme.primary, width: 1.5),
              foregroundColor: darkScheme.primary,
            ),
          ),
          appBarTheme: AppBarTheme(
            titleTextStyle: GoogleFonts.notoSansKr(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: darkScheme.onSurface,
              letterSpacing: 0.4,
            ),
            toolbarTextStyle: GoogleFonts.notoSansKr(
              fontSize: 14,
              color: darkScheme.onSurface,
            ),
          ),
        );

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, mode, _) {
        return ValueListenableBuilder<Locale?>(
          valueListenable: appLocale,
          builder: (context, loc, __) {
            return MaterialApp(
              onGenerateTitle: (ctx) => AppLocalizations.of(ctx).appTitle,
              theme: light,
              darkTheme: dark,
              themeMode: mode,
              navigatorKey: navigatorKey,
              locale: loc,
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [Locale('ko'), Locale('en')],
              routes: {
                '/': (_) => const HomeScreen(),
                '/settings': (_) => const SettingsScreen(),
              },
            );
          },
        );
      },
    );
  }
}

/// payload 형식: 'sunrise:[id]:[epochMsUtc]'를 파싱해 (id, ms) 튜플 반환
(int?, int?) _parseIdAndMs(String? payload) {
  if (payload == null || !payload.startsWith('sunrise:')) return (null, null);
  final parts = payload.split(':');
  if (parts.length < 3) return (null, null);
  final id = int.tryParse(parts[1]);
  final ms = int.tryParse(parts[2]);
  return (id, ms);
}

// Overlay version handles stop popup; no modal route push required.

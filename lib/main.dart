import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

import 'screens/home_screen.dart';
import 'screens/alarm_screen.dart';
import 'services/settings_service.dart';

final navigatorKey = GlobalKey<NavigatorState>();
final notifications = FlutterLocalNotificationsPlugin();
// 앱 전역 테마 모드 (라이트/다크 동적 전환)
final appThemeMode = ValueNotifier<ThemeMode>(ThemeMode.light);

Future<void> initTimeZone() async {
  tzdata.initializeTimeZones();
  final override = await SettingsService.getTzOverride();
  if (override != null && override.isNotEmpty) {
    tz.setLocalLocation(tz.getLocation(override));
  } else {
    final tzInfo = await FlutterTimezone.getLocalTimezone();
    // tzInfo.identifier 예: 'Asia/Seoul'
    tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
  }
}

Future<void> _initNotifications() async {
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosInit = DarwinInitializationSettings();
  const initSettings = InitializationSettings(
    android: androidInit,
    iOS: iosInit,
  );

  await notifications.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (resp) {
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const AlarmScreen()),
      );
    },
  );

  // Android 13+ notifications permission and exact alarm permission
  final androidImpl = notifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  await androidImpl?.requestNotificationsPermission();
  await androidImpl?.requestExactAlarmsPermission();

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

  // 알람(알림)으로 인해 앱이 실행되었는지 확인하고, 실행 직후 알람 화면으로 이동
  final launchDetails = await notifications.getNotificationAppLaunchDetails();

  runApp(const MyApp());

  // 프레임이 그려진 직후 내비게이션 수행 (navigatorKey 사용 가능 상태)
  if (launchDetails?.didNotificationLaunchApp == true) {
    final payload = launchDetails!.notificationResponse?.payload;
    if (payload == 'sunrise' || payload == 'debug') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const AlarmScreen()),
        );
      });
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // High-contrast color schemes for better readability in light/dark modes
    const primaryBlue = Color(0xFF0D47A1); // deep, vivid blue
    const secondaryOrange = Color(0xFFFF6F00); // strong accent

    final lightScheme = ColorScheme.highContrastLight(
      primary: primaryBlue,
      onPrimary: Colors.white,
      secondary: secondaryOrange,
      onSecondary: Colors.black,
      surface: Colors.white,
      onSurface: Colors.black,
      error: const Color(0xFFB00020),
      onError: Colors.white,
    );
    final darkScheme = ColorScheme.highContrastDark(
      primary: const Color(0xFF82B1FF), // bright enough for dark bg
      onPrimary: Colors.black,
      secondary: const Color(0xFFFFAB40),
      onSecondary: Colors.black,
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
              side: BorderSide(color: darkScheme.secondary, width: 1.5),
              foregroundColor: darkScheme.secondary,
            ),
          ),
        );

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'Sunrise Alarm',
          theme: light,
          darkTheme: dark,
          themeMode: mode,
          navigatorKey: navigatorKey,
          routes: {
            '/': (_) => const HomeScreen(),
            '/alarm': (_) => const AlarmScreen(),
          },
        );
      },
    );
  }
}

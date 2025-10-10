// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Sunrise Alarm';

  @override
  String get nextSunrise => 'Next Sunrise';

  @override
  String get retry => 'Retry';

  @override
  String get alarmTime => 'Alarm Time';

  @override
  String get offsetExact => 'on time';

  @override
  String offsetBeforeMinutes(Object minutes) {
    return '$minutes min before';
  }

  @override
  String offsetAfterMinutes(Object minutes) {
    return '$minutes min after';
  }

  @override
  String previewRing(Object time) {
    return 'Rings at $time';
  }

  @override
  String get reserveAlarm => 'Reserve Alarm';

  @override
  String get confirmReserveTitle => 'Reserve Alarm';

  @override
  String confirmReserveMsgExact(Object offset) {
    return 'Reserve the alarm? (Sunrise $offset)';
  }

  @override
  String confirmReserveMsg(Object offset, Object time) {
    return 'Reserve the alarm? (Sunrise $offset, Rings at $time)';
  }

  @override
  String get reserve => 'Reserve';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get keep => 'Keep';

  @override
  String get noReserved => 'No alarm reserved yet';

  @override
  String get alarmDeletedToast => 'Alarm deleted.';

  @override
  String get alarmReservedToast => 'Alarm reserved.';

  @override
  String get unlockGuide => 'Unlock alarm: Type the text below exactly';

  @override
  String get unlock => 'Unlock';

  @override
  String get stop => 'Stop';

  @override
  String get almostThere => 'Almost there—type a bit more accurately!';

  @override
  String get released => 'Unlocked! Have a great day ✨';

  @override
  String get cantGoBackRinging => 'Press \'Stop\' below to stop the alarm.';

  @override
  String get remainSoon => 'Rings soon';

  @override
  String remain(Object days, Object hours, Object minutes) {
    return '$days$hours$minutes left';
  }

  @override
  String remainDays(Object count) {
    return '${count}d ';
  }

  @override
  String remainHours(Object count) {
    return '${count}h ';
  }

  @override
  String remainMinutes(Object count) {
    return '${count}m';
  }

  @override
  String get locationServiceOffShort => 'Location services are off.';

  @override
  String get locationServiceOffDetail =>
      'Turn on location services and try again.';

  @override
  String get openSettings => 'Open settings';

  @override
  String get appSettings => 'App settings';

  @override
  String get locationPermissionRequiredShort =>
      'Location permission is required.';

  @override
  String get locationPermissionRequiredDetail =>
      'Please allow the permission in app settings.';

  @override
  String get couldNotGetLocation =>
      'Couldn\'t get current location. Try again later or go outside.';

  @override
  String get networkSlowSunriseFail =>
      'Network is slow. Could not fetch sunrise. Please retry.';

  @override
  String errorWithMessage(Object message) {
    return 'Error: $message';
  }

  @override
  String get confirmDeleteTitle => 'Delete Alarm';

  @override
  String get confirmDeleteMsg => 'Delete the reserved alarm?';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsSystemDefault => 'System default';

  @override
  String get settingsKorean => 'Korean';

  @override
  String get settingsEnglish => 'English';

  @override
  String get settingsTime24h => '24-hour time';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsThemeAuto => 'Auto';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsNote =>
      'Changes apply immediately. Some options may be limited by OS policies.';

  @override
  String get settingsTooltip => 'Settings';

  @override
  String get settingsTestAlarm => 'Test alarm';

  @override
  String get settingsTestAlarmDesc => 'An alarm will ring in 10 seconds.';

  @override
  String get settingsRun => 'Run';

  @override
  String get testAlarmScheduledToast => 'Test alarm scheduled (in 10s).';

  @override
  String get notifSunriseTitle => 'Sunrise Alarm';

  @override
  String get notifSunriseBody => 'Start a great day ☀️';

  @override
  String get notifTestTitle => 'Test Notification';

  @override
  String get notifTestBody => 'Check channel/permission behavior';
}

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => 'Sunrise Alarm';

  @override
  String get nextSunrise => '다음 일출';

  @override
  String get retry => '다시 시도';

  @override
  String get alarmTime => '알람 시각';

  @override
  String get offsetExact => '정각';

  @override
  String offsetBeforeMinutes(Object minutes) {
    return '$minutes분 전';
  }

  @override
  String offsetAfterMinutes(Object minutes) {
    return '$minutes분 후';
  }

  @override
  String previewRing(Object time) {
    return '예상 울림 $time';
  }

  @override
  String get reserveAlarm => '알람 예약';

  @override
  String get confirmReserveTitle => '알람 예약';

  @override
  String confirmReserveMsgExact(Object offset) {
    return '알람을 예약할까요? (일출 $offset)';
  }

  @override
  String confirmReserveMsg(Object offset, Object time) {
    return '알람을 예약할까요? (일출 $offset, 예상 울림 $time)';
  }

  @override
  String get reserve => '예약';

  @override
  String get cancel => '취소';

  @override
  String get delete => '삭제';

  @override
  String get keep => '유지';

  @override
  String get noReserved => '아직 예약된 알람이 없어요';

  @override
  String get alarmDeletedToast => '알람을 삭제했어요.';

  @override
  String get alarmReservedToast => '알람을 예약했어요.';

  @override
  String get unlockGuide => '알람 해제: 아래 문장을 그대로 입력하세요';

  @override
  String get unlock => '해제';

  @override
  String get stop => '멈춤';

  @override
  String get almostThere => '조금만 더 정확히 입력해봐요!';

  @override
  String get released => '해제 완료! 좋은 하루 ✨';

  @override
  String get cantGoBackRinging => '알람을 멈추려면 아래 \"멈춤\" 버튼을 누르세요.';

  @override
  String get remainSoon => '곧 울림';

  @override
  String remain(Object days, Object hours, Object minutes) {
    return '$days$hours$minutes 남음';
  }

  @override
  String remainDays(Object count) {
    return '$count일 ';
  }

  @override
  String remainHours(Object count) {
    return '$count시간 ';
  }

  @override
  String remainMinutes(Object count) {
    return '$count분';
  }

  @override
  String get locationServiceOffShort => '위치 서비스가 꺼져 있어요.';

  @override
  String get locationServiceOffDetail => '위치 서비스를 켠 뒤 다시 시도해 주세요.';

  @override
  String get openSettings => '설정 열기';

  @override
  String get appSettings => '앱 설정';

  @override
  String get locationPermissionRequiredShort => '위치 권한이 필요합니다.';

  @override
  String get locationPermissionRequiredDetail => '앱 설정에서 권한을 허용해 주세요.';

  @override
  String get couldNotGetLocation =>
      '현재 위치를 가져오지 못했습니다. 잠시 후 다시 시도하거나 야외에서 시도해 주세요.';

  @override
  String get networkSlowSunriseFail =>
      '네트워크가 느려 일출 시간을 가져오지 못했습니다. 다시 시도해 주세요.';

  @override
  String errorWithMessage(Object message) {
    return '오류: $message';
  }

  @override
  String get confirmDeleteTitle => '알람 삭제';

  @override
  String get confirmDeleteMsg => '예약된 알람을 삭제할까요?';

  @override
  String get settingsTitle => '설정';

  @override
  String get settingsLanguage => '언어';

  @override
  String get settingsSystemDefault => '시스템 기본값';

  @override
  String get settingsKorean => '한국어';

  @override
  String get settingsEnglish => '영어';

  @override
  String get settingsTime24h => '24시간 표시';

  @override
  String get settingsTheme => '테마';

  @override
  String get settingsThemeAuto => '자동';

  @override
  String get settingsThemeLight => '라이트';

  @override
  String get settingsThemeDark => '다크';

  @override
  String get settingsNote => '변경 사항은 즉시 적용됩니다. 일부 옵션은 OS 정책에 의해 제한될 수 있어요.';

  @override
  String get settingsTooltip => '설정';

  @override
  String get settingsTestAlarm => '알람 테스트';

  @override
  String get settingsTestAlarmDesc => '10초 후 알람이 울립니다.';

  @override
  String get settingsRun => '실행';

  @override
  String get testAlarmScheduledToast => '테스트 알람을 예약했어요. (10초 후)';

  @override
  String get notifSunriseTitle => '일출 알람';

  @override
  String get notifSunriseBody => '좋은 하루 시작해요 ☀️';

  @override
  String get notifTestTitle => '테스트 알림';

  @override
  String get notifTestBody => '채널/권한 동작 확인';
}

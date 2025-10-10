import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ko.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ko'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In ko, this message translates to:
  /// **'Sunrise Alarm'**
  String get appTitle;

  /// No description provided for @nextSunrise.
  ///
  /// In ko, this message translates to:
  /// **'다음 일출'**
  String get nextSunrise;

  /// No description provided for @retry.
  ///
  /// In ko, this message translates to:
  /// **'다시 시도'**
  String get retry;

  /// No description provided for @alarmTime.
  ///
  /// In ko, this message translates to:
  /// **'알람 시각'**
  String get alarmTime;

  /// No description provided for @offsetExact.
  ///
  /// In ko, this message translates to:
  /// **'정각'**
  String get offsetExact;

  /// No description provided for @offsetBeforeMinutes.
  ///
  /// In ko, this message translates to:
  /// **'{minutes}분 전'**
  String offsetBeforeMinutes(Object minutes);

  /// No description provided for @offsetAfterMinutes.
  ///
  /// In ko, this message translates to:
  /// **'{minutes}분 후'**
  String offsetAfterMinutes(Object minutes);

  /// No description provided for @previewRing.
  ///
  /// In ko, this message translates to:
  /// **'예상 울림 {time}'**
  String previewRing(Object time);

  /// No description provided for @reserveAlarm.
  ///
  /// In ko, this message translates to:
  /// **'알람 예약'**
  String get reserveAlarm;

  /// No description provided for @confirmReserveTitle.
  ///
  /// In ko, this message translates to:
  /// **'알람 예약'**
  String get confirmReserveTitle;

  /// No description provided for @confirmReserveMsgExact.
  ///
  /// In ko, this message translates to:
  /// **'알람을 예약할까요? (일출 {offset})'**
  String confirmReserveMsgExact(Object offset);

  /// No description provided for @confirmReserveMsg.
  ///
  /// In ko, this message translates to:
  /// **'알람을 예약할까요? (일출 {offset}, 예상 울림 {time})'**
  String confirmReserveMsg(Object offset, Object time);

  /// No description provided for @reserve.
  ///
  /// In ko, this message translates to:
  /// **'예약'**
  String get reserve;

  /// No description provided for @cancel.
  ///
  /// In ko, this message translates to:
  /// **'취소'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In ko, this message translates to:
  /// **'삭제'**
  String get delete;

  /// No description provided for @keep.
  ///
  /// In ko, this message translates to:
  /// **'유지'**
  String get keep;

  /// No description provided for @noReserved.
  ///
  /// In ko, this message translates to:
  /// **'아직 예약된 알람이 없어요'**
  String get noReserved;

  /// No description provided for @alarmDeletedToast.
  ///
  /// In ko, this message translates to:
  /// **'알람을 삭제했어요.'**
  String get alarmDeletedToast;

  /// No description provided for @alarmReservedToast.
  ///
  /// In ko, this message translates to:
  /// **'알람을 예약했어요.'**
  String get alarmReservedToast;

  /// No description provided for @unlockGuide.
  ///
  /// In ko, this message translates to:
  /// **'알람 해제: 아래 문장을 그대로 입력하세요'**
  String get unlockGuide;

  /// No description provided for @unlock.
  ///
  /// In ko, this message translates to:
  /// **'해제'**
  String get unlock;

  /// No description provided for @stop.
  ///
  /// In ko, this message translates to:
  /// **'멈춤'**
  String get stop;

  /// No description provided for @almostThere.
  ///
  /// In ko, this message translates to:
  /// **'조금만 더 정확히 입력해봐요!'**
  String get almostThere;

  /// No description provided for @released.
  ///
  /// In ko, this message translates to:
  /// **'해제 완료! 좋은 하루 ✨'**
  String get released;

  /// No description provided for @cantGoBackRinging.
  ///
  /// In ko, this message translates to:
  /// **'알람을 멈추려면 아래 \"멈춤\" 버튼을 누르세요.'**
  String get cantGoBackRinging;

  /// No description provided for @remainSoon.
  ///
  /// In ko, this message translates to:
  /// **'곧 울림'**
  String get remainSoon;

  /// No description provided for @remain.
  ///
  /// In ko, this message translates to:
  /// **'{days}{hours}{minutes} 남음'**
  String remain(Object days, Object hours, Object minutes);

  /// No description provided for @remainDays.
  ///
  /// In ko, this message translates to:
  /// **'{count}일 '**
  String remainDays(Object count);

  /// No description provided for @remainHours.
  ///
  /// In ko, this message translates to:
  /// **'{count}시간 '**
  String remainHours(Object count);

  /// No description provided for @remainMinutes.
  ///
  /// In ko, this message translates to:
  /// **'{count}분'**
  String remainMinutes(Object count);

  /// No description provided for @locationServiceOffShort.
  ///
  /// In ko, this message translates to:
  /// **'위치 서비스가 꺼져 있어요.'**
  String get locationServiceOffShort;

  /// No description provided for @locationServiceOffDetail.
  ///
  /// In ko, this message translates to:
  /// **'위치 서비스를 켠 뒤 다시 시도해 주세요.'**
  String get locationServiceOffDetail;

  /// No description provided for @openSettings.
  ///
  /// In ko, this message translates to:
  /// **'설정 열기'**
  String get openSettings;

  /// No description provided for @appSettings.
  ///
  /// In ko, this message translates to:
  /// **'앱 설정'**
  String get appSettings;

  /// No description provided for @locationPermissionRequiredShort.
  ///
  /// In ko, this message translates to:
  /// **'위치 권한이 필요합니다.'**
  String get locationPermissionRequiredShort;

  /// No description provided for @locationPermissionRequiredDetail.
  ///
  /// In ko, this message translates to:
  /// **'앱 설정에서 권한을 허용해 주세요.'**
  String get locationPermissionRequiredDetail;

  /// No description provided for @couldNotGetLocation.
  ///
  /// In ko, this message translates to:
  /// **'현재 위치를 가져오지 못했습니다. 잠시 후 다시 시도하거나 야외에서 시도해 주세요.'**
  String get couldNotGetLocation;

  /// No description provided for @networkSlowSunriseFail.
  ///
  /// In ko, this message translates to:
  /// **'네트워크가 느려 일출 시간을 가져오지 못했습니다. 다시 시도해 주세요.'**
  String get networkSlowSunriseFail;

  /// No description provided for @errorWithMessage.
  ///
  /// In ko, this message translates to:
  /// **'오류: {message}'**
  String errorWithMessage(Object message);

  /// No description provided for @confirmDeleteTitle.
  ///
  /// In ko, this message translates to:
  /// **'알람 삭제'**
  String get confirmDeleteTitle;

  /// No description provided for @confirmDeleteMsg.
  ///
  /// In ko, this message translates to:
  /// **'예약된 알람을 삭제할까요?'**
  String get confirmDeleteMsg;

  /// No description provided for @settingsTitle.
  ///
  /// In ko, this message translates to:
  /// **'설정'**
  String get settingsTitle;

  /// No description provided for @settingsLanguage.
  ///
  /// In ko, this message translates to:
  /// **'언어'**
  String get settingsLanguage;

  /// No description provided for @settingsSystemDefault.
  ///
  /// In ko, this message translates to:
  /// **'시스템 기본값'**
  String get settingsSystemDefault;

  /// No description provided for @settingsKorean.
  ///
  /// In ko, this message translates to:
  /// **'한국어'**
  String get settingsKorean;

  /// No description provided for @settingsEnglish.
  ///
  /// In ko, this message translates to:
  /// **'영어'**
  String get settingsEnglish;

  /// No description provided for @settingsTime24h.
  ///
  /// In ko, this message translates to:
  /// **'24시간 표시'**
  String get settingsTime24h;

  /// No description provided for @settingsTheme.
  ///
  /// In ko, this message translates to:
  /// **'테마'**
  String get settingsTheme;

  /// No description provided for @settingsThemeAuto.
  ///
  /// In ko, this message translates to:
  /// **'자동'**
  String get settingsThemeAuto;

  /// No description provided for @settingsThemeLight.
  ///
  /// In ko, this message translates to:
  /// **'라이트'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In ko, this message translates to:
  /// **'다크'**
  String get settingsThemeDark;

  /// No description provided for @settingsNote.
  ///
  /// In ko, this message translates to:
  /// **'변경 사항은 즉시 적용됩니다. 일부 옵션은 OS 정책에 의해 제한될 수 있어요.'**
  String get settingsNote;

  /// No description provided for @settingsTooltip.
  ///
  /// In ko, this message translates to:
  /// **'설정'**
  String get settingsTooltip;

  /// No description provided for @settingsTestAlarm.
  ///
  /// In ko, this message translates to:
  /// **'알람 테스트'**
  String get settingsTestAlarm;

  /// No description provided for @settingsTestAlarmDesc.
  ///
  /// In ko, this message translates to:
  /// **'10초 후 알람이 울립니다.'**
  String get settingsTestAlarmDesc;

  /// No description provided for @settingsRun.
  ///
  /// In ko, this message translates to:
  /// **'실행'**
  String get settingsRun;

  /// No description provided for @testAlarmScheduledToast.
  ///
  /// In ko, this message translates to:
  /// **'테스트 알람을 예약했어요. (10초 후)'**
  String get testAlarmScheduledToast;

  /// No description provided for @notifSunriseTitle.
  ///
  /// In ko, this message translates to:
  /// **'일출 알람'**
  String get notifSunriseTitle;

  /// No description provided for @notifSunriseBody.
  ///
  /// In ko, this message translates to:
  /// **'좋은 하루 시작해요 ☀️'**
  String get notifSunriseBody;

  /// No description provided for @notifTestTitle.
  ///
  /// In ko, this message translates to:
  /// **'테스트 알림'**
  String get notifTestTitle;

  /// No description provided for @notifTestBody.
  ///
  /// In ko, this message translates to:
  /// **'채널/권한 동작 확인'**
  String get notifTestBody;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ko':
      return AppLocalizationsKo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

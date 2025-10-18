import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show PlatformException;
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:geocoding/geocoding.dart' as geocoding;
import '../services/sunrise_service.dart';
import '../services/timezone_service.dart';
import '../main.dart';
import '../l10n/app_localizations.dart';
import '../utils/formatters.dart' as fmt;
import '../utils/toast.dart' show showTopToast;
import '../widgets/reserved_alarm_card.dart';
import '../models/schedule_result.dart';
import '../services/settings_service.dart';
import '../services/alarm_service.dart';
// StopOverlay no longer directly triggered from AppBar
import '../services/foreground_alarm_overlay.dart';
import 'package:workmanager/workmanager.dart';
import '../services/repeat_prefs.dart';
import '../utils/dev_log.dart';
import '../utils/constants.dart';
import '../services/alarm_refactor_helpers.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  // 위치 기준 다음 일출 시각 (로컬/위치 타임존)
  DateTime? nextSunriseLocal;
  // UTC 기준 다음 일출 시각(진단)
  DateTime? nextSunriseUtc;
  // 위치 타임존
  tz.Location? _targetLoc;
  // 진행/오류 상태
  bool _busy = false;
  String? _error;
  // 사람 친화적 위치 라벨 (예: 서울 강남구)
  String? _placeLabel;
  // 마지막 위치 저장하여 언어 변경 시 라벨을 재계산
  Position? _lastPosition;
  void _onLocaleChanged() {
    final pos = _lastPosition;
    if (pos != null) {
      _updatePlaceLabelFor(pos);
    }
  }

  // 마지막으로 예약한 알람의 로컬 시각 (표시용)
  DateTime? _lastScheduledAlarmLocal;
  Timer? _ticker;
  // 일출 기준 예약 오프셋 (분). 음수=전, 양수=후
  int _offsetMinutes = 0; // 기본: 일출 기준(오프셋 0)
  // 예약 진행 중 플래그(이중 탭 방지)
  bool _reserving = false;

  bool _isInKorea(double lat, double lon) {
    return lat >= 33.0 && lat <= 39.5 && lon >= 124.5 && lon <= 132.0;
  }

  tz.Location _resolveLocationForCoordinates(
    double lat,
    double lon,
    String? tzId,
  ) {
    tz.Location loc;
    if (tzId != null) {
      try {
        loc = tz.getLocation(tzId);
      } catch (_) {
        loc = tz.local;
      }
    } else {
      loc = tz.local;
    }
    if (_isInKorea(lat, lon) && loc.name != 'Asia/Seoul') {
      // 좌표상 한국이면 Asia/Seoul을 우선 적용
      try {
        loc = tz.getLocation('Asia/Seoul');
      } catch (_) {}
    }
    return loc;
  }

  Future<bool> _ensureLocationReady() async {
    final l10n = AppLocalizations.of(context);
    // 1) 위치 서비스 켜짐 여부
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      setState(() {
        _busy = false;
        _error = l10n.locationServiceOffDetail;
      });
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.locationServiceOffShort),
          action: SnackBarAction(
            label: l10n.openSettings,
            onPressed: () {
              Geolocator.openLocationSettings();
            },
          ),
        ),
      );
      return false;
    }

    // 2) 권한 확인 및 요청
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever ||
        perm == LocationPermission.denied) {
      setState(() {
        _busy = false;
        _error = l10n.locationPermissionRequiredDetail;
      });
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.locationPermissionRequiredShort),
          action: SnackBarAction(
            label: l10n.appSettings,
            onPressed: () {
              Geolocator.openAppSettings();
            },
          ),
        ),
      );
      return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 첫 프레임 이후 비동기 준비 시작 (빌드 블로킹 최소화)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _prepare();
      // 저장소에 있는 예약 내역을 불러와 UI에 반영 (앱 재시작 후에도 표시 유지)
      await _loadReservedFromStorage();
    });
    // 언어 변경 시 현재 위치 라벨을 해당 언어로 재지정
    appLocale.addListener(_onLocaleChanged);
    // 남은 시간 갱신 타이머 (60초, 배터리 절약)
    _ticker = Timer.periodic(const Duration(seconds: 60), (_) {
      if (!mounted) return;
      // 남은 시간 텍스트만 갱신되도록 setState 호출
      setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      // 앱 복귀 시 저장소에서 예약 정보 동기화
      await _loadReservedFromStorage();
    }
    super.didChangeAppLifecycleState(state);
  }

  // 저장된 예약(레거시 단일 ID 우선)을 읽어와 로컬 시간으로 표시
  Future<void> _loadReservedFromStorage() async {
    try {
      // 반복이 비활성화되었거나 일시정지 상태면 카드 숨김
      if (!await RepeatPrefs.isEnabled() || await RepeatPrefs.isPausedNow()) {
        if (!mounted) return;
        setState(() => _lastScheduledAlarmLocal = null);
        return;
      }
      final items = await AlarmService.list();
      if (items.isEmpty) {
        if (!mounted) return;
        setState(() {
          _lastScheduledAlarmLocal = null;
        });
        return;
      }
      // 우선순위: 레거시 단일 ID(2025), 없으면 가장 가까운 미래 예약
      final legacy = items.where((e) => e.id == 2025).toList();
      final nowUtc = DateTime.now().toUtc();
      final candidates = legacy.isNotEmpty ? legacy : items;
      // 미래에 예약된 항목만 고려
      final future =
          candidates.where((e) => e.scheduled.isAfter(nowUtc)).toList()
            ..sort((a, b) => a.scheduled.compareTo(b.scheduled));
      if (future.isEmpty) {
        if (!mounted) return;
        setState(() {
          _lastScheduledAlarmLocal = null;
        });
        return;
      }
      final pick = future.first; // 가장 가까운 미래 시각

      // 저장된 tzName을 사용해 로컬 표시 시간 계산
      tz.Location loc;
      try {
        loc = tz.getLocation(pick.tzName);
      } catch (_) {
        loc = _targetLoc ?? tz.local;
      }
      final local = tz.TZDateTime.from(pick.scheduled, loc);
      if (!mounted) return;
      setState(() {
        _lastScheduledAlarmLocal = local;
        _targetLoc = _targetLoc ?? loc;
      });
    } catch (_) {
      // 저장소 파싱 실패 등은 무시하고 표시만 비움
    }
  }

  Future<void> _prepare() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      // 위치 서비스 & 권한 준비
      final ready = await _ensureLocationReady();
      if (!ready) return;

      // 현재 위치 얻기 (타임아웃 6초) + Fallback: 마지막 위치
      Position pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
      } catch (_) {
        final last = await Geolocator.getLastKnownPosition();
        if (last == null) {
          setState(() {
            _busy = false;
            _error = l10n.couldNotGetLocation;
          });
          return;
        }
        pos = last;
      }

      _lastPosition = pos;
      // 현재 앱 로케일 기준으로 위치 라벨 계산
      final place = await _computePlaceLabel(pos, appLocale.value);

      // 위치 기준 타임존 조회 (실패 시 null)
      final tzId = await TimeZoneService.fetchTimeZoneId(
        pos.latitude,
        pos.longitude,
      );
      // 변환용 타임존: 좌표 기준으로 우선 선택 (한국 범위면 Asia/Seoul)
      final targetLoc = _resolveLocationForCoordinates(
        pos.latitude,
        pos.longitude,
        tzId,
      );
      // '현지 날짜' 기준으로 오늘/내일 일출을 조회하여 UTC로 확보
      final sunriseUtc = await SunriseService.fetchNextSunriseUtcForLocation(
        pos.latitude,
        pos.longitude,
        targetLoc,
      );
      // 위치 타임존에서의 일출 시각
      final localSunrise = tz.TZDateTime.from(sunriseUtc, targetLoc);
      setState(() {
        _targetLoc = targetLoc;
        nextSunriseLocal = localSunrise;
        nextSunriseUtc = sunriseUtc;
        _placeLabel = place;
      });

      // 현지 시간대 기준 라이트/다크 모드 전환 (06:00~18:00 라이트, 그 외 다크)
      // 단, 사용자 설정이 'auto'일 때만 자동 전환 수행
      final pref = await SettingsService.getThemeModePref();
      if (pref == 'auto') {
        final nowLocal = tz.TZDateTime.now(targetLoc);
        final isDay = nowLocal.hour >= 6 && nowLocal.hour < 18;
        appThemeMode.value = isDay ? ThemeMode.light : ThemeMode.dark;
      }
    } on TimeoutException catch (_) {
      setState(() => _error = l10n.networkSlowSunriseFail);
    } catch (e) {
      setState(() => _error = l10n.errorWithMessage(e.toString()));
    } finally {
      setState(() => _busy = false);
    }
  }

  // 주어진 위치와 앱 로케일로 사용자 친화적 라벨을 계산
  Future<String?> _computePlaceLabel(Position pos, Locale? locale) async {
    try {
      final placemarks = await geocoding.placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
      );
      if (placemarks.isEmpty) return null;
      final p = placemarks.first;
      final lang = (locale?.languageCode ?? '').toLowerCase();
      if (lang == 'ko') {
        // 한국어: 시/군 위주로 간단히 표기
        String? city;
        final sa = (p.subAdministrativeArea ?? '').trim();
        final loc = (p.locality ?? '').trim();
        final admin = (p.administrativeArea ?? '').trim();
        if (sa.isNotEmpty && (sa.endsWith('시') || sa.endsWith('군'))) {
          city = sa;
        } else if (loc.isNotEmpty && (loc.endsWith('시') || loc.endsWith('군'))) {
          city = loc;
        } else if (admin.isNotEmpty) {
          city = admin;
        }
        return city?.isNotEmpty == true ? city : null;
      } else {
        // 영어: locality > subAdministrativeArea > administrativeArea
        final parts = <String>[
          if ((p.locality ?? '').trim().isNotEmpty) (p.locality ?? '').trim(),
          if ((p.subAdministrativeArea ?? '').trim().isNotEmpty)
            (p.subAdministrativeArea ?? '').trim(),
          if ((p.administrativeArea ?? '').trim().isNotEmpty)
            (p.administrativeArea ?? '').trim(),
        ];
        if (parts.isEmpty) return null;
        return parts.first;
      }
    } catch (_) {
      return null;
    }
  }

  // Note: Without localeIdentifier support in the current geocoding package
  // version, we reformat the label based on app language using available
  // placemark fields. Underlying language may come from the OS locale.

  Future<void> _updatePlaceLabelFor(Position pos) async {
    final label = await _computePlaceLabel(pos, appLocale.value);
    if (!mounted) return;
    setState(() {
      _placeLabel = label;
    });
  }

  // 수동 좌표 입력 기능 제거됨

  // (removed old _computeScheduledLocal)

  // 항상 미래 알람이 되도록 일출/오프셋을 정규화해 계산하고, 사용한 일출도 반환
  ScheduleResult _computeScheduleNormalized(
    DateTime localSunrise,
    tz.Location loc,
    int offsetMin,
  ) {
    tz.TZDateTime s = localSunrise is tz.TZDateTime
        ? localSunrise
        : tz.TZDateTime.from(localSunrise, loc);
    final now = tz.TZDateTime.now(loc);

    // 일출이 이미 지났다면 다음 날 일출로 이동
    while (!s.isAfter(now)) {
      s = s.add(const Duration(days: 1));
    }

    var scheduled = s.add(Duration(minutes: offsetMin));
    // 오프셋 결과가 과거라면 그 다음 일출로 재계산
    if (!scheduled.isAfter(now)) {
      s = s.add(const Duration(days: 1));
      scheduled = s.add(Duration(minutes: offsetMin));
    }
    return ScheduleResult(scheduled: scheduled, sunriseUsed: s);
  }

  // (진단용 10초 뒤 테스트 알람 기능 제거됨)

  // 통합 버튼으로 기능 대체되어 기존 재예약 메서드는 제거되었습니다.

  Future<void> _addNewAlarmFromCurrent() async {
    debugPrint('[UI] addNewAlarmFromCurrent invoked');
    final l10n = AppLocalizations.of(context);
    // Capture locale upfront to avoid using BuildContext across async gaps
    final localeAtStart = Localizations.localeOf(context);
    final isKoStart = localeAtStart.languageCode == 'ko';
    // Web은 flutter_local_notifications의 예약이 지원되지 않음
    if (kIsWeb) {
      final isKo = Localizations.localeOf(context).languageCode == 'ko';
      final msg = isKo
          ? '웹에서는 알람 예약이 지원되지 않아요. 안드로이드 기기에서 테스트해 주세요.'
          : 'Alarm scheduling is not supported on web. Please test on an Android device.';
      if (!mounted) return;
      showTopToast(context, msg);
      return;
    }
    if (nextSunriseLocal == null || _targetLoc == null) {
      await _prepare();
      if (nextSunriseLocal == null || _targetLoc == null) return;
    }
    // 일출 시각 기준으로 다음 며칠치를 한 번에 예약 (기본 7일)
    final res = _computeScheduleNormalized(
      nextSunriseLocal!,
      _targetLoc!,
      _offsetMinutes,
    );
    try {
      // UI는 실제 예약 성공 후에만 반영 (유령 카드 방지)
      setState(() {
        _reserving = true;
      });
      await AlarmService.cancelAll();
      const seriesDays = 30; // 선예약 지평선(보충 작업이 채움)
      // 위치 좌표는 _lastPosition 저장값 사용 (init에서 확보)
      if (_lastPosition == null) {
        // 위치가 아직 없으면 준비 재시도
        await _prepare();
        if (_lastPosition == null) throw Exception('No location available');
      }
      // 무기한을 위해 사용자 설정을 먼저 저장하여 pause window 제거 및 상태 확정
      await RepeatPrefs.save(
        enabled: true,
        offsetMinutes: _offsetMinutes,
        lat: _lastPosition!.latitude,
        lon: _lastPosition!.longitude,
        tzName: _targetLoc!.name,
        horizonDays: seriesDays,
      );
      // 즉시 다음 1건만 예약(네트워크 호출 없이 계산값 사용)
      bool scheduledOne = false;
      try {
        await AlarmService.scheduleAtZoned(
          res.scheduled,
          _targetLoc!,
          title: l10n.notifSunriseTitle,
          body: l10n.notifSunriseBody,
        );
        scheduledOne = true;
      } catch (_) {
        scheduledOne = false;
      }
      // 저장소에 실제로 예약이 기록되었는지 즉시 동기화
      await _loadReservedFromStorage();
      if (!scheduledOne) {
        // 예약 실패 가능성(정확 알람/알림 권한 등)
        final msg = isKoStart
            ? '예약된 알람이 없어요. 시스템 설정에서 "정확한 알람"과 알림 권한을 확인해 주세요.'
            : 'No alarms were scheduled. Please enable "Exact alarms" and notifications in system settings.';
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(msg)));
        }
      }
      // 무기한을 위해 백그라운드 보충 작업 활성화
      devLogTopUp('[TopUp] registerPeriodicTask requested');
      await Workmanager().registerPeriodicTask(
        WorkTaskNames.topUp,
        WorkTaskNames.topUp,
        frequency: const Duration(hours: 24),
        initialDelay: const Duration(hours: 6),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
        constraints: Constraints(networkType: NetworkType.connected),
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: const Duration(minutes: 30),
      );
      // 초기 대량 선예약은 원오프 작업으로 즉시 보충(앱 UI 대기 시간 최소화)
      try {
        await Workmanager().registerOneOffTask(
          '${WorkTaskNames.topUp}Once',
          WorkTaskNames.topUp,
          initialDelay: const Duration(seconds: 5),
          constraints: Constraints(networkType: NetworkType.connected),
          backoffPolicy: BackoffPolicy.exponential,
          backoffPolicyDelay: const Duration(minutes: 5),
        );
        devLogTopUp('[TopUp] registerOneOffTask requested');
      } catch (_) {}
      // 오늘 예약 시각 기준으로 오버레이 타이머(앱이 열려 있을 때만 유효)
      ForegroundAlarmOverlay.arm(res.scheduled, alarmId: 2025);
      if (!mounted) return;
      if (scheduledOne) {
        setState(() {
          // 저장소 동기화에서 값을 못 불러왔을 경우에만 즉시 계산값 유지
          _lastScheduledAlarmLocal = _lastScheduledAlarmLocal ?? res.scheduled;
        });
      } else {
        // 스케줄 실패/차단 시에는 예약 카드 표시를 비웁니다
        if (mounted) {
          setState(() {
            _lastScheduledAlarmLocal = null;
          });
        }
      }
      // 예약 건수와 함께 토스트로 피드백 제공
      try {
        final cnt = await AlarmService.pendingCount();
        if (!mounted) return;
        showTopToast(
          context,
          scheduledOne
              ? '${l10n.alarmReservedToast} ($cnt)'
              : l10n.alarmReservedToast,
        );
      } catch (_) {
        if (!mounted) return;
        showTopToast(context, l10n.alarmReservedToast);
      }
      // 진단용 로그는 유지
      try {
        final cnt = await AlarmService.pendingCount();
        // ignore: avoid_print
        debugPrint('[Alarm] Pending notification requests: $cnt');
      } catch (_) {}
    } on PlatformException catch (_) {
      // Android 14+에서 정확 알람 권한 미허용 등으로 실패할 수 있음
      final msg = isKoStart
          ? '정확한 알람 권한이 없어 예약에 실패했어요. 설정 > 알람 및 리마인더(또는 정확한 알람)에서 허용해 주세요.'
          : 'Failed to schedule. Please enable the exact alarm permission in system settings.';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() => _reserving = false);
      }
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    String confirmText = '확인',
    String cancelText = '취소',
  }) async {
    if (!mounted) return false;
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(cancelText),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(confirmText),
            ),
          ],
        );
      },
    );
    return res ?? false;
  }

  String _offsetLabel(AppLocalizations l10n) {
    if (_offsetMinutes == 0) return l10n.offsetExact;
    if (_offsetMinutes < 0) {
      return l10n.offsetBeforeMinutes((-_offsetMinutes).toString());
    }
    return l10n.offsetAfterMinutes(_offsetMinutes.toString());
  }

  Widget _buildReservedSection() {
    return ReservedAlarmCard(
      scheduled: _lastScheduledAlarmLocal,
      location: _targetLoc,
      onDelete: _busy
          ? null
          : () async {
              final ok = await _confirm(
                title: AppLocalizations.of(context).confirmDeleteTitle,
                message: AppLocalizations.of(context).confirmDeleteMsg,
                confirmText: AppLocalizations.of(context).delete,
                cancelText: AppLocalizations.of(context).keep,
              );
              if (!ok) return;
              // 순서: 1) 선예약 설정 비활성화 → 2) 백그라운드 작업 취소 → 3) 모든 알람 취소
              await RepeatPrefs.disable();
              debugPrint('[Repeat] Disabled by user (card delete)');
              await AlarmCleanup.disableRepeatAndCancelAll(
                dismissOverlay: false,
              );
              ForegroundAlarmOverlay.cancel();
              if (!mounted) return;
              setState(() {
                _lastScheduledAlarmLocal = null;
                _reserving = false; // 버튼 비활성화 상태 해제
              });
              showTopToast(
                context,
                AppLocalizations.of(context).alarmDeletedToast,
              );
            },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).appTitle),
        actions: [
          IconButton(
            tooltip: AppLocalizations.of(context).settingsTooltip,
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).pushNamed('/settings'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 220,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Center(
                child: _busy
                    ? const SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                          strokeWidth: 3,
                        ),
                      )
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_error != null) ...[
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white),
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.white70),
                                ),
                                onPressed: _busy ? null : _prepare,
                                child: Text(AppLocalizations.of(context).retry),
                              ),
                            ] else ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFFFFFFF,
                                  ).withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  AppLocalizations.of(context).nextSunrise,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.wb_sunny,
                                    color: Colors.white,
                                    size: 64,
                                  ),
                                  const SizedBox(width: 12),
                                  ValueListenableBuilder<bool>(
                                    valueListenable: appTime24h,
                                    builder: (context, is24h, __) {
                                      final text = nextSunriseLocal != null
                                          ? (is24h
                                                ? fmt.fmtHM(nextSunriseLocal!)
                                                : fmt.fmtJmIntl(
                                                    nextSunriseLocal!,
                                                    Localizations.localeOf(
                                                      context,
                                                    ),
                                                  ))
                                          : '--:--';
                                      return Text(
                                        text,
                                        style: Theme.of(context)
                                            .textTheme
                                            .displayLarge
                                            ?.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 64,
                                            ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Column(
                                children: [
                                  Text(
                                    fmt.fmtYMDWIntl(
                                      DateTime.now(),
                                      Localizations.localeOf(context),
                                    ),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(color: Colors.white70),
                                  ),
                                  if ((_placeLabel ?? '').isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      _placeLabel!,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(color: Colors.white70),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
            // 오프셋 선택 (일출 전/후 5~60분, 5분 단위)
            if (nextSunriseLocal != null && _targetLoc != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppLocalizations.of(context).alarmTime,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          _offsetMinutes == 0
                              ? AppLocalizations.of(context).nextSunrise
                              : '${AppLocalizations.of(context).nextSunrise} ${_offsetLabel(AppLocalizations.of(context))}',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                    Slider(
                      min: -60,
                      max: 60,
                      divisions: 24, // 5분 단위 (총 120/5)
                      value: _offsetMinutes.toDouble(),
                      label: _offsetLabel(AppLocalizations.of(context)),
                      onChanged: (v) {
                        setState(() {
                          _offsetMinutes = (v / 5).round() * 5;
                        });
                      },
                    ),
                    Builder(
                      builder: (_) {
                        final res = _computeScheduleNormalized(
                          nextSunriseLocal!,
                          _targetLoc!,
                          _offsetMinutes,
                        );
                        return Row(
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 18,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            ValueListenableBuilder<bool>(
                              valueListenable: appTime24h,
                              builder: (context, is24h, __) {
                                final timeText = is24h
                                    ? fmt.fmtHM(res.scheduled)
                                    : fmt.fmtJmIntl(
                                        res.scheduled,
                                        Localizations.localeOf(context),
                                      );
                                return Text(
                                  AppLocalizations.of(
                                    context,
                                  ).previewRing(timeText),
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                );
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: (_busy || _reserving)
                    ? null
                    : () async {
                        // Confirm before scheduling
                        final l10n = AppLocalizations.of(context);
                        final locale = Localizations.localeOf(context);
                        final off = _offsetLabel(l10n);
                        tz.TZDateTime? preview;
                        if (nextSunriseLocal != null && _targetLoc != null) {
                          preview = _computeScheduleNormalized(
                            nextSunriseLocal!,
                            _targetLoc!,
                            _offsetMinutes,
                          ).scheduled;
                        }
                        final ok = await _confirm(
                          title: l10n.confirmReserveTitle,
                          message: preview == null
                              ? l10n.confirmReserveMsgExact(off)
                              : l10n.confirmReserveMsg(
                                  off,
                                  (appTime24h.value
                                      ? fmt.fmtHM(preview)
                                      : fmt.fmtJmIntl(preview, locale)),
                                ),
                          confirmText: l10n.reserve,
                          cancelText: l10n.cancel,
                        );
                        if (!mounted) return;
                        if (ok) {
                          await _addNewAlarmFromCurrent();
                        }
                      },
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(64),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                child: Text(AppLocalizations.of(context).reserveAlarm),
              ),
            ),
            const SizedBox(height: 16),
            _buildReservedSection(),
          ],
        ),
      ),
    );
  }

  // Stop dialog replaced by overlay for zero-gap audio

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    appLocale.removeListener(_onLocaleChanged);
    _ticker?.cancel();
    super.dispose();
  }
}

// 알람 목록/진단 등 부가 기능은 최소화 모드에서 제거되었습니다.
// 알람 목록/진단 등 부가 기능은 최소화 모드에서 제거되었습니다.

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:geocoding/geocoding.dart' as geocoding;
import '../services/sunrise_service.dart';
import '../services/alarm_service.dart';
import '../services/timezone_service.dart';
import '../main.dart';
import '../utils/formatters.dart' as fmt;
import '../utils/toast.dart' show showTopToast;
import '../widgets/reserved_alarm_card.dart';
import '../models/schedule_result.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
  // 마지막으로 예약한 알람의 로컬 시각 (표시용)
  DateTime? _lastScheduledAlarmLocal;
  Timer? _ticker;
  // 일출 기준 예약 오프셋 (분). 음수=전, 양수=후
  int _offsetMinutes = 0; // 기본: 정각

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
    // 1) 위치 서비스 켜짐 여부
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      setState(() {
        _busy = false;
        _error = '위치 서비스가 꺼져 있어요. 위치 서비스를 켠 뒤 다시 시도해 주세요.';
      });
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('위치 서비스가 꺼져 있어요.'),
          action: SnackBarAction(
            label: '설정 열기',
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
        _error = '위치 권한이 필요합니다. 앱 설정에서 권한을 허용해 주세요.';
      });
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('위치 권한이 필요합니다.'),
          action: SnackBarAction(
            label: '앱 설정',
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
    // 첫 프레임 이후 비동기 준비 시작 (빌드 블로킹 최소화)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _prepare();
    });
    // 남은 시간 갱신 타이머 (60초, 배터리 절약)
    _ticker = Timer.periodic(const Duration(seconds: 60), (_) {
      if (!mounted) return;
      // 남은 시간 텍스트만 갱신되도록 setState 호출
      setState(() {});
    });
  }

  Future<void> _prepare() async {
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
            _error = '현재 위치를 가져오지 못했습니다. 잠시 후 다시 시도하거나 야외에서 시도해 주세요.';
          });
          return;
        }
        pos = last;
      }

      // 사용자 친화적 위치 라벨 역지오코딩 (도시급까지만 표기)
      String? place;
      try {
        final placemarks = await geocoding.placemarkFromCoordinates(
          pos.latitude,
          pos.longitude,
        );
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          String? city;
          final sa = (p.subAdministrativeArea ?? '').trim(); // 시/군 (도 산하)
          final loc = (p.locality ?? '').trim(); // 일부 기기에서 시/군이 locality로 옴
          final admin = (p.administrativeArea ?? '')
              .trim(); // 서울특별시/부산광역시/경기도 등

          if (sa.isNotEmpty && (sa.endsWith('시') || sa.endsWith('군'))) {
            city = sa;
          } else if (loc.isNotEmpty &&
              (loc.endsWith('시') || loc.endsWith('군'))) {
            city = loc;
          } else if (admin.isNotEmpty &&
              (admin.endsWith('특별시') ||
                  admin.endsWith('광역시') ||
                  admin.endsWith('자치시') ||
                  admin.endsWith('시'))) {
            city = admin;
          } else if (admin.isNotEmpty) {
            city = admin; // 시 식별 실패 시 광역(도) 표시
          }

          place = city;
        }
      } catch (_) {
        // 역지오코딩 실패는 무시 (라벨만 비워둠)
      }

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
      final nowLocal = tz.TZDateTime.now(targetLoc);
      final isDay = nowLocal.hour >= 6 && nowLocal.hour < 18;
      appThemeMode.value = isDay ? ThemeMode.light : ThemeMode.dark;
    } on TimeoutException catch (_) {
      setState(() => _error = '네트워크가 느려 일출 시간을 가져오지 못했습니다. 다시 시도해 주세요.');
    } catch (e) {
      setState(() => _error = '오류: $e');
    } finally {
      setState(() => _busy = false);
    }
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
    if (nextSunriseLocal == null || _targetLoc == null) {
      await _prepare();
      if (nextSunriseLocal == null || _targetLoc == null) return;
    }
    // 일출 시각(정각) 기준으로 다음 알람 예약 (기존 알람은 대체)
    final res = _computeScheduleNormalized(
      nextSunriseLocal!,
      _targetLoc!,
      _offsetMinutes,
    );
    await AlarmService.cancel();
    await AlarmService.scheduleAtZoned(res.scheduled, _targetLoc!);
    setState(() {
      _lastScheduledAlarmLocal = res.scheduled;
    });
    if (!mounted) return;
    showTopToast(context, '알람을 예약했어요.');
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

  Widget _buildReservedSection() {
    return ReservedAlarmCard(
      scheduled: _lastScheduledAlarmLocal,
      location: _targetLoc,
      onDelete: _busy
          ? null
          : () async {
              final ok = await _confirm(
                title: '알람 삭제',
                message: '예약된 알람을 삭제할까요?',
                confirmText: '삭제',
                cancelText: '유지',
              );
              if (!ok) return;
              await AlarmService.cancel();
              if (!mounted) return;
              setState(() {
                _lastScheduledAlarmLocal = null;
              });
              showTopToast(context, '알람을 삭제했어요.');
            },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sunrise Alarm')),
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
                                child: const Text('다시 시도'),
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
                                child: const Text(
                                  '다음 일출',
                                  style: TextStyle(
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
                                  Text(
                                    nextSunriseLocal != null
                                        ? fmt.fmtHM(nextSunriseLocal!)
                                        : '--:--',
                                    style: Theme.of(context)
                                        .textTheme
                                        .displayLarge
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 64,
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Column(
                                children: [
                                  Text(
                                    fmt.fmtYMDW(DateTime.now()),
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
                          '알람 시각',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          '일출 ${fmt.offsetHuman(_offsetMinutes)}',
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
                      label: fmt.offsetHuman(_offsetMinutes),
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
                            Text(
                              '예상 울림 ${fmt.fmtHM(res.scheduled)}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
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
                onPressed: _busy
                    ? null
                    : () async {
                        // Confirm before scheduling
                        String off = fmt.offsetHuman(_offsetMinutes);
                        tz.TZDateTime? preview;
                        if (nextSunriseLocal != null && _targetLoc != null) {
                          preview = _computeScheduleNormalized(
                            nextSunriseLocal!,
                            _targetLoc!,
                            _offsetMinutes,
                          ).scheduled;
                        }
                        final ok = await _confirm(
                          title: '알람 예약',
                          message: preview == null
                              ? '알람을 예약할까요?\n(일출 $off)'
                              : '알람을 예약할까요?\n(일출 $off, 예상 울림 ${fmt.fmtHM(preview)})',
                          confirmText: '예약',
                          cancelText: '취소',
                        );
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
                child: const Text('알람 예약'),
              ),
            ),
            const SizedBox(height: 16),
            _buildReservedSection(),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

// 알람 목록/진단 등 부가 기능은 최소화 모드에서 제거되었습니다.
// 알람 목록/진단 등 부가 기능은 최소화 모드에서 제거되었습니다.

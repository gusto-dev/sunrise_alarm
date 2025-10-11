import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'settings_service.dart';

class RingtoneService {
  static final AudioPlayer _player = AudioPlayer()
    ..setReleaseMode(ReleaseMode.loop);
  static bool _started = false;
  // Separate lightweight player for short previews to avoid interfering
  static AudioPlayer? _preview;
  static Timer? _previewTimer;

  static Future<void> startWithSettings({int? scheduledEpochMsUtc}) async {
    final key = await SettingsService.getNotificationSound();
    final assetPath = _mapSoundKeyToAsset(key);
    try {
      await _player.setSource(AssetSource(assetPath));
      Duration? duration;
      try {
        duration = await _player.onDurationChanged.first.timeout(
          const Duration(milliseconds: 500),
        );
      } catch (_) {
        duration = null;
      }
      if (scheduledEpochMsUtc != null) {
        final now = DateTime.now().toUtc().millisecondsSinceEpoch;
        final diffMs = now - scheduledEpochMsUtc;
        if (diffMs > 0) {
          if (duration != null && duration > Duration.zero) {
            final offset = Duration(
              milliseconds: diffMs % duration.inMilliseconds,
            );
            await _player.seek(offset);
          } else {
            await _player.seek(Duration(milliseconds: diffMs));
          }
        }
      }
      await _player.resume();
      _started = true;
    } catch (_) {
      // fallback to default alarm
      await _player.play(AssetSource('sounds/alarm.mp3'));
      _started = true;
    }
  }

  static Future<void> ensurePrepared() async {
    if (_started) return;
    final key = await SettingsService.getNotificationSound();
    final assetPath = _mapSoundKeyToAsset(key);
    try {
      await _player.setSource(AssetSource(assetPath));
      // 준비만 하고 재생은 하지 않음
    } catch (_) {
      // ignore
    }
  }

  static Future<void> ensureStarted({int? scheduledEpochMsUtc}) async {
    if (!_started) {
      await startWithSettings(scheduledEpochMsUtc: scheduledEpochMsUtc);
    }
  }

  static Future<void> stop() async {
    await _player.stop();
    _started = false;
  }

  static bool get isPlaying => _started;

  static String _mapSoundKeyToAsset(String key) {
    switch (key) {
      case 'good_morning':
        return 'sounds/good_morning.mp3';
      case 'wake_up':
        return 'sounds/wake_up.mp3';
      case 'morning_triumph':
        return 'sounds/morning_triumph.mp3';
      default:
        return 'sounds/alarm.mp3';
    }
  }

  /// Play a short, non-looping preview of the given sound key.
  /// Does not interrupt an active alarm playback. Replaces any existing preview.
  static Future<void> previewKey(
    String key, {
    Duration duration = const Duration(seconds: 3),
  }) async {
    // If an alarm is actively playing, skip preview to avoid clobbering it.
    if (_started) return;

    // Cancel any existing preview
    _previewTimer?.cancel();
    _previewTimer = null;
    try {
      await _preview?.stop();
    } catch (_) {}
    try {
      await _preview?.dispose();
    } catch (_) {}
    _preview = null;

    final p = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
    _preview = p;
    try {
      final assetPath = _mapSoundKeyToAsset(key);
      await p.setSource(AssetSource(assetPath));
      await p.resume();
      _previewTimer = Timer(duration, () async {
        try {
          await p.stop();
        } catch (_) {}
        try {
          await p.dispose();
        } catch (_) {}
        if (identical(_preview, p)) {
          _preview = null;
        }
      });
    } catch (_) {
      // Best effort: ensure we dispose the preview player on errors
      try {
        await p.dispose();
      } catch (_) {}
      if (identical(_preview, p)) {
        _preview = null;
      }
    }
  }
}

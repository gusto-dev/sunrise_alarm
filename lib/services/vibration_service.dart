import 'dart:async';
import 'dart:io' show Platform;
import 'package:vibration/vibration.dart';

class VibrationService {
  static Timer? _timer;

  /// Preview a vibration pattern for a short time based on our key.
  /// Keys: 'off'|'short'|'long'|'pattern'
  static Future<void> preview(String key) async {
    // iOS devices without Taptic Engine or simulators may not support vibration
    final hasVibrator = await Vibration.hasVibrator();
    if (!hasVibrator) return;

    final hasCustom = await Vibration.hasCustomVibrationsSupport();

    // Cancel any previous preview timer
    _timer?.cancel();
    _timer = null;

    if (key == 'off') {
      // Nothing to preview
      return;
    }

    if (hasCustom) {
      List<int>? pattern;
      switch (key) {
        case 'short':
          pattern = [0, 200, 100, 200];
          break;
        case 'long':
          pattern = [0, 800, 200, 800];
          break;
      }
      if (pattern != null) {
        if (Platform.isAndroid) {
          await Vibration.vibrate(
            pattern: pattern,
            intensities: const [128, 255, 128, 255],
          );
        } else {
          await Vibration.vibrate(pattern: pattern);
        }
        // Auto-cancel after ~2 seconds
        _timer = Timer(const Duration(seconds: 2), () async {
          try {
            await Vibration.cancel();
          } catch (_) {}
        });
      }
    } else {
      // Fallback to simple vibration pulses
      int durationMs = 200;
      switch (key) {
        case 'long':
          durationMs = 800;
          break;
      }
      await Vibration.vibrate(duration: durationMs);
    }
  }
}

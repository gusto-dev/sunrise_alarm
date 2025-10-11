import 'dart:async';
import 'package:timezone/timezone.dart' as tz;
import 'ringtone_service.dart';
import '../widgets/stop_overlay.dart';

/// Shows our in-app stop overlay exactly at the scheduled alarm time
/// when the app is in the foreground. This avoids route pushes and
/// does not interrupt audio.
class ForegroundAlarmOverlay {
  static Timer? _timer;

  /// Arm a one-shot timer to display the stop overlay at [scheduled].
  /// If another timer is already armed, it will be replaced.
  static void arm(tz.TZDateTime scheduled, {int? alarmId}) {
    cancel();
    final now = tz.TZDateTime.now(scheduled.location);
    var delay = scheduled.difference(now);
    if (delay.isNegative) {
      // If we are already past the time, show shortly.
      delay = const Duration(milliseconds: 100);
    }
    _timer = Timer(delay, () {
      // Start/ensure in-app playback and show overlay.
      RingtoneService.ensureStarted(
        scheduledEpochMsUtc: scheduled.toUtc().millisecondsSinceEpoch,
      );
      StopOverlay.show(alarmId: alarmId);
    });
  }

  /// Cancel any armed overlay timer.
  static void cancel() {
    _timer?.cancel();
    _timer = null;
  }
}

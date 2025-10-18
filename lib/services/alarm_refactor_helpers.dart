import 'package:workmanager/workmanager.dart';
import 'repeat_prefs.dart';
import 'alarm_service.dart';
import '../widgets/stop_overlay.dart';
import '../utils/constants.dart';

/// Centralized cleanup for disabling repeat and cancelling all schedules/work.
class AlarmCleanup {
  /// Disables daily repeat, cancels background work and scheduled alarms.
  /// Safe to call multiple times. Errors are swallowed by default.
  static Future<void> disableRepeatAndCancelAll({
    bool dismissOverlay = true,
  }) async {
    try {
      await RepeatPrefs.disable();
    } catch (_) {}
    try {
      await Workmanager().cancelByUniqueName(WorkTaskNames.topUp);
    } catch (_) {}
    try {
      await Workmanager().cancelAll();
    } catch (_) {}
    try {
      await AlarmService.cancelAll();
    } catch (_) {}
    if (dismissOverlay && StopOverlay.isShowing) {
      try {
        StopOverlay.hide();
      } catch (_) {}
    }
  }
}

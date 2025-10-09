import 'package:timezone/timezone.dart' as tz;

class ScheduleResult {
  final tz.TZDateTime scheduled;
  final tz.TZDateTime sunriseUsed;
  const ScheduleResult({required this.scheduled, required this.sunriseUsed});
}

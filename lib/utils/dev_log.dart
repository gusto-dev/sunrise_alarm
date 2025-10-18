import 'package:flutter/foundation.dart';

/// Development-only logs for verbose subsystems. These no-op in release.
void devLogTopUp(String message) {
  if (kReleaseMode) return;
  // ignore: avoid_print
  debugPrint(message);
}

void devLogSchedule(String message) {
  if (kReleaseMode) return;
  // ignore: avoid_print
  debugPrint(message);
}

import 'package:intl/intl.dart';
import 'dart:ui';

String fmtHM(DateTime dt) {
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

// Localized 12-hour format with AM/PM (e.g., '오전 7:05' in ko, '7:05 AM' in en)
String fmtJmIntl(DateTime dt, Locale locale) {
  final f = DateFormat.jm(locale.toString());
  return f.format(dt);
}

String fmtYMDW(DateTime dt) {
  const wk = ['월', '화', '수', '목', '금', '토', '일'];
  final y = dt.year.toString().padLeft(4, '0');
  final mo = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  final w = wk[(dt.weekday - 1) % 7];
  return '$y.$mo.$d($w)';
}

String fmtYMDWIntl(DateTime dt, Locale locale) {
  final f = DateFormat('yyyy.MM.dd(E)', locale.toString());
  return f.format(dt);
}

String offsetHuman(int v) {
  if (v == 0) return '정각';
  if (v < 0) return '${-v}분 전';
  return '$v분 후';
}

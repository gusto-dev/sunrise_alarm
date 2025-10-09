String fmtHM(DateTime dt) {
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

String fmtYMDW(DateTime dt) {
  const wk = ['월', '화', '수', '목', '금', '토', '일'];
  final y = dt.year.toString().padLeft(4, '0');
  final mo = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  final w = wk[(dt.weekday - 1) % 7];
  return '$y.$mo.$d($w)';
}

String offsetHuman(int v) {
  if (v == 0) return '정각';
  if (v < 0) return '${-v}분 전';
  return '$v분 후';
}

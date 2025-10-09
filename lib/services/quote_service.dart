class QuoteService {
  static const _quotes = [
    '오늘의 나는 어제의 나를 이긴다',
    '일찍 일어나는 새가 해를 본다',
    '작은 시작이 큰 변화를 만든다',
    '꾸준함은 재능을 이긴다',
    '포기하지 않으면 결국 도착한다',
  ];

  /// 무작위 명언 선택
  static String pick() {
    final list = [..._quotes]..shuffle();
    return list.first;
  }

  /// 불필요한 공백, 문장부호 제거
  static String _normalize(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[\p{P}\p{S}\s]+', unicode: true), '');

  /// 레벤슈타인 거리(문자열 유사도)
  static int _lev(String a, String b) {
    final m = a.length, n = b.length;
    final dp = List.generate(m + 1, (_) => List<int>.filled(n + 1, 0));
    for (var i = 0; i <= m; i++) {
      dp[i][0] = i;
    }
    for (var j = 0; j <= n; j++) {
      dp[0][j] = j;
    }
    for (var i = 1; i <= m; i++) {
      for (var j = 1; j <= n; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        dp[i][j] = [
          dp[i - 1][j] + 1, // 삭제
          dp[i][j - 1] + 1, // 삽입
          dp[i - 1][j - 1] + cost, // 치환
        ].reduce((a, b) => a < b ? a : b);
      }
    }
    return dp[m][n];
  }

  /// tolerance: 0(엄격) ~ 1(관대)
  static bool pass(String input, String target, double tolerance) {
    final A = _normalize(input);
    final B = _normalize(target);
    final dist = _lev(A, B);
    final sim = 1 - dist / (B.isEmpty ? 1 : B.length);
    final threshold = 0.9 - tolerance * 0.2; // 0.9~0.7 사이
    return sim >= threshold;
  }
}

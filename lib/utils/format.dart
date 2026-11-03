// lib/utils/format.dart
// 화면마다 따로 있던 숫자·날짜 포맷을 모은다.

/// 1234567 → "1,234,567"
String comma(num v) {
  final s = v.round().abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return (v < 0 ? '-' : '') + b.toString();
}

/// 230000 → "230,000원", null → "—"
String won(num? v) => v == null ? '—' : '${comma(v)}원';

/// 2.22 → "+2.22%", -1.5 → "-1.50%"
String signedPct(num? v, {int digits = 2}) {
  if (v == null) return '—';
  final s = v.abs().toStringAsFixed(digits);
  // -0.001 이 "-0.00%" 로 보이지 않게, 반올림해서 0 이면 부호를 떼다.
  if (double.parse(s) == 0) return '$s%';
  return v > 0 ? '+$s%' : '-$s%';
}

/// 등락 화살표. 0 이면 빈 문자열.
String arrow(num? v) => v == null || v == 0 ? '' : (v > 0 ? '▲' : '▼');

/// 원 단위 금액을 조·억으로 줄인다. 333_600_000_000_000 → "333.6조", 52_000_000_000 → "520억"
String krwCompact(num? v) {
  if (v == null) return '—';
  final a = v.abs();
  final sign = v < 0 ? '-' : '';
  if (a >= 1e12) return '$sign${_trim(a / 1e12)}조';
  if (a >= 1e8) return '$sign${comma(a / 1e8)}억';
  if (a >= 1e4) return '$sign${comma(a / 1e4)}만';
  return '$sign${comma(a)}';
}

String _trim(double v) {
  final s = v.toStringAsFixed(1);
  final dot = s.indexOf('.');
  final head = comma(int.parse(s.substring(0, dot)));
  final tail = s.substring(dot);
  return tail == '.0' ? head : '$head$tail';
}

/// "방금 전", "5분 전", "3시간 전", "어제", "11월 1일", 해가 다르면 "2025.11.01"
String relativeTime(DateTime t, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final local = t.toLocal();
  final d = n.difference(local);
  if (d.inMinutes < 1) return '방금 전';
  if (d.inMinutes < 60) return '${d.inMinutes}분 전';
  if (d.inHours < 24 && local.day == n.day) return '${d.inHours}시간 전';
  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(local.year, local.month, local.day);
  if (today.difference(day).inDays == 1) return '어제';
  if (local.year == n.year) return '${local.month}월 ${local.day}일';
  return ymd(local, sep: '.');
}

/// 2026-11-02 (sep 로 구분자 지정)
String ymd(DateTime t, {String sep = '-'}) {
  final l = t.toLocal();
  return '${l.year}$sep${_pad2(l.month)}$sep${_pad2(l.day)}';
}

/// "11/02 15:30"
String mdHm(DateTime t) {
  final l = t.toLocal();
  return '${_pad2(l.month)}/${_pad2(l.day)} ${_pad2(l.hour)}:${_pad2(l.minute)}';
}

/// 알림·피드를 날짜로 묶을 때 쓰는 제목: "오늘", "어제", "11월 1일"
String dayGroupLabel(DateTime t, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final l = t.toLocal();
  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(l.year, l.month, l.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return '오늘';
  if (diff == 1) return '어제';
  return l.year == n.year ? '${l.month}월 ${l.day}일' : ymd(l, sep: '.');
}

String _pad2(int v) => v.toString().padLeft(2, '0');

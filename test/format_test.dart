import 'package:disclosure_app/utils/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('comma / won', () {
    expect(comma(1234567), '1,234,567');
    expect(comma(-5000), '-5,000');
    expect(won(230000), '230,000원');
    expect(won(null), '—');
  });

  test('signedPct / arrow', () {
    expect(signedPct(2.2222), '+2.22%');
    expect(signedPct(-1.5), '-1.50%');
    expect(signedPct(0), '0.00%');
    expect(signedPct(-0.001), '0.00%');
    expect(arrow(1), '▲');
    expect(arrow(-1), '▼');
    expect(arrow(0), '');
  });

  test('krwCompact', () {
    expect(krwCompact(333600000000000), '333.6조');
    expect(krwCompact(43000000000000), '43조');
    expect(krwCompact(1344644100000000), '1,344.6조');
    expect(krwCompact(52000000000), '520억');
    expect(krwCompact(-2600000000), '-26억');
  });

  test('relativeTime / dayGroupLabel', () {
    final now = DateTime(2026, 11, 2, 15, 0);
    expect(relativeTime(DateTime(2026, 11, 2, 14, 58), now: now), '2분 전');
    expect(relativeTime(DateTime(2026, 11, 2, 12, 0), now: now), '3시간 전');
    expect(relativeTime(DateTime(2026, 11, 1, 20, 0), now: now), '어제');
    expect(relativeTime(DateTime(2026, 10, 29, 9, 0), now: now), '10월 29일');
    expect(relativeTime(DateTime(2025, 10, 29, 9, 0), now: now), '2025.10.29');
    expect(dayGroupLabel(DateTime(2026, 11, 2, 1, 0), now: now), '오늘');
    expect(dayGroupLabel(DateTime(2026, 11, 1, 23, 0), now: now), '어제');
    expect(dayGroupLabel(DateTime(2026, 11, 1, 23, 0).subtract(const Duration(days: 1)), now: now), '10월 31일');
  });
}

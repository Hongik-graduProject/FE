// 실제 BE 응답(2026-11-12 로컬 호출) 모양으로 새 기능 모델 파싱을 고정한다.
import 'package:disclosure_app/models/analysis_model.dart';
import 'package:disclosure_app/models/radar_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('critique', () {
    final c = CritiqueResponse.fromJson({
      'status': 'success',
      'data': {
        'grade': '하',
        'score': 2,
        'items': [
          {'code': 'MISSING_DELTA', 'severity': 'warning', 'summary': 's', 'evidence': 'e'},
          {'code': 'STRUCTURAL_CAR_BAND', 'severity': 'info', 'summary': 's', 'evidence': 'e'},
        ]
      }
    });
    expect(c.grade, '하');
    expect(c.items.where((i) => i.isWarning).length, 1);
  });

  test('track-record reads unwrapped fields and by_type', () {
    final t = TrackRecordResponse.fromJson({
      'data': {
        'total': 8, 'judged': 0, 'hits': 0, 'hit_rate': null, 'neutral': 8,
        'pending': 0, 'insufficient': 0, 'ticker': '000150', 'type': null,
        'by_type': [
          {'total': 8, 'judged': 0, 'hits': 0, 'hit_rate': null, 'neutral': 8,
           'pending': 0, 'insufficient': 0, 'type': 'event'}
        ]
      }
    });
    expect(t.record.neutral, 8);
    expect(t.record.hitRate, isNull);
    expect(t.byType.single.$1, 'event');
  });

  test('replay', () {
    final r = ReplayResponse.fromJson({
      'data': {
        'report_id': 20, 'ticker': '000150', 'disclosure_type': 'event',
        'as_of': '2026-10-26', 'base_date': '2026-10-26', 'end_date': null,
        'expected_car': 0.0, 'actual_excess_return_pct': null, 'status': 'NEUTRAL',
        'days_remaining': null,
        'series': [
          {'date': '2026-10-26', 'stock_return_pct': 0.0, 'kospi_return_pct': 0.0},
          {'date': '2026-10-27', 'stock_return_pct': 6.1947, 'kospi_return_pct': 3.0875},
        ]
      }
    });
    expect(r.status, 'NEUTRAL');
    expect(r.series.last.excessPct, closeTo(3.1072, 1e-9));
  });

  test('radar point', () {
    final p = RadarPoint.fromJson({
      'disclosure_id': 5673, 'ticker': '142760', 'name': '모아라이프플러스',
      'title': 't', 'type': 'event', 'theme': '바이오/헬스케어',
      'theta': 63.529411764705884, 'radius': 0.85, 'expected_car': null,
      'top_metric': null, 'filed_at': '2026-11-11T15:00:00Z', 'is_mine': false,
      'event': null,
    });
    expect(p.theta, closeTo(63.53, 0.01));
    expect(p.expectedCar, isNull);
    expect(p.filedAt.isUtc, isFalse);
  });
}

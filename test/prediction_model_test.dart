import 'package:disclosure_app/models/analysis_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PredictionResponse parses available=true', () {
    final p = PredictionResponse.fromJson({
      'status': 'success',
      'data': {
        'available': true,
        'ticker': '005930',
        'as_of_date': '2026-10-30',
        'close': 220500.0,
        'predicted_excess_return_60d': -0.0653839260880201,
        'predicted_percentile': 0.7623318385650224,
        'signal': 'Above Average',
        'model_agreement_score': 0.5979073243647235,
        'scenario_price_if_kospi_flat': 206082.84429759157,
        'feature_coverage': 1.0,
      },
    });
    expect(p.available, isTrue);
    expect(p.signal, 'Above Average');
    expect(p.excessReturn60d, closeTo(-0.0654, 1e-4));
    expect(p.featureCoverage, 1.0);
  });

  test('PredictionResponse parses available=false', () {
    final p = PredictionResponse.fromJson({
      'status': 'success',
      'data': {'available': false, 'ticker': '999999'},
    });
    expect(p.available, isFalse);
    expect(p.signal, isNull);
    expect(p.excessReturn60d, isNull);
  });

  test('ReportDetail parses metrics and tolerates missing', () {
    Map<String, dynamic> body(Map<String, dynamic> extra) => {
          'data': {
            'id': 5,
            'ticker': '005930',
            'is_read': true,
            'generated_at': '2026-11-02T12:41:39Z',
            ...extra,
          },
        };
    final r = ReportDetail.fromJson(body({
      'metrics': {'revenue': 333605938000000, 'yoy_op_growth': 33.2308, 'x': null},
    }));
    expect(r.metrics['revenue'], 333605938000000);
    expect(r.metrics['yoy_op_growth'], closeTo(33.23, 1e-2));
    expect(r.metrics.containsKey('x'), isFalse);
    expect(ReportDetail.fromJson(body({})).metrics, isEmpty);
  });
}

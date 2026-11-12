// lib/models/radar_model.dart — 레이더 스코프 점 (GET /radar/points, /radar/stream)
class RadarPoint {
  final int disclosureId;
  final String ticker;
  final String name;
  final String title;
  final String? type;
  final String? theme;
  final double theta; // 도(0~360)
  final double radius; // 0~1, 중심이 내 종목
  final double? expectedCar; // null 이면 리포트 없음(회색 점)
  final String? topMetric;
  final DateTime filedAt;
  final bool isMine;
  final String? event; // SSE 에서만: "disclosure" | "report"

  const RadarPoint({
    required this.disclosureId,
    required this.ticker,
    required this.name,
    required this.title,
    this.type,
    this.theme,
    required this.theta,
    required this.radius,
    this.expectedCar,
    this.topMetric,
    required this.filedAt,
    required this.isMine,
    this.event,
  });

  factory RadarPoint.fromJson(Map<String, dynamic> json) => RadarPoint(
        disclosureId: json['disclosure_id'] as int,
        ticker: json['ticker'] as String,
        name: (json['name'] as String?) ?? (json['ticker'] as String),
        title: (json['title'] as String?) ?? '',
        type: json['type'] as String?,
        theme: json['theme'] as String?,
        theta: (json['theta'] as num).toDouble(),
        radius: (json['radius'] as num).toDouble(),
        expectedCar: (json['expected_car'] as num?)?.toDouble(),
        topMetric: json['top_metric'] as String?,
        filedAt: DateTime.parse(json['filed_at'] as String).toLocal(),
        isMine: json['is_mine'] as bool? ?? false,
        event: json['event'] as String?,
      );
}

// lib/models/analysis_model.dart
class SensitiveMetric {
  final String code;
  final String displayName;
  final double beta;
  final int rank;

  const SensitiveMetric({
    required this.code,
    required this.displayName,
    required this.beta,
    required this.rank,
  });

  factory SensitiveMetric.fromJson(Map<String, dynamic> json) => SensitiveMetric(
        code: json['code'] as String,
        displayName: json['display_name'] as String,
        beta: (json['beta'] as num).toDouble(),
        rank: json['rank'] as int,
      );
}

class StockTheme {
  final int id;
  final String name;
  final double probability;
  final int rank;
  final bool isPrimary;
  final List<SensitiveMetric>? topSensitiveMetrics;

  const StockTheme({
    required this.id,
    required this.name,
    required this.probability,
    required this.rank,
    required this.isPrimary,
    this.topSensitiveMetrics,
  });

  factory StockTheme.fromJson(Map<String, dynamic> json) => StockTheme(
        id: json['id'] as int,
        name: json['name'] as String,
        probability: (json['probability'] as num).toDouble(),
        rank: json['rank'] as int,
        isPrimary: json['is_primary'] as bool,
        topSensitiveMetrics: json['top_sensitive_metrics'] != null
            ? (json['top_sensitive_metrics'] as List)
                .map((m) => SensitiveMetric.fromJson(m as Map<String, dynamic>))
                .toList()
            : null,
      );
}

class ThemesResponse {
  final String ticker;
  final String name;
  final List<StockTheme> themes;
  final String? message;
  final String? modelVersion;
  final String? predictedAt;

  const ThemesResponse({
    required this.ticker,
    required this.name,
    required this.themes,
    this.message,
    this.modelVersion,
    this.predictedAt,
  });

  bool get hasThemes => themes.isNotEmpty;

  factory ThemesResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    final ticker = data['ticker'] as String;
    return ThemesResponse(
      ticker: ticker,
      // BE ThemesResponse.name은 nullable(NON_NULL로 누락 가능) → ticker로 폴백.
      name: (data['name'] as String?) ?? ticker,
      themes: (data['themes'] as List? ?? [])
          .map((t) => StockTheme.fromJson(t as Map<String, dynamic>))
          .toList(),
      message: data['message'] as String?,
      modelVersion: data['model_version'] as String?,
      predictedAt: data['predicted_at'] as String?,
    );
  }
}

class AppliedTheme {
  final int id;
  final String name;
  final double? routingScore;

  const AppliedTheme({required this.id, required this.name, this.routingScore});

  factory AppliedTheme.fromJson(Map<String, dynamic> json) => AppliedTheme(
        id: json['id'] as int,
        name: json['name'] as String,
        routingScore: json['routing_score'] != null
            ? (json['routing_score'] as num).toDouble()
            : null,
      );
}

class AnalysisReport {
  final int id;
  final String title;
  final String summary;
  final AppliedTheme? appliedTheme;
  final double? expectedCar;
  final bool isRead;
  final String generatedAt;

  const AnalysisReport({
    required this.id,
    required this.title,
    required this.summary,
    this.appliedTheme,
    this.expectedCar,
    required this.isRead,
    required this.generatedAt,
  });

  factory AnalysisReport.fromJson(Map<String, dynamic> json) => AnalysisReport(
        id: json['id'] as int,
        title: (json['title'] as String?) ?? '',
        summary: (json['summary'] as String?) ?? '',
        appliedTheme: json['applied_theme'] != null
            ? AppliedTheme.fromJson(
                json['applied_theme'] as Map<String, dynamic>)
            : null,
        expectedCar: json['expected_car'] != null
            ? (json['expected_car'] as num).toDouble()
            : null,
        isRead: json['is_read'] as bool,
        generatedAt: json['generated_at'] as String,
      );
}

class ReportsPagination {
  final int page;
  final int size;
  final int totalCount;
  final int totalPages;
  final bool hasNext;

  const ReportsPagination({
    required this.page,
    required this.size,
    required this.totalCount,
    required this.totalPages,
    required this.hasNext,
  });

  factory ReportsPagination.fromJson(Map<String, dynamic> json) =>
      ReportsPagination(
        page: json['page'] as int,
        size: json['size'] as int,
        totalCount: json['total_count'] as int,
        totalPages: json['total_pages'] as int,
        hasNext: json['has_next'] as bool,
      );
}

class ReportsResponse {
  final String ticker;
  final List<AnalysisReport> reports;
  final ReportsPagination pagination;

  const ReportsResponse({
    required this.ticker,
    required this.reports,
    required this.pagination,
  });

  factory ReportsResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return ReportsResponse(
      ticker: data['ticker'] as String,
      reports: (data['reports'] as List)
          .map((r) => AnalysisReport.fromJson(r as Map<String, dynamic>))
          .toList(),
      pagination: ReportsPagination.fromJson(
          data['pagination'] as Map<String, dynamic>),
    );
  }
}

// ─── W-16 보고서 상세 모델 ────────────────────────────────────────────────────

class MetricContribution {
  final String metricCode;
  final String displayName;
  final double beta;
  // BE MetricContribution.raw_value는 nullable.
  final String? rawValue;
  final double delta;
  final double contribution;

  const MetricContribution({
    required this.metricCode,
    required this.displayName,
    required this.beta,
    this.rawValue,
    required this.delta,
    required this.contribution,
  });

  factory MetricContribution.fromJson(Map<String, dynamic> json) =>
      MetricContribution(
        metricCode: json['metric_code'] as String,
        displayName: json['display_name'] as String,
        beta: (json['beta'] as num).toDouble(),
        rawValue: json['raw_value'] as String?,
        delta: (json['delta'] as num).toDouble(),
        contribution: (json['contribution'] as num).toDouble(),
      );
}

class SourceDisclosure {
  // BE SourceDisclosureResponse.id는 Long(숫자)이다 → 문자열로 변환해 보관.
  final String id;
  final String title;
  final String filedAt;
  final String dartUrl;

  const SourceDisclosure({
    required this.id,
    required this.title,
    required this.filedAt,
    required this.dartUrl,
  });

  factory SourceDisclosure.fromJson(Map<String, dynamic> json) =>
      SourceDisclosure(
        id: json['id'].toString(),
        title: json['title'] as String,
        filedAt: json['filed_at'] as String,
        dartUrl: json['dart_url'] as String,
      );
}

class ReportDetail {
  final int id;
  final String ticker;
  final String name;
  final String title;
  final AppliedTheme? appliedTheme;
  final SourceDisclosure? sourceDisclosure;
  final String summary;
  // BE ReportDetailResponse.expected_car는 nullable(Double).
  final double? expectedCar;
  final double? carLower;
  final double? carUpper;
  final List<MetricContribution> metricContributions;
  final List<String> keyFindings;
  // 핵심 재무 (revenue, operating_profit, net_income, yoy_revenue_growth, yoy_op_growth). 없으면 빈 맵.
  final Map<String, num> metrics;
  final bool isRead;
  final String generatedAt;

  const ReportDetail({
    required this.id,
    required this.ticker,
    required this.name,
    required this.title,
    this.appliedTheme,
    this.sourceDisclosure,
    required this.summary,
    required this.expectedCar,
    this.carLower,
    this.carUpper,
    required this.metricContributions,
    required this.keyFindings,
    this.metrics = const {},
    required this.isRead,
    required this.generatedAt,
  });

  factory ReportDetail.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return ReportDetail(
      id: data['id'] as int,
      ticker: data['ticker'] as String,
      name: (data['name'] as String?) ?? (data['ticker'] as String),
      title: (data['title'] as String?) ?? '',
      appliedTheme: data['applied_theme'] != null
          ? AppliedTheme.fromJson(
              data['applied_theme'] as Map<String, dynamic>)
          : null,
      sourceDisclosure: data['source_disclosure'] != null
          ? SourceDisclosure.fromJson(
              data['source_disclosure'] as Map<String, dynamic>)
          : null,
      summary: (data['summary'] as String?) ?? '',
      expectedCar: (data['expected_car'] as num?)?.toDouble(),
      carLower: data['car_lower'] != null
          ? (data['car_lower'] as num).toDouble()
          : null,
      carUpper: data['car_upper'] != null
          ? (data['car_upper'] as num).toDouble()
          : null,
      metricContributions: (data['metric_contributions'] as List? ?? [])
          .map((m) => MetricContribution.fromJson(m as Map<String, dynamic>))
          .toList(),
      keyFindings: (data['key_findings'] as List? ?? [])
          .map((f) => f as String)
          .toList(),
      metrics: {
        for (final e in (data['metrics'] as Map<String, dynamic>? ?? {}).entries)
          if (e.value is num) e.key: e.value as num,
      },
      isRead: data['is_read'] as bool,
      generatedAt: data['generated_at'] as String,
    );
  }
}

/// ML 60거래일 KOSPI 대비 초과수익률 예측 (available=false면 나머지 필드 없음)
class PredictionResponse {
  final bool available;
  final String ticker;
  final String? asOfDate;
  final double? close;
  final double? excessReturn60d;
  final double? percentile;
  final String? signal;
  final double? agreementScore;
  final double? scenarioPriceKospiFlat;
  final double? featureCoverage;

  const PredictionResponse({
    required this.available,
    required this.ticker,
    this.asOfDate,
    this.close,
    this.excessReturn60d,
    this.percentile,
    this.signal,
    this.agreementScore,
    this.scenarioPriceKospiFlat,
    this.featureCoverage,
  });

  factory PredictionResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    double? d(String k) => (data[k] as num?)?.toDouble();
    return PredictionResponse(
      available: data['available'] as bool? ?? false,
      ticker: data['ticker'] as String,
      asOfDate: data['as_of_date'] as String?,
      close: d('close'),
      excessReturn60d: d('predicted_excess_return_60d'),
      percentile: d('predicted_percentile'),
      signal: data['signal'] as String?,
      agreementScore: d('model_agreement_score'),
      scenarioPriceKospiFlat: d('scenario_price_if_kospi_flat'),
      featureCoverage: d('feature_coverage'),
    );
  }
}

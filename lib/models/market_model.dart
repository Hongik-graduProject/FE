// lib/models/market_model.dart
//
// 홈 시장 요약: GET /market/summary.
// 지수 조회가 실패하면 BE 가 그 지수를 배열에서 뺀다 (오류 아님).

class MarketIndex {
  final String code;
  final String name;
  final double value;
  final double? change;
  final double? changeRate;

  const MarketIndex({
    required this.code,
    required this.name,
    required this.value,
    this.change,
    this.changeRate,
  });

  factory MarketIndex.fromJson(Map<String, dynamic> json) => MarketIndex(
        code: json['code'] as String,
        name: (json['name'] as String?) ?? json['code'] as String,
        value: (json['value'] as num).toDouble(),
        change: (json['change'] as num?)?.toDouble(),
        changeRate: (json['change_rate'] as num?)?.toDouble(),
      );
}

class HotStock {
  final String ticker;
  final String name;
  final String market;
  final int disclosureCount;

  const HotStock({
    required this.ticker,
    required this.name,
    required this.market,
    required this.disclosureCount,
  });

  factory HotStock.fromJson(Map<String, dynamic> json) => HotStock(
        ticker: json['ticker'] as String,
        name: json['name'] as String,
        market: (json['market'] as String?) ?? '',
        disclosureCount: (json['disclosure_count'] as num?)?.toInt() ?? 0,
      );
}

class MarketSummary {
  final List<MarketIndex> indices;
  final DateTime? latestDisclosureDate;
  final int? latestDisclosureCount;
  final List<HotStock> hotStocks;

  const MarketSummary({
    required this.indices,
    this.latestDisclosureDate,
    this.latestDisclosureCount,
    required this.hotStocks,
  });

  factory MarketSummary.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    final date = data['latest_disclosure_date'] as String?;
    return MarketSummary(
      indices: (data['indices'] as List? ?? [])
          .map((e) => MarketIndex.fromJson(e as Map<String, dynamic>))
          .toList(),
      // "2026-11-02" 는 KST 날짜라 시간대 변환 없이 그대로 읽는다.
      latestDisclosureDate: date == null ? null : DateTime.tryParse(date),
      latestDisclosureCount: (data['latest_disclosure_count'] as num?)?.toInt(),
      hotStocks: (data['hot_stocks'] as List? ?? [])
          .map((e) => HotStock.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

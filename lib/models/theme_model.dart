// lib/models/theme_model.dart
//
// 테마 둘러보기: GET /themes, GET /themes/{theme_id}/stocks.
// 업종 코드 규칙으로 만든 데모 테마라 종목별 "1순위 테마" 로만 묶인다.
import 'stock_model.dart';

class ThemeSummary {
  final int id;
  final String name;
  final String? description;
  final int stockCount;

  const ThemeSummary({
    required this.id,
    required this.name,
    this.description,
    required this.stockCount,
  });

  factory ThemeSummary.fromJson(Map<String, dynamic> json) => ThemeSummary(
        id: json['id'] as int,
        name: json['name'] as String,
        description: json['description'] as String?,
        stockCount: (json['stock_count'] as num?)?.toInt() ?? 0,
      );
}

/// GET /themes 응답.
class ThemeListResponse {
  final List<ThemeSummary> themes;
  const ThemeListResponse({required this.themes});

  factory ThemeListResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return ThemeListResponse(
      themes: (data['themes'] as List? ?? [])
          .map((e) => ThemeSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ThemeStockItem {
  final StockBriefItem stock;
  final double? probability;

  const ThemeStockItem({required this.stock, this.probability});

  factory ThemeStockItem.fromJson(Map<String, dynamic> json) => ThemeStockItem(
        stock: StockBriefItem.fromJson(json),
        probability: (json['probability'] as num?)?.toDouble(),
      );
}

/// GET /themes/{theme_id}/stocks 응답.
class ThemeStocksResponse {
  final ThemeSummary theme;
  final List<ThemeStockItem> items;
  final StockPagination pagination;

  const ThemeStocksResponse(
      {required this.theme, required this.items, required this.pagination});

  factory ThemeStocksResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return ThemeStocksResponse(
      theme: ThemeSummary.fromJson(data['theme'] as Map<String, dynamic>),
      items: (data['items'] as List? ?? [])
          .map((e) => ThemeStockItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      pagination:
          StockPagination.fromJson(data['pagination'] as Map<String, dynamic>),
    );
  }
}

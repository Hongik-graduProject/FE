// lib/models/stock_model.dart
//
// W-08·09·10·11·12·13·14 화면 BE 응답 매핑.
// BE는 application.yml에서 SNAKE_CASE 적용.

class StockBriefItem {
  final String ticker;
  final String name;
  final String market;
  final String? category;
  final int? currentPrice;
  final double? changeRate;
  final int? changeAmount;

  const StockBriefItem({
    required this.ticker,
    required this.name,
    required this.market,
    this.category,
    this.currentPrice,
    this.changeRate,
    this.changeAmount,
  });

  factory StockBriefItem.fromJson(Map<String, dynamic> json) => StockBriefItem(
        ticker: json['ticker'] as String,
        name: json['name'] as String,
        market: (json['market'] as String?) ?? '',
        category: json['category'] as String?,
        currentPrice: (json['current_price'] as num?)?.toInt(),
        changeRate: (json['change_rate'] as num?)?.toDouble(),
        changeAmount: (json['change_amount'] as num?)?.toInt(),
      );
}

class StockPagination {
  final int page;
  final int size;
  final int totalCount;
  final int totalPages;
  final bool hasNext;

  const StockPagination({
    required this.page,
    required this.size,
    required this.totalCount,
    required this.totalPages,
    required this.hasNext,
  });

  factory StockPagination.fromJson(Map<String, dynamic> json) => StockPagination(
        page: json['page'] as int,
        size: json['size'] as int,
        totalCount: json['total_count'] as int,
        totalPages: json['total_pages'] as int,
        hasNext: json['has_next'] as bool,
      );
}

/// §4-1 GET /stocks/search 응답.
class StockSearchResponse {
  final List<StockBriefItem> items;
  final StockPagination pagination;

  const StockSearchResponse({required this.items, required this.pagination});

  factory StockSearchResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return StockSearchResponse(
      items: (data['items'] as List? ?? [])
          .map((e) => StockBriefItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      pagination:
          StockPagination.fromJson(data['pagination'] as Map<String, dynamic>),
    );
  }
}

/// §4-2 GET /stocks/autocomplete 응답.
class StockAutocompleteResponse {
  final List<StockBriefItem> items;
  const StockAutocompleteResponse({required this.items});

  factory StockAutocompleteResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return StockAutocompleteResponse(
      items: (data['items'] as List? ?? [])
          .map((e) => StockBriefItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// §4-6 GET /stocks/ranking 응답.
class StockRankingResponse {
  final List<StockBriefItem> items;
  const StockRankingResponse({required this.items});

  factory StockRankingResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return StockRankingResponse(
      items: (data['items'] as List? ?? [])
          .map((e) => StockBriefItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// §4-3 GET /stocks/recent — 최근 검색어.
class RecentSearchItem {
  final int id;
  final String keyword;
  final String searchedAt;

  const RecentSearchItem(
      {required this.id, required this.keyword, required this.searchedAt});

  factory RecentSearchItem.fromJson(Map<String, dynamic> json) =>
      RecentSearchItem(
        id: json['id'] as int,
        keyword: json['keyword'] as String,
        searchedAt: json['searched_at'] as String? ?? '',
      );
}

class RecentSearchResponse {
  final List<RecentSearchItem> items;
  const RecentSearchResponse({required this.items});

  factory RecentSearchResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return RecentSearchResponse(
      items: (data['items'] as List? ?? [])
          .map((e) => RecentSearchItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// §4-7 GET /stocks/{ticker} 응답.
class StockDetailResponse {
  final String ticker;
  final String name;
  final String market;
  final String? category;
  final String? description;
  final String? listedAt;
  final int? currentPrice;
  final double? changeRate;
  final int? changeAmount;
  final bool isFavorite;

  const StockDetailResponse({
    required this.ticker,
    required this.name,
    required this.market,
    this.category,
    this.description,
    this.listedAt,
    this.currentPrice,
    this.changeRate,
    this.changeAmount,
    required this.isFavorite,
  });

  factory StockDetailResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return StockDetailResponse(
      ticker: data['ticker'] as String,
      name: data['name'] as String,
      market: (data['market'] as String?) ?? '',
      category: data['category'] as String?,
      description: data['description'] as String?,
      listedAt: data['listed_at'] as String?,
      currentPrice: (data['current_price'] as num?)?.toInt(),
      changeRate: (data['change_rate'] as num?)?.toDouble(),
      changeAmount: (data['change_amount'] as num?)?.toInt(),
      isFavorite: data['is_favorite'] as bool? ?? false,
    );
  }
}

/// §4-8 뉴스 항목.
class StockNewsItem {
  final int id;
  final String title;
  final String? source;
  final String url;
  final String? thumbnailUrl;
  final String publishedAt;

  const StockNewsItem({
    required this.id,
    required this.title,
    this.source,
    required this.url,
    this.thumbnailUrl,
    required this.publishedAt,
  });

  factory StockNewsItem.fromJson(Map<String, dynamic> json) => StockNewsItem(
        id: json['id'] as int,
        title: json['title'] as String? ?? '',
        source: json['source'] as String?,
        url: json['url'] as String? ?? '',
        thumbnailUrl: json['thumbnail_url'] as String?,
        publishedAt: json['published_at'] as String? ?? '',
      );
}

class StockNewsResponse {
  final List<StockNewsItem> items;
  const StockNewsResponse({required this.items});

  factory StockNewsResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return StockNewsResponse(
      items: (data['items'] as List? ?? [])
          .map((e) => StockNewsItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// §4-9 재무 항목 (sj_div = CIS/BS/CF, period = "2024" or "2024Q1" 등).
class FinanceItem {
  final String periodType; // ANNUAL | QUARTERLY
  final String period; // "2024", "2024Q1", "2024H1", "2024Q3"
  final String? sjDiv; // "CIS" | "BS" | "CF"
  final String? fsDiv; // "CFS" | "OFS"

  // 손익계산서
  final int? revenue;
  final int? costOfRevenue;
  final int? grossProfit;
  final int? sga;
  final int? operatingProfit;
  final int? nonOperatingIncome;
  final int? nonOperatingExpense;
  final int? pretaxIncome;
  final int? taxExpense;
  final int? netIncome;
  final int? controllingNetIncome;
  final int? noncontrollingNetIncome;

  // 재무상태표
  final int? currentAssets;
  final int? nonCurrentAssets;
  final int? totalAssets;
  final int? currentLiabilities;
  final int? nonCurrentLiabilities;
  final int? totalLiabilities;
  final int? capitalStock;
  final int? retainedEarnings;
  final int? totalEquity;

  // 현금흐름표
  final int? operatingCashFlow;
  final int? investingCashFlow;
  final int? financingCashFlow;
  final int? endingCash;

  // 비율
  final double? per;
  final double? pbr;
  final int? eps;
  final double? dividendYield;
  final double? roe;
  final double? roa;

  const FinanceItem({
    required this.periodType,
    required this.period,
    this.sjDiv,
    this.fsDiv,
    this.revenue,
    this.costOfRevenue,
    this.grossProfit,
    this.sga,
    this.operatingProfit,
    this.nonOperatingIncome,
    this.nonOperatingExpense,
    this.pretaxIncome,
    this.taxExpense,
    this.netIncome,
    this.controllingNetIncome,
    this.noncontrollingNetIncome,
    this.currentAssets,
    this.nonCurrentAssets,
    this.totalAssets,
    this.currentLiabilities,
    this.nonCurrentLiabilities,
    this.totalLiabilities,
    this.capitalStock,
    this.retainedEarnings,
    this.totalEquity,
    this.operatingCashFlow,
    this.investingCashFlow,
    this.financingCashFlow,
    this.endingCash,
    this.per,
    this.pbr,
    this.eps,
    this.dividendYield,
    this.roe,
    this.roa,
  });

  factory FinanceItem.fromJson(Map<String, dynamic> json) => FinanceItem(
        periodType: json['period_type'] as String,
        period: json['period'] as String,
        sjDiv: json['sj_div'] as String?,
        fsDiv: json['fs_div'] as String?,
        revenue: (json['revenue'] as num?)?.toInt(),
        costOfRevenue: (json['cost_of_revenue'] as num?)?.toInt(),
        grossProfit: (json['gross_profit'] as num?)?.toInt(),
        sga: (json['sga'] as num?)?.toInt(),
        operatingProfit: (json['operating_profit'] as num?)?.toInt(),
        nonOperatingIncome: (json['non_operating_income'] as num?)?.toInt(),
        nonOperatingExpense: (json['non_operating_expense'] as num?)?.toInt(),
        pretaxIncome: (json['pretax_income'] as num?)?.toInt(),
        taxExpense: (json['tax_expense'] as num?)?.toInt(),
        netIncome: (json['net_income'] as num?)?.toInt(),
        controllingNetIncome:
            (json['controlling_net_income'] as num?)?.toInt(),
        noncontrollingNetIncome:
            (json['noncontrolling_net_income'] as num?)?.toInt(),
        currentAssets: (json['current_assets'] as num?)?.toInt(),
        nonCurrentAssets: (json['non_current_assets'] as num?)?.toInt(),
        totalAssets: (json['total_assets'] as num?)?.toInt(),
        currentLiabilities: (json['current_liabilities'] as num?)?.toInt(),
        nonCurrentLiabilities:
            (json['non_current_liabilities'] as num?)?.toInt(),
        totalLiabilities: (json['total_liabilities'] as num?)?.toInt(),
        capitalStock: (json['capital_stock'] as num?)?.toInt(),
        retainedEarnings: (json['retained_earnings'] as num?)?.toInt(),
        totalEquity: (json['total_equity'] as num?)?.toInt(),
        operatingCashFlow: (json['operating_cash_flow'] as num?)?.toInt(),
        investingCashFlow: (json['investing_cash_flow'] as num?)?.toInt(),
        financingCashFlow: (json['financing_cash_flow'] as num?)?.toInt(),
        endingCash: (json['ending_cash'] as num?)?.toInt(),
        per: (json['per'] as num?)?.toDouble(),
        pbr: (json['pbr'] as num?)?.toDouble(),
        eps: (json['eps'] as num?)?.toInt(),
        dividendYield: (json['dividend_yield'] as num?)?.toDouble(),
        roe: (json['roe'] as num?)?.toDouble(),
        roa: (json['roa'] as num?)?.toDouble(),
      );
}

class StockFinanceResponse {
  final List<FinanceItem> items;
  const StockFinanceResponse({required this.items});

  factory StockFinanceResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return StockFinanceResponse(
      items: (data['items'] as List? ?? [])
          .map((e) => FinanceItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// §4-11 일별 시세 항목.
class StockDailyPriceItem {
  final String date; // ISO yyyy-MM-dd
  final int close;
  final int change;
  final int open;
  final int high;
  final int low;
  final int volume;
  final double? changeRate;

  const StockDailyPriceItem({
    required this.date,
    required this.close,
    required this.change,
    required this.open,
    required this.high,
    required this.low,
    required this.volume,
    this.changeRate,
  });

  factory StockDailyPriceItem.fromJson(Map<String, dynamic> json) =>
      StockDailyPriceItem(
        date: json['date'] as String,
        close: (json['close'] as num?)?.toInt() ?? 0,
        change: (json['change'] as num?)?.toInt() ?? 0,
        open: (json['open'] as num?)?.toInt() ?? 0,
        high: (json['high'] as num?)?.toInt() ?? 0,
        low: (json['low'] as num?)?.toInt() ?? 0,
        volume: (json['volume'] as num?)?.toInt() ?? 0,
        changeRate: (json['change_rate'] as num?)?.toDouble(),
      );
}

class StockDailyPriceResponse {
  final List<StockDailyPriceItem> items;
  const StockDailyPriceResponse({required this.items});

  factory StockDailyPriceResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return StockDailyPriceResponse(
      items: (data['items'] as List? ?? [])
          .map((e) => StockDailyPriceItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// §4-10 공시 항목.
class StockDisclosureItem {
  final int id;
  final String title;
  final String type;
  final String filedAt;
  final String? dartUrl;

  const StockDisclosureItem({
    required this.id,
    required this.title,
    required this.type,
    required this.filedAt,
    this.dartUrl,
  });

  factory StockDisclosureItem.fromJson(Map<String, dynamic> json) =>
      StockDisclosureItem(
        id: json['id'] as int,
        title: json['title'] as String? ?? '',
        type: json['type'] as String? ?? '',
        filedAt: json['filed_at'] as String? ?? '',
        dartUrl: json['dart_url'] as String?,
      );
}

class StockDisclosuresResponse {
  final List<StockDisclosureItem> items;
  final StockPagination pagination;

  const StockDisclosuresResponse(
      {required this.items, required this.pagination});

  factory StockDisclosuresResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return StockDisclosuresResponse(
      items: (data['items'] as List? ?? [])
          .map((e) => StockDisclosureItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      pagination:
          StockPagination.fromJson(data['pagination'] as Map<String, dynamic>),
    );
  }
}

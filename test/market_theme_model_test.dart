import 'package:disclosure_app/models/market_model.dart';
import 'package:disclosure_app/models/theme_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MarketSummary parses indices, latest disclosure, hot stocks', () {
    final m = MarketSummary.fromJson({
      'status': 'success',
      'data': {
        'indices': [
          {
            'code': 'KOSPI',
            'name': '코스피',
            'value': 5859.08,
            'change': 128.34,
            'change_rate': 2.24
          },
          {
            'code': 'KOSDAQ',
            'name': '코스닥',
            'value': 1000,
            'change': -3.1,
            'change_rate': -0.31
          },
        ],
        'latest_disclosure_date': '2026-11-02',
        'latest_disclosure_count': 399,
        'hot_stocks': [
          {
            'ticker': '005930',
            'name': '삼성전자',
            'market': 'KOSPI',
            'disclosure_count': 7
          },
        ],
      },
    });
    expect(m.indices, hasLength(2));
    expect(m.indices[1].value, 1000.0);
    expect(m.indices[1].changeRate, -0.31);
    expect(m.latestDisclosureDate, DateTime(2026, 11, 2));
    expect(m.latestDisclosureCount, 399);
    expect(m.hotStocks.single.disclosureCount, 7);
  });

  test('MarketSummary tolerates empty table and missing indices', () {
    final m = MarketSummary.fromJson({
      'data': {
        'indices': [],
        'latest_disclosure_date': null,
        'latest_disclosure_count': null,
        'hot_stocks': []
      },
    });
    expect(m.indices, isEmpty);
    expect(m.latestDisclosureDate, isNull);
    expect(m.latestDisclosureCount, isNull);
  });

  test('ThemeListResponse and ThemeStocksResponse parse', () {
    final list = ThemeListResponse.fromJson({
      'data': {
        'themes': [
          {
            'id': 14,
            'name': '소비재/유통',
            'description': '식품·의류·생활용품·유통',
            'stock_count': 357
          },
        ],
      },
    });
    expect(list.themes.single.stockCount, 357);

    final r = ThemeStocksResponse.fromJson({
      'data': {
        'theme': {
          'id': 1,
          'name': 'AI/반도체',
          'description': '반도체 제조·장비·소재',
          'stock_count': 74
        },
        'items': [
          {
            'ticker': '005930',
            'name': '삼성전자',
            'market': 'KOSPI',
            'current_price': 230000,
            'change_rate': 2.22,
            'change_amount': 5000,
            'probability': 0.6
          },
          {
            'ticker': '000660',
            'name': 'SK하이닉스',
            'market': 'KOSPI',
            'current_price': null,
            'change_rate': null,
            'change_amount': null,
            'probability': 0.55
          },
        ],
        'pagination': {
          'page': 1,
          'size': 20,
          'total_count': 74,
          'total_pages': 4,
          'has_next': true
        },
      },
    });
    expect(r.theme.name, 'AI/반도체');
    expect(r.items.first.stock.currentPrice, 230000);
    expect(r.items.first.probability, 0.6);
    expect(r.items[1].stock.currentPrice, isNull);
    expect(r.pagination.hasNext, isTrue);
  });
}

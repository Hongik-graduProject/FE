// lib/screens/company/company_detail_screen.dart — W-11~15 기업 상세 (탭 쉘)
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/stock_model.dart';
import '../../services/api_service.dart';
import 'analysis_tab.dart';

class CompanyArgs {
  final String ticker;
  final String name;
  final int? currentPrice;
  final double? changeRate;
  final int? changeAmount;
  final bool isFavorite;
  final int initialTab; // 0=정보, 1=뉴스, 2=재무, 3=공시, 4=분석

  const CompanyArgs({
    required this.ticker,
    required this.name,
    this.currentPrice,
    this.changeRate,
    this.changeAmount,
    this.isFavorite = false,
    this.initialTab = 4, // W-15 진입 기본값
  });
}

class CompanyDetailScreen extends StatefulWidget {
  const CompanyDetailScreen({super.key});

  @override
  State<CompanyDetailScreen> createState() => _CompanyDetailScreenState();
}

class _CompanyDetailScreenState extends State<CompanyDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late CompanyArgs _args;
  bool _argsInitialized = false;

  static const _tabs = ['정보', '뉴스', '재무', '공시', '분석'];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_argsInitialized) {
      final args =
          ModalRoute.of(context)?.settings.arguments as CompanyArgs?;
      _args = args ??
          const CompanyArgs(ticker: '005930', name: '삼성전자', initialTab: 4);
      _tabController = TabController(
        length: _tabs.length,
        vsync: this,
        initialIndex: _args.initialTab,
      );
      _argsInitialized = true;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildAppBar(innerBoxIsScrolled),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _InfoTab(ticker: _args.ticker),
            _NewsTab(ticker: _args.ticker),
            _FinanceTab(ticker: _args.ticker),
            _DisclosuresTab(ticker: _args.ticker),
            AnalysisTab(ticker: _args.ticker),
          ],
        ),
      ),
    );
  }

  SliverAppBar _buildAppBar(bool innerBoxIsScrolled) {
    final price = _args.currentPrice;
    final rate = _args.changeRate;
    final amount = _args.changeAmount;
    final isUp = (rate ?? 0) >= 0;
    final priceColor =
        isUp ? const Color(0xFFE53935) : const Color(0xFF1976D2);

    return SliverAppBar(
      pinned: true,
      floating: false,
      snap: false,
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF111827),
      elevation: 0,
      scrolledUnderElevation: 1,
      leading: const BackButton(),
      title: Text(
        _args.name,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: Color(0xFF111827),
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(
            _args.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: _args.isFavorite ? const Color(0xFFE53935) : const Color(0xFF9CA3AF),
          ),
          onPressed: () {
            // TODO: W-10 폴더 선택 모달
          },
        ),
      ],
      // 종목코드 + 현재가 바
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(88),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 가격 바
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Color(0xFFF3F4F6), width: 1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _args.ticker,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (price != null) ...[
                    Text(
                      '₩${_formatPrice(price)}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: priceColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (rate != null && amount != null)
                      Text(
                        '${isUp ? '▲' : '▼'} ${_formatPrice(amount.abs())} (${rate.abs().toStringAsFixed(2)}%)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: priceColor,
                        ),
                      ),
                  ] else
                    const Text(
                      '—',
                      style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                    ),
                ],
              ),
            ),
            // 탭 바
            TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF1A237E),
              unselectedLabelColor: const Color(0xFF6B7280),
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
              indicatorColor: const Color(0xFF1A237E),
              indicatorWeight: 2,
              dividerColor: const Color(0xFFE5E7EB),
              tabs: _tabs.map((t) => Tab(text: t)).toList(),
            ),
          ],
        ),
      ),
    );
  }

  String _formatPrice(int price) {
    final str = price.toString();
    final result = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) result.write(',');
      result.write(str[i]);
    }
    return result.toString();
  }
}

// ─── Info Tab (W-11) ─────────────────────────────────────────────────────────

class _InfoTab extends StatefulWidget {
  final String ticker;
  const _InfoTab({required this.ticker});

  @override
  State<_InfoTab> createState() => _InfoTabState();
}

class _InfoTabState extends State<_InfoTab>
    with AutomaticKeepAliveClientMixin {
  late Future<StockDetailResponse> _detailFuture;
  late Future<StockDailyPriceResponse> _pricesFuture;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _detailFuture = ApiService().getStockDetail(widget.ticker);
    _pricesFuture = ApiService().getStockDailyPrices(widget.ticker, days: 30);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<StockDetailResponse>(
      future: _detailFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _Err(message: snapshot.error.toString());
        }
        final s = snapshot.data!;
        final isUp = (s.changeRate ?? 0) >= 0;
        final color =
            isUp ? const Color(0xFFE53935) : const Color(0xFF1976D2);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            // 한 줄 소개
            if (s.description != null && s.description!.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  s.description!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF1A237E),
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // 가격 요약
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  s.currentPrice != null
                      ? '₩${_n(s.currentPrice!)}'
                      : '-',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(width: 8),
                if (s.changeRate != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '${isUp ? '▲' : '▼'} '
                      '${s.changeAmount != null ? _n(s.changeAmount!.abs()) : ''} '
                      '(${s.changeRate!.abs().toStringAsFixed(2)}%)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),

            // 주가 차트 (30일)
            const Text('최근 30 거래일',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            SizedBox(
              height: 220,
              child: FutureBuilder<StockDailyPriceResponse>(
                future: _pricesFuture,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(strokeWidth: 2));
                  }
                  if (snap.hasError) {
                    return _Err(message: snap.error.toString());
                  }
                  final items = snap.data!.items;
                  if (items.isEmpty) {
                    return const _Empty(label: '주가 데이터가 없습니다');
                  }
                  return _PriceChart(items: items);
                },
              ),
            ),
            const SizedBox(height: 24),

            // 기본 정보
            const Text('기본 정보',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            _kv('종목 코드', s.ticker),
            _kv('이름', s.name),
            _kv('시장', s.market),
            if (s.category != null) _kv('업종', s.category!),
            if (s.listedAt != null) _kv('상장일', s.listedAt!),
          ],
        );
      },
    );
  }
}

// ─── Price Chart ─────────────────────────────────────────────────────────────

class _PriceChart extends StatelessWidget {
  final List<StockDailyPriceItem> items;
  const _PriceChart({required this.items});

  @override
  Widget build(BuildContext context) {
    // 데이터는 최신→과거 순으로 들어옴 → x축은 과거→최신.
    final ordered = items.reversed.toList();
    final spots = <FlSpot>[];
    for (int i = 0; i < ordered.length; i++) {
      spots.add(FlSpot(i.toDouble(), ordered[i].close.toDouble()));
    }
    final minY = ordered.map((e) => e.close).reduce((a, b) => a < b ? a : b);
    final maxY = ordered.map((e) => e.close).reduce((a, b) => a > b ? a : b);
    final pad = ((maxY - minY) * 0.08).round().toDouble();
    final isUp = ordered.last.close >= ordered.first.close;
    final lineColor =
        isUp ? const Color(0xFFE53935) : const Color(0xFF1976D2);

    return LineChart(
      LineChartData(
        minY: (minY - pad).toDouble(),
        maxY: (maxY + pad).toDouble(),
        gridData: const FlGridData(
          show: true,
          drawVerticalLine: false,
        ),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              getTitlesWidget: (v, meta) => Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  '₩${_compact(v)}',
                  style: const TextStyle(
                      fontSize: 10, color: Color(0xFF6B7280)),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: (ordered.length / 5).floorToDouble().clamp(1, 999),
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i < 0 || i >= ordered.length) return const SizedBox.shrink();
                final d = ordered[i].date;
                final short = d.length >= 10 ? d.substring(5) : d; // MM-dd
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(short,
                      style: const TextStyle(
                          fontSize: 9.5, color: Color(0xFF6B7280))),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: const Border(
            bottom: BorderSide(color: Color(0xFFE5E7EB)),
            left: BorderSide(color: Color(0xFFE5E7EB)),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.25,
            color: lineColor,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: lineColor.withValues(alpha: 0.10),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots
                .map((s) {
                  final i = s.x.toInt();
                  if (i < 0 || i >= ordered.length) return null;
                  final d = ordered[i];
                  return LineTooltipItem(
                    '${d.date}\n₩${_n(d.close)}',
                    const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  );
                })
                .toList(),
          ),
        ),
      ),
    );
  }

  static String _compact(double v) {
    if (v.abs() >= 100000000) return '${(v / 100000000).toStringAsFixed(1)}억';
    if (v.abs() >= 10000) return '${(v / 10000).toStringAsFixed(1)}만';
    return v.toInt().toString();
  }
}

// ─── News Tab (W-12) ─────────────────────────────────────────────────────────

class _NewsTab extends StatefulWidget {
  final String ticker;
  const _NewsTab({required this.ticker});

  @override
  State<_NewsTab> createState() => _NewsTabState();
}

class _NewsTabState extends State<_NewsTab>
    with AutomaticKeepAliveClientMixin {
  late Future<StockNewsResponse> _future;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = ApiService().getStockNews(widget.ticker);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<StockNewsResponse>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _Err(message: snapshot.error.toString());
        }
        final items = snapshot.data!.items;
        if (items.isEmpty) return const _Empty(label: '관련 뉴스가 없습니다');
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 6),
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final n = items[i];
            return ListTile(
              title: Text(n.title,
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text('${n.source ?? ''} · ${_short(n.publishedAt)}',
                  style: const TextStyle(fontSize: 11)),
              trailing: const Icon(Icons.open_in_new_rounded,
                  size: 18, color: Color(0xFF9CA3AF)),
              onTap: n.url.isEmpty ? null : () => _openExternal(context, n.url),
            );
          },
        );
      },
    );
  }
}

// ─── Finance Tab (W-13) ──────────────────────────────────────────────────────

class _FinanceTab extends StatefulWidget {
  final String ticker;
  const _FinanceTab({required this.ticker});

  @override
  State<_FinanceTab> createState() => _FinanceTabState();
}

class _FinanceTabState extends State<_FinanceTab>
    with AutomaticKeepAliveClientMixin {
  late Future<StockFinanceResponse> _future;
  String _sjDiv = 'CIS'; // CIS | BS | CF
  String _periodType = 'QUARTERLY'; // QUARTERLY | ANNUAL

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = ApiService().getStockFinance(widget.ticker);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<StockFinanceResponse>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _Err(message: snapshot.error.toString());
        }
        final all = snapshot.data!.items;
        if (all.isEmpty) return const _Empty(label: '재무 데이터가 없습니다');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SjDivSelector(
              value: _sjDiv,
              onChanged: (v) => setState(() => _sjDiv = v),
            ),
            const SizedBox(height: 6),
            _PeriodTypeSelector(
              value: _periodType,
              onChanged: (v) => setState(() => _periodType = v),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _FinancePivotTable(
                items: all,
                sjDiv: _sjDiv,
                periodType: _periodType,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── 재무 서브탭 (손익/재무/현금흐름) ───────────────────────────────────────────

class _SjDivSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _SjDivSelector({required this.value, required this.onChanged});

  static const _opts = [
    ('CIS', '손익계산서'),
    ('BS', '재무상태표'),
    ('CF', '현금흐름표'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Wrap(
        spacing: 6,
        children: _opts
            .map((o) => ChoiceChip(
                  label: Text(o.$2,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                  selected: value == o.$1,
                  onSelected: (_) => onChanged(o.$1),
                  selectedColor:
                      const Color(0xFF1A237E).withValues(alpha: 0.12),
                  showCheckmark: false,
                ))
            .toList(),
      ),
    );
  }
}

class _PeriodTypeSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _PeriodTypeSelector({required this.value, required this.onChanged});

  static const _opts = [
    ('QUARTERLY', '분기'),
    ('ANNUAL', '연간'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: _opts
            .map(
              (o) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: OutlinedButton(
                  onPressed: () => onChanged(o.$1),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(60, 30),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    foregroundColor: value == o.$1
                        ? Colors.white
                        : const Color(0xFF374151),
                    backgroundColor: value == o.$1
                        ? const Color(0xFF1A237E)
                        : Colors.transparent,
                    side: BorderSide(
                      color: value == o.$1
                          ? const Color(0xFF1A237E)
                          : const Color(0xFFD1D5DB),
                    ),
                  ),
                  child: Text(o.$2,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

// ─── 표 — 행=항목, 열=기간 ──────────────────────────────────────────────────

typedef _Pick = String? Function(FinanceItem);

class _Row {
  final String label;
  final _Pick pick;
  final bool emphasis;
  const _Row(this.label, this.pick, {this.emphasis = false});
}

class _FinancePivotTable extends StatelessWidget {
  final List<FinanceItem> items;
  final String sjDiv;
  final String periodType;

  const _FinancePivotTable({
    required this.items,
    required this.sjDiv,
    required this.periodType,
  });

  @override
  Widget build(BuildContext context) {
    final cols = items
        .where((f) => f.periodType == periodType && (f.sjDiv ?? 'CIS') == sjDiv)
        .toList()
      ..sort((a, b) => a.period.compareTo(b.period));

    if (cols.isEmpty) {
      return const _Empty(label: '선택한 구분의 데이터가 없습니다');
    }

    final rows = _rowsFor(sjDiv);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(12),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: MediaQuery.of(context).size.width - 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _headerRow(cols),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            ...rows.map((r) => _dataRow(r, cols)),
          ],
        ),
      ),
    );
  }

  Widget _headerRow(List<FinanceItem> cols) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const SizedBox(
            width: 140,
            child: Text('항목',
                style:
                    TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
          ...cols.map(
            (c) => Container(
              width: 90,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(c.period,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A237E))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dataRow(_Row r, List<FinanceItem> cols) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              r.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: r.emphasis ? FontWeight.w700 : FontWeight.w500,
                color: const Color(0xFF111827),
              ),
            ),
          ),
          ...cols.map((c) {
            final v = r.pick(c) ?? '-';
            return Container(
              width: 90,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(v,
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight:
                          r.emphasis ? FontWeight.w700 : FontWeight.w500,
                      color: _valueColor(v))),
            );
          }),
        ],
      ),
    );
  }

  static Color _valueColor(String v) {
    if (v.startsWith('-')) return const Color(0xFF1976D2);
    return const Color(0xFF111827);
  }

  // ─── 항목 정의 ────────────────────────────────────────────────────────────

  List<_Row> _rowsFor(String sj) {
    switch (sj) {
      case 'BS':
        return [
          _Row('유동자산', (f) => _money(f.currentAssets)),
          _Row('비유동자산', (f) => _money(f.nonCurrentAssets)),
          _Row('자산총계', (f) => _money(f.totalAssets), emphasis: true),
          _Row('유동부채', (f) => _money(f.currentLiabilities)),
          _Row('비유동부채', (f) => _money(f.nonCurrentLiabilities)),
          _Row('부채총계', (f) => _money(f.totalLiabilities), emphasis: true),
          _Row('자본금', (f) => _money(f.capitalStock)),
          _Row('이익잉여금', (f) => _money(f.retainedEarnings)),
          _Row('자본총계', (f) => _money(f.totalEquity), emphasis: true),
        ];
      case 'CF':
        return [
          _Row('영업활동 현금흐름', (f) => _money(f.operatingCashFlow), emphasis: true),
          _Row('투자활동 현금흐름', (f) => _money(f.investingCashFlow)),
          _Row('재무활동 현금흐름', (f) => _money(f.financingCashFlow)),
          _Row('기말의 현금', (f) => _money(f.endingCash)),
        ];
      default: // CIS
        return [
          _Row('매출액', (f) => _money(f.revenue), emphasis: true),
          _Row('매출원가', (f) => _money(f.costOfRevenue)),
          _Row('매출총이익', (f) => _money(f.grossProfit), emphasis: true),
          _Row('판매비와관리비', (f) => _money(f.sga)),
          _Row('영업이익', (f) => _money(f.operatingProfit), emphasis: true),
          _Row('영업외수익', (f) => _money(f.nonOperatingIncome)),
          _Row('영업외비용', (f) => _money(f.nonOperatingExpense)),
          _Row('세전이익', (f) => _money(f.pretaxIncome)),
          _Row('법인세비용', (f) => _money(f.taxExpense)),
          _Row('당기순이익', (f) => _money(f.netIncome), emphasis: true),
          _Row('  지배주주순이익', (f) => _money(f.controllingNetIncome)),
          _Row('  비지배주주순이익', (f) => _money(f.noncontrollingNetIncome)),
          _Row('ROE', (f) => _pct(f.roe), emphasis: true),
          _Row('ROA', (f) => _pct(f.roa), emphasis: true),
          _Row('EPS', (f) => _intStr(f.eps)),
          _Row('PER', (f) => _num(f.per), emphasis: true),
          _Row('PBR', (f) => _num(f.pbr), emphasis: true),
        ];
    }
  }
}

String? _money(int? v) {
  if (v == null) return null;
  // 100,000,000 단위 = 1억
  if (v.abs() >= 100000000) {
    final eok = (v / 100000000).round();
    return '${_thousand(eok)}억';
  }
  if (v.abs() >= 10000) {
    final man = (v / 10000).round();
    return '${_thousand(man)}만';
  }
  return _thousand(v);
}

String _thousand(int v) =>
    v.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},');

String? _pct(double? v) =>
    v == null ? null : '${v.toStringAsFixed(1)}%';

String? _intStr(int? v) => v == null ? null : _thousand(v);

String? _num(double? v) => v?.toStringAsFixed(2);

// ─── Disclosures Tab (W-14) ─────────────────────────────────────────────────

class _DisclosuresTab extends StatefulWidget {
  final String ticker;
  const _DisclosuresTab({required this.ticker});

  @override
  State<_DisclosuresTab> createState() => _DisclosuresTabState();
}

class _DisclosuresTabState extends State<_DisclosuresTab>
    with AutomaticKeepAliveClientMixin {
  late Future<StockDisclosuresResponse> _future;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = ApiService().getStockDisclosures(widget.ticker);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<StockDisclosuresResponse>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _Err(message: snapshot.error.toString());
        }
        final items = snapshot.data!.items;
        if (items.isEmpty) return const _Empty(label: '공시가 없습니다');
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 6),
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final d = items[i];
            final url = d.dartUrl ?? '';
            return ListTile(
              leading: const Icon(Icons.article_outlined, size: 20),
              title: Text(d.title,
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text('${d.type} · ${_short(d.filedAt)}',
                  style: const TextStyle(fontSize: 11)),
              trailing: const Icon(Icons.open_in_new_rounded,
                  size: 18, color: Color(0xFF9CA3AF)),
              onTap: url.isEmpty ? null : () => _openExternal(context, url),
            );
          },
        );
      },
    );
  }
}

Future<void> _openExternal(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('링크를 열 수 없습니다')));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

Widget _kv(String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
              width: 70,
              child: Text(k,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF6B7280)))),
          Expanded(
              child: Text(v,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827)))),
        ],
      ),
    );

String _n(int v) => v.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );

String _short(String iso) {
  if (iso.length >= 10) return iso.substring(0, 10);
  return iso;
}

class _Empty extends StatelessWidget {
  final String label;
  const _Empty({required this.label});

  @override
  Widget build(BuildContext context) => Center(
        child: Text(label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
      );
}

class _Err extends StatelessWidget {
  final String message;
  const _Err({required this.message});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(message,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
        ),
      );
}

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../models/stock_model.dart';
import '../../../services/api_service.dart';
import '../../../utils/design_tokens.dart';
import '../../../utils/format.dart';
import '../../../widgets/ds.dart';
import 'segmented.dart';

/// 종목 상세 · 재무 탭 (Stitch _4). (E) 추정치와 재무 건전성 레이더는 데이터가 없어 뺐다.
class FinanceTab extends StatefulWidget {
  final String ticker;
  const FinanceTab({super.key, required this.ticker});

  @override
  State<FinanceTab> createState() => _FinanceTabState();
}

typedef _Pick = num? Function(FinanceItem);

class _Row {
  final String label;
  final _Pick pick;
  final bool emphasis;
  final bool money;
  const _Row(this.label, this.pick, {this.emphasis = false, this.money = true});
}

class _FinanceTabState extends State<FinanceTab> with AutomaticKeepAliveClientMixin {
  late Future<StockFinanceResponse> _future;
  String _sjDiv = 'CIS'; // CIS | BS | CF
  String _periodType = 'ANNUAL'; // ANNUAL | QUARTERLY

  static const _rowH = 44.0;
  static const _labelW = 112.0;
  static const _colW = 84.0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = ApiService().getStockFinance(widget.ticker);
  }

  Future<void> _refresh() async {
    setState(() { _future = ApiService().getStockFinance(widget.ticker); });
    try {
      await _future;
    } catch (_) {} // 오류는 FutureBuilder 가 보여준다.
  }

  /// "2025Q1" < "2025H1" < "2025Q3" < "2025" 시간 순. 같은 해 연간은 맨 뒤.
  static String _periodKey(String period) {
    const order = {'Q1': '1', 'H1': '2', 'Q3': '3', 'Q4': '4'};
    if (period.length < 6) return '${period}9';
    return period.substring(0, 4) + (order[period.substring(4)] ?? period.substring(4));
  }

  /// 차트에 그릴 대표 두 줄
  static List<_Row> _chartRows(String sj) => switch (sj) {
        'BS' => [_Row('자산총계', (f) => f.totalAssets), _Row('부채총계', (f) => f.totalLiabilities)],
        'CF' => [
            _Row('영업활동', (f) => f.operatingCashFlow),
            _Row('투자활동', (f) => f.investingCashFlow)
          ],
        _ => [_Row('매출액', (f) => f.revenue), _Row('영업이익', (f) => f.operatingProfit)],
      };

  static List<_Row> _rowsFor(String sj) => switch (sj) {
        'BS' => [
            _Row('유동자산', (f) => f.currentAssets),
            _Row('비유동자산', (f) => f.nonCurrentAssets),
            _Row('자산총계', (f) => f.totalAssets, emphasis: true),
            _Row('유동부채', (f) => f.currentLiabilities),
            _Row('비유동부채', (f) => f.nonCurrentLiabilities),
            _Row('부채총계', (f) => f.totalLiabilities, emphasis: true),
            _Row('자본금', (f) => f.capitalStock),
            _Row('이익잉여금', (f) => f.retainedEarnings),
            _Row('자본총계', (f) => f.totalEquity, emphasis: true),
          ],
        'CF' => [
            _Row('영업활동', (f) => f.operatingCashFlow, emphasis: true),
            _Row('투자활동', (f) => f.investingCashFlow),
            _Row('재무활동', (f) => f.financingCashFlow),
            _Row('기말 현금', (f) => f.endingCash),
          ],
        _ => [
            _Row('매출액', (f) => f.revenue, emphasis: true),
            _Row('매출원가', (f) => f.costOfRevenue),
            _Row('매출총이익', (f) => f.grossProfit),
            _Row('판관비', (f) => f.sga),
            _Row('영업이익', (f) => f.operatingProfit, emphasis: true),
            _Row('세전이익', (f) => f.pretaxIncome),
            _Row('당기순이익', (f) => f.netIncome, emphasis: true),
            _Row('지배주주순이익', (f) => f.controllingNetIncome),
            _Row('ROE', (f) => f.roe, money: false),
            _Row('ROA', (f) => f.roa, money: false),
          ],
      };

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<StockFinanceResponse>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(AppSpace.lg),
            child: SkeletonList(count: 3, itemHeight: 160),
          );
        }
        final List<Widget> children;
        if (snapshot.hasError) {
          children = [ErrorRetry(message: snapshot.error.toString(), onRetry: _refresh)];
        } else if (snapshot.data!.items.isEmpty) {
          children = const [
            EmptyState(icon: Icons.bar_chart_rounded, title: '재무 데이터가 없어요'),
          ];
        } else {
          children = _content(snapshot.data!.items);
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, 0),
            children: children,
          ),
        );
      },
    );
  }

  List<Widget> _content(List<FinanceItem> all) {
    final cols = all
        .where((f) => f.periodType == _periodType && (f.sjDiv ?? 'CIS') == _sjDiv)
        .toList()
      ..sort((a, b) => _periodKey(a.period).compareTo(_periodKey(b.period)));

    return [
      Segmented<String>(
        options: const [('CIS', '손익계산서'), ('BS', '재무상태표'), ('CF', '현금흐름표')],
        value: _sjDiv,
        onChanged: (v) => setState(() => _sjDiv = v),
        expand: true,
      ),
      const SizedBox(height: AppSpace.sm),
      Row(children: [
        Segmented<String>(
          options: const [('ANNUAL', '연간'), ('QUARTERLY', '분기')],
          value: _periodType,
          onChanged: (v) => setState(() => _periodType = v),
        ),
        const Spacer(),
        const Text('단위: 억원 / 조원', style: AppText.labelSm),
      ]),
      const SizedBox(height: AppSpace.md),
      if (cols.isEmpty)
        const EmptyState(icon: Icons.bar_chart_rounded, title: '선택한 구분의 데이터가 없어요')
      else ...[
        _chartCard(cols),
        const SizedBox(height: AppSpace.xl),
        _tableCard(cols),
      ],
      const Disclaimer(),
    ];
  }

  Widget _chartCard(List<FinanceItem> cols) {
    final rows = _chartRows(_sjDiv);
    final recent = cols.length > 5 ? cols.sublist(cols.length - 5) : cols;
    const colors = [AppColors.brand, AppColors.accent];
    final values = [
      for (final c in recent)
        for (final r in rows) (r.pick(c) ?? 0).toDouble(),
    ];
    final maxV = values.fold<double>(0, (a, b) => b > a ? b : a);
    final minV = values.fold<double>(0, (a, b) => b < a ? b : a);

    return DsCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionTitle('${rows[0].label} · ${rows[1].label} 추이'),
        Row(children: [
          for (var i = 0; i < rows.length; i++) ...[
            Container(width: 8, height: 8, color: colors[i]),
            const SizedBox(width: 4),
            Text(rows[i].label, style: AppText.labelSm),
            const SizedBox(width: AppSpace.md),
          ],
        ]),
        const SizedBox(height: AppSpace.md),
        SizedBox(
          height: 180,
          child: BarChart(
            BarChartData(
              maxY: maxV == 0 ? 1 : maxV * 1.15,
              minY: minV * 1.15,
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) =>
                    const FlLine(color: AppColors.border, strokeWidth: 1, dashArray: [4, 4]),
              ),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 44,
                    getTitlesWidget: (v, meta) => v == meta.max
                        ? const SizedBox.shrink()
                        : Text(krwCompact(v), style: AppText.labelSm),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    getTitlesWidget: (v, meta) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(recent[v.toInt()].period, style: AppText.labelSm),
                    ),
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => AppColors.brand,
                  getTooltipItem: (group, _, rod, i) => BarTooltipItem(
                    '${rows[i].label} ${krwCompact(rod.toY)}',
                    AppText.labelMd.copyWith(color: Colors.white),
                  ),
                ),
              ),
              barGroups: [
                for (var x = 0; x < recent.length; x++)
                  BarChartGroupData(x: x, barsSpace: 4, barRods: [
                    for (var i = 0; i < rows.length; i++)
                      BarChartRodData(
                        toY: (rows[i].pick(recent[x]) ?? 0).toDouble(),
                        color: colors[i],
                        width: 12,
                        borderRadius: BorderRadius.circular(3),
                      ),
                  ]),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  /// 첫 열(항목명)은 고정, 기간 열만 가로로 스크롤한다.
  Widget _tableCard(List<FinanceItem> cols) {
    final rows = _rowsFor(_sjDiv);
    final latest = cols.length - 1;

    Widget cell(String text, {required double width, TextStyle? style, bool alignRight = true}) =>
        Container(
          width: width,
          height: _rowH,
          alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm + 4),
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.subtle))),
          child: Text(text, maxLines: 1, style: style),
        );

    String fmt(_Row r, FinanceItem c) {
      final v = r.pick(c);
      if (v == null) return '—';
      return r.money ? krwCompact(v) : '${v.toStringAsFixed(1)}%';
    }

    final header = AppText.labelMd.copyWith(color: AppColors.textTertiary);
    return DsCard(
      padding: EdgeInsets.zero,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Column(children: [
          cell('항목', width: _labelW, style: header, alignRight: false),
          for (final r in rows)
            cell(r.label,
                width: _labelW,
                alignRight: false,
                style: AppText.bodySm.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: r.emphasis ? FontWeight.w700 : FontWeight.w400)),
        ]),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true, // 최신 기간이 먼저 보이도록 오른쪽 끝에서 시작
            child: Column(children: [
              Row(children: [
                for (var i = 0; i < cols.length; i++)
                  cell(cols[i].period,
                      width: _colW,
                      style: i == latest ? header.copyWith(color: AppColors.brand) : header),
              ]),
              for (final r in rows)
                Row(children: [
                  for (var i = 0; i < cols.length; i++)
                    Builder(builder: (_) {
                      final v = r.pick(cols[i]);
                      return cell(fmt(r, cols[i]),
                          width: _colW,
                          style: AppText.bodySm.copyWith(
                            fontFeatures: AppText.numeric.fontFeatures,
                            fontWeight: r.emphasis || i == latest
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: v != null && v < 0 ? AppColors.bear : AppColors.textPrimary,
                          ));
                    }),
                ]),
            ]),
          ),
        ),
      ]),
    );
  }
}

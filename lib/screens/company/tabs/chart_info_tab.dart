import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../models/stock_model.dart';
import '../../../services/api_service.dart';
import '../../../utils/design_tokens.dart';
import '../../../utils/format.dart';
import '../../../widgets/ds.dart';
import 'segmented.dart';

/// 종목 상세 · 차트·정보 탭 (Stitch _3). 투자자 심리 레이더는 데이터가 없어 뺐다.
/// [detail] 은 상세 화면이 한 번 불러온 GET /stocks/{ticker} 를 같이 쓴다.
class ChartInfoTab extends StatefulWidget {
  final String ticker;
  final Future<StockDetailResponse> detail;
  final Future<void> Function() onReloadDetail;

  const ChartInfoTab({
    super.key,
    required this.ticker,
    required this.detail,
    required this.onReloadDetail,
  });

  @override
  State<ChartInfoTab> createState() => _ChartInfoTabState();
}

class _ChartInfoTabState extends State<ChartInfoTab>
    with AutomaticKeepAliveClientMixin {
  // 거래일 수. 1년 ≈ 250 거래일 (BE 상한과 같다).
  static const _periods = [(21, '1개월'), (63, '3개월'), (250, '1년')];

  int _days = 63;
  final _prices = <int, Future<StockDailyPriceResponse>>{};

  @override
  bool get wantKeepAlive => true;

  Future<StockDailyPriceResponse> _pricesFor(int days) => _prices.putIfAbsent(
      days, () => ApiService().getStockDailyPrices(widget.ticker, days: days));

  Future<void> _refresh() async {
    setState(_prices.clear);
    await Future.wait([
      _pricesFor(_days).then((_) {}, onError: (_) {}),
      widget.onReloadDetail(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, 0),
        children: [
          DsCard(
            child: Column(children: [
              Segmented<int>(
                options: _periods,
                value: _days,
                onChanged: (v) => setState(() => _days = v),
                expand: true,
              ),
              const SizedBox(height: AppSpace.md),
              _priceSection(),
            ]),
          ),
          const SizedBox(height: AppSpace.xl),
          FutureBuilder<StockDetailResponse>(
            future: widget.detail,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const SkeletonList(count: 2, itemHeight: 200);
              }
              if (snap.hasError) {
                return ErrorRetry(
                    message: snap.error.toString(), onRetry: widget.onReloadDetail);
              }
              final s = snap.data!;
              return Column(children: [
                _MetricsCard(detail: s),
                const SizedBox(height: AppSpace.xl),
                _OverviewCard(detail: s),
              ]);
            },
          ),
          const Disclaimer(),
        ],
      ),
    );
  }

  Widget _priceSection() {
    return FutureBuilder<StockDailyPriceResponse>(
      future: _pricesFor(_days),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SkeletonBox(height: 240, radius: AppRadius.md);
        }
        if (snap.hasError) {
          return ErrorRetry(
              message: snap.error.toString(),
              onRetry: () => setState(() { _prices.remove(_days); }));
        }
        final items = snap.data!.items;
        if (items.isEmpty) {
          return const EmptyState(icon: Icons.show_chart_rounded, title: '시세 데이터가 없어요');
        }
        // high/low 가 비어 오는 날(0)은 종가로 대신한다.
        final high = items
            .map((e) => e.high > 0 ? e.high : e.close)
            .reduce((a, b) => a > b ? a : b);
        final low = items
            .map((e) => e.low > 0 ? e.low : e.close)
            .reduce((a, b) => a < b ? a : b);
        return Column(children: [
          Row(children: [
            const Text('기간 최고 ', style: AppText.labelSm),
            Text(won(high), style: AppText.labelMd.copyWith(color: AppColors.bull)),
            const Spacer(),
            const Text('기간 최저 ', style: AppText.labelSm),
            Text(won(low), style: AppText.labelMd.copyWith(color: AppColors.bear)),
          ]),
          const SizedBox(height: AppSpace.md),
          SizedBox(height: 200, child: _PriceChart(items: items)),
        ]);
      },
    );
  }
}

class _PriceChart extends StatelessWidget {
  final List<StockDailyPriceItem> items;
  const _PriceChart({required this.items});

  @override
  Widget build(BuildContext context) {
    // 데이터는 최신→과거 순 → x축은 과거→최신.
    final ordered = items.reversed.toList();
    final spots = [
      for (var i = 0; i < ordered.length; i++)
        FlSpot(i.toDouble(), ordered[i].close.toDouble()),
    ];
    final closes = ordered.map((e) => e.close);
    final minY = closes.reduce((a, b) => a < b ? a : b).toDouble();
    final maxY = closes.reduce((a, b) => a > b ? a : b).toDouble();
    final pad = (maxY - minY) * 0.08 + 1;
    final color = AppColors.market(ordered.last.close - ordered.first.close);

    return LineChart(
      LineChartData(
        minY: minY - pad,
        maxY: maxY + pad,
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: AppColors.border, strokeWidth: 1, dashArray: [4, 4]),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (v, meta) => v == meta.min || v == meta.max
                  ? const SizedBox.shrink()
                  : Text(krwCompact(v), style: AppText.labelSm),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: (ordered.length / 4).floorToDouble().clamp(1, 999),
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i < 0 || i >= ordered.length || v == meta.max) {
                  return const SizedBox.shrink();
                }
                final d = ordered[i].date;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(d.length >= 10 ? d.substring(5) : d, style: AppText.labelSm),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            color: color,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0)],
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.brand,
            getTooltipItems: (touched) => touched.map((s) {
              final d = ordered[s.x.toInt()];
              return LineTooltipItem(
                '${d.date.length >= 10 ? d.date.substring(5) : d.date}\n${won(d.close)}',
                AppText.labelMd.copyWith(color: Colors.white),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _MetricsCard extends StatelessWidget {
  final StockDetailResponse detail;
  const _MetricsCard({required this.detail});

  @override
  Widget build(BuildContext context) {
    final s = detail;
    String times(double? v) => v == null ? '—' : '${v.toStringAsFixed(2)}배';
    return DsCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionTitle('핵심 투자 지표'),
        _row(
          _tile('시가총액', krwCompact(s.marketCap)),
          _tile('PER', times(s.per),
              info: const InfoButton(
                  title: 'PER (주가수익비율)',
                  body: '주가를 주당순이익으로 나눈 값이에요. 낮을수록 벌어들이는 이익에 비해 주가가 싸다는 뜻이에요.')),
        ),
        _row(
          _tile('PBR', times(s.pbr),
              info: const InfoButton(
                  title: 'PBR (주가순자산비율)',
                  body: '주가를 주당순자산으로 나눈 값이에요. 1보다 낮으면 회사가 가진 자산보다 주가가 싸게 거래된다는 뜻이에요.')),
          _tile('배당수익률', s.dividendYield == null ? '—' : '${s.dividendYield!.toStringAsFixed(2)}%'),
        ),
        _row(
          _tile('52주 최고', won(s.high52w), color: s.high52w == null ? null : AppColors.bull),
          _tile('52주 최저', won(s.low52w), color: s.low52w == null ? null : AppColors.bear),
          last: true,
        ),
      ]),
    );
  }

  Widget _row(Widget a, Widget b, {bool last = false}) => Padding(
        padding: EdgeInsets.only(bottom: last ? 0 : AppSpace.sm),
        child: Row(children: [
          Expanded(child: a),
          const SizedBox(width: AppSpace.sm),
          Expanded(child: b),
        ]),
      );

  Widget _tile(String label, String value, {Widget? info, Color? color}) => Container(
        padding: const EdgeInsets.all(AppSpace.sm + 4),
        decoration: BoxDecoration(
            color: AppColors.subtle, borderRadius: BorderRadius.circular(AppRadius.md)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(label, style: AppText.labelSm),
            if (info != null) ...[const SizedBox(width: 2), info],
          ]),
          const SizedBox(height: AppSpace.xs),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.numericMetric.copyWith(fontSize: 17, color: color)),
        ]),
      );
}

class _OverviewCard extends StatelessWidget {
  final StockDetailResponse detail;
  const _OverviewCard({required this.detail});

  @override
  Widget build(BuildContext context) {
    final s = detail;
    final desc = s.description ?? '';
    final listed = s.listedAt == null ? null : DateTime.tryParse(s.listedAt!);
    return DsCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionTitle('기업 개요'),
        if (desc.isNotEmpty) ...[
          Text(desc, style: AppText.bodySm),
          const SizedBox(height: AppSpace.sm),
        ],
        _kv('종목 코드', s.ticker),
        _kv('시장', s.market),
        if ((s.category ?? '').isNotEmpty) _kv('업종', s.category!),
        if (listed != null) _kv('상장일', ymd(listed, sep: '.')),
      ]),
    );
  }

  Widget _kv(String k, String v) => Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.sm + 4),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.subtle))),
        child: Row(children: [
          Text(k, style: AppText.bodySm.copyWith(color: AppColors.textTertiary)),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Text(v,
                textAlign: TextAlign.right,
                style: AppText.bodyMd.copyWith(fontWeight: FontWeight.w600)),
          ),
        ]),
      );
}

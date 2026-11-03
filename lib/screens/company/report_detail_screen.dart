// lib/screens/company/report_detail_screen.dart — W-16 분석 보고서 상세
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../models/analysis_model.dart';
import '../../services/api_service.dart';
import '../../utils/design_tokens.dart';
import '../../utils/format.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/ds.dart';

class ReportDetailScreen extends StatefulWidget {
  const ReportDetailScreen({super.key});

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  late int _reportId;
  late Future<ReportDetail> _future;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _reportId = ModalRoute.of(context)!.settings.arguments as int;
      _future = ApiService().getReportDetail(_reportId);
    }
  }

  void _retry() {
    setState(() {
      _future = ApiService().getReportDetail(_reportId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.canvas,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text('분석 보고서', style: AppText.headlineSm),
      ),
      body: FutureBuilder<ReportDetail>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(AppSpace.lg),
              child: Column(children: [
                SkeletonBox(height: 260, radius: AppRadius.lg),
                SizedBox(height: AppSpace.xl),
                SkeletonList(count: 2, itemHeight: 120),
              ]),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: ErrorRetry(
                  message: snapshot.error.toString(), onRetry: _retry),
            );
          }
          return _ReportBody(report: snapshot.data!);
        },
      ),
    );
  }
}

// ─── Body ────────────────────────────────────────────────────────────────────

class _ReportBody extends StatelessWidget {
  final ReportDetail report;
  const _ReportBody({required this.report});

  @override
  Widget build(BuildContext context) {
    final src = report.sourceDisclosure;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.lg, AppSpace.sm, AppSpace.lg, 0),
      children: [
        _HeroCard(report: report),
        if (report.metricContributions.isNotEmpty) ...[
          const SizedBox(height: AppSpace.xl),
          const SectionTitle('왜 이렇게 나왔나요?'),
          _ContributionsCard(items: report.metricContributions),
        ],
        if (_FinanceCard.hasData(report.metrics)) ...[
          const SizedBox(height: AppSpace.xl),
          const SectionTitle('핵심 재무'),
          _FinanceCard(metrics: report.metrics),
        ],
        if (report.keyFindings.isNotEmpty) ...[
          const SizedBox(height: AppSpace.xl),
          const SectionTitle('핵심 발견'),
          DsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final f in report.keyFindings)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('•  ', style: AppText.bodyMd),
                        Expanded(child: Text(f, style: AppText.bodyMd)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (src != null) ...[
          const SizedBox(height: AppSpace.xl),
          const SectionTitle('원문 공시'),
          DsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(src.title.trim(), style: AppText.labelLg),
                if (DateTime.tryParse(src.filedAt) != null) ...[
                  const SizedBox(height: AppSpace.xs),
                  Text('${ymd(DateTime.parse(src.filedAt))} 공시',
                      style: AppText.labelSm),
                ],
                const SizedBox(height: AppSpace.md),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => openExternalUrl(context, src.dartUrl),
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text('DART에서 원문 보기'),
                  ),
                ),
              ],
            ),
          ),
        ],
        const Disclaimer(),
      ],
    );
  }
}

// ─── Hero ────────────────────────────────────────────────────────────────────

String? _verdict(double? car) {
  if (car == null) return null;
  if (car >= 1.0) return '이 공시는 주가에 긍정적일 것으로 분석돼요';
  if (car > 0) return '이 공시는 주가에 소폭 긍정적일 것으로 분석돼요';
  if (car <= -1.0) return '이 공시는 주가에 부정적일 것으로 분석돼요';
  if (car < 0) return '이 공시는 주가에 소폭 부정적일 것으로 분석돼요';
  return '이 공시는 주가에 영향이 거의 없을 것으로 분석돼요';
}

class _HeroCard extends StatelessWidget {
  final ReportDetail report;
  const _HeroCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final car = report.expectedCar;
    // 공시일이 있으면 공시일, 없으면 보고서 생성일
    final date = DateTime.tryParse(
        report.sourceDisclosure?.filedAt ?? report.generatedAt);
    final verdict = _verdict(car);
    final theme = report.appliedTheme;

    return DsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${report.name} · ${report.ticker}', style: AppText.labelMd),
          const SizedBox(height: AppSpace.xs),
          Text(report.title.trim(), style: AppText.headlineMd),
          if (date != null) ...[
            const SizedBox(height: AppSpace.xs),
            Text('${ymd(date)} 공시', style: AppText.labelSm),
          ],
          if (verdict != null) ...[
            const SizedBox(height: AppSpace.md),
            Text(verdict,
                style: AppText.bodyLg.copyWith(fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: AppSpace.md),
          const Row(children: [
            Text('예상 CAR', style: AppText.labelMd),
            SizedBox(width: 4),
            InfoButton(
              title: '예상 CAR이란?',
              body: '공시가 나온 뒤 며칠 동안 주가가 시장 평균보다 얼마나 더 오르거나 '
                  '내릴지(누적 초과수익률) 예측한 값이에요. 플러스면 긍정, 마이너스면 부정적인 반응을 뜻해요.',
            ),
          ]),
          Text(
            car == null ? '분석 대기' : '${arrow(car)} ${signedPct(car, digits: 1)}'.trim(),
            style: AppText.numericHero.copyWith(color: AppColors.market(car)),
          ),
          if (car != null && report.carLower != null && report.carUpper != null) ...[
            const SizedBox(height: AppSpace.md),
            _RangeBar(
                lower: report.carLower!, upper: report.carUpper!, value: car),
            const SizedBox(height: AppSpace.xs),
            Text(
              '95% 범위 ${signedPct(report.carLower, digits: 1)} ~ ${signedPct(report.carUpper, digits: 1)}',
              style: AppText.labelSm,
            ),
          ],
          if (theme != null) ...[
            const SizedBox(height: AppSpace.md),
            Row(children: [
              Flexible(child: ThemeChip(theme.name)),
              if (theme.routingScore != null) ...[
                const SizedBox(width: AppSpace.sm),
                Text('테마 일치도 ${theme.routingScore!.toStringAsFixed(2)}',
                    style: AppText.labelMd),
              ],
            ]),
          ],
        ],
      ),
    );
  }
}

/// 95% 범위 막대: 범위 구간은 연한 색, 예측값은 점, 0 위치에 세로선.
class _RangeBar extends StatelessWidget {
  final double lower;
  final double upper;
  final double value;
  const _RangeBar(
      {required this.lower, required this.upper, required this.value});

  @override
  Widget build(BuildContext context) {
    final lo = [lower, value, 0.0].reduce(math.min);
    final hi = [upper, value, 0.0].reduce(math.max);
    final pad = (hi - lo) * 0.1 + 0.01;
    final min = lo - pad, span = hi + pad - min;
    return LayoutBuilder(builder: (context, c) {
      double x(double v) => (v - min) / span * c.maxWidth;
      return SizedBox(
        height: 16,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned(
            left: 0,
            right: 0,
            top: 6,
            height: 4,
            child: Container(
                decoration: BoxDecoration(
                    color: AppColors.subtle,
                    borderRadius: BorderRadius.circular(2))),
          ),
          Positioned(
            left: x(lower),
            width: math.max(x(upper) - x(lower), 2),
            top: 5,
            height: 6,
            child: Container(
                decoration: BoxDecoration(
                    color: AppColors.marketTint(value),
                    borderRadius: BorderRadius.circular(3))),
          ),
          Positioned(
              left: x(0) - 0.5,
              width: 1,
              top: 0,
              bottom: 0,
              child: Container(color: AppColors.borderStrong)),
          Positioned(
            left: x(value) - 5,
            top: 3,
            width: 10,
            height: 10,
            child: Container(
                decoration: BoxDecoration(
                    color: AppColors.market(value), shape: BoxShape.circle)),
          ),
        ]),
      );
    });
  }
}

// ─── 지표별 기여도 ────────────────────────────────────────────────────────────

class _ContributionsCard extends StatelessWidget {
  final List<MetricContribution> items;
  const _ContributionsCard({required this.items});

  @override
  Widget build(BuildContext context) {
    final sorted = [...items]
      ..sort((a, b) => b.contribution.abs().compareTo(a.contribution.abs()));
    final active = sorted.where((m) => m.contribution != 0).toList();
    final zero = sorted.where((m) => m.contribution == 0).toList();
    final maxAbs = active.isEmpty ? 0.0 : active.first.contribution.abs();

    return DsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final m in active) _ContributionRow(m: m, maxAbs: maxAbs),
          if (zero.isNotEmpty)
            Theme(
              data: Theme.of(context)
                  .copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                dense: true,
                title: Text('영향 없음 ${zero.length}개',
                    style: AppText.labelMd
                        .copyWith(color: AppColors.textTertiary)),
                children: [
                  for (final m in zero) _ContributionRow(m: m, maxAbs: maxAbs),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ContributionRow extends StatelessWidget {
  final MetricContribution m;
  final double maxAbs;
  const _ContributionRow({required this.m, required this.maxAbs});

  static String _signed(double v, int digits) {
    final s = v.abs().toStringAsFixed(digits);
    return v > 0 ? '+$s' : (v < 0 ? '-$s' : s);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(m.displayName, style: AppText.labelLg)),
            Text(
              '${_signed(m.contribution, 2)}%p',
              style: AppText.labelLg.copyWith(
                  color: AppColors.market(m.contribution),
                  fontFeatures: AppText.numeric.fontFeatures),
            ),
          ]),
          const SizedBox(height: 6),
          ContributionBar(value: m.contribution, maxAbs: maxAbs),
          const SizedBox(height: 4),
          Text(
            'β ${m.beta.toStringAsFixed(2)} × 변화 ${_signed(m.delta, 1)}',
            style: AppText.labelSm.copyWith(
                fontFeatures: AppText.numeric.fontFeatures),
          ),
        ],
      ),
    );
  }
}

// ─── 핵심 재무 ────────────────────────────────────────────────────────────────

class _FinanceCard extends StatelessWidget {
  final Map<String, num> metrics;
  const _FinanceCard({required this.metrics});

  static const _rows = [
    ('revenue', '매출', 'yoy_revenue_growth'),
    ('operating_profit', '영업이익', 'yoy_op_growth'),
    ('net_income', '순이익', null),
  ];

  static bool hasData(Map<String, num> m) =>
      _rows.any((r) => m.containsKey(r.$1));

  @override
  Widget build(BuildContext context) {
    return DsCard(
      child: Column(
        children: [
          for (final (key, label, yoyKey) in _rows)
            if (metrics[key] != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  Expanded(child: Text(label, style: AppText.bodySm)),
                  Text(krwCompact(metrics[key]),
                      style: AppText.labelLg.copyWith(
                          fontFeatures: AppText.numeric.fontFeatures)),
                  if (yoyKey != null && metrics[yoyKey] != null) ...[
                    const SizedBox(width: AppSpace.sm),
                    Text(
                      '(${signedPct(metrics[yoyKey], digits: 1)})',
                      style: AppText.labelMd.copyWith(
                          color: AppColors.market(metrics[yoyKey]),
                          fontFeatures: AppText.numeric.fontFeatures),
                    ),
                  ],
                ]),
              ),
          const Align(
            alignment: Alignment.centerRight,
            child: Text('괄호는 전년 대비 증감률', style: AppText.labelSm),
          ),
        ],
      ),
    );
  }
}

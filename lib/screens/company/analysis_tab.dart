// lib/screens/company/analysis_tab.dart — W-15 기업 상세 분석 탭
import 'package:flutter/material.dart';
import '../../models/analysis_model.dart';
import '../../services/api_service.dart';
import '../../utils/design_tokens.dart';
import '../../utils/format.dart';
import '../../widgets/ds.dart';

class AnalysisTab extends StatefulWidget {
  final String ticker;

  const AnalysisTab({super.key, required this.ticker});

  @override
  State<AnalysisTab> createState() => _AnalysisTabState();
}

class _AnalysisTabState extends State<AnalysisTab>
    with AutomaticKeepAliveClientMixin {
  late Future<ThemesResponse> _themesFuture;
  late Future<PredictionResponse?> _predFuture;
  late Future<ReportsResponse> _reportsFuture;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    // 섹션마다 따로 불러온다: 보고서는 첫 조회 때 생성돼 1~2초 걸리므로 테마 카드를 막지 않는다.
    _themesFuture = ApiService().getStockThemes(widget.ticker);
    // 섹션마다 FutureBuilder 가 따로 있어 예측 실패가 다른 섹션을 막지 않는다. 실패는 그 카드에서 다시 시도한다.
    _predFuture = ApiService().getStockPrediction(widget.ticker);
    _reportsFuture = ApiService().getStockReports(widget.ticker);
  }

  Future<void> _refresh() async {
    setState(_loadData);
    await Future.wait([
      _themesFuture.then((_) {}, onError: (_) {}),
      _predFuture.then((_) {}, onError: (_) {}),
      _reportsFuture.then((_) {}, onError: (_) {}),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpace.lg, AppSpace.lg, AppSpace.lg, 0),
        children: [
          FutureBuilder<ThemesResponse>(
            future: _themesFuture,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const SkeletonBox(height: 220, radius: AppRadius.lg);
              }
              if (snap.hasError) {
                return DsCard(
                  child: ErrorRetry(
                    message: snap.error.toString(),
                    onRetry: () => setState(() => _themesFuture =
                        ApiService().getStockThemes(widget.ticker)),
                  ),
                );
              }
              return _ThemeCard(res: snap.data!);
            },
          ),
          const SizedBox(height: AppSpace.md),
          _PredictionSection(
            future: _predFuture,
            onRetry: () => setState(
                () => _predFuture = ApiService().getStockPrediction(widget.ticker)),
          ),
          const SizedBox(height: AppSpace.xl),
          const SectionTitle('공시 분석 보고서'),
          FutureBuilder<ReportsResponse>(
            future: _reportsFuture,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(bottom: AppSpace.sm),
                      child: Text('공시를 분석하고 있어요', style: AppText.labelSm),
                    ),
                    SkeletonList(itemHeight: 76),
                  ],
                );
              }
              if (snap.hasError) {
                return ErrorRetry(
                  message: snap.error.toString(),
                  onRetry: () => setState(() => _reportsFuture =
                      ApiService().getStockReports(widget.ticker)),
                );
              }
              final reports = snap.data!.reports;
              if (reports.isEmpty) {
                return const EmptyState(
                  icon: Icons.description_outlined,
                  title: '최근 공시가 없어 분석 보고서가 없어요',
                );
              }
              return Column(
                children: [
                  for (final r in reports) ...[
                    _ReportRow(report: r),
                    const SizedBox(height: AppSpace.sm + 4),
                  ],
                ],
              );
            },
          ),
          const Disclaimer(),
        ],
      ),
    );
  }
}

// ─── 테마 카드 ────────────────────────────────────────────────────────────────

class _ThemeCard extends StatelessWidget {
  final ThemesResponse res;
  const _ThemeCard({required this.res});

  @override
  Widget build(BuildContext context) {
    if (!res.hasThemes) {
      return DsCard(
        child: EmptyState(
          icon: Icons.hourglass_empty_rounded,
          title: '테마 분류 대기 중',
          message: res.message ?? 'ThemeSense 학습 대상이 아닌 종목이에요',
        ),
      );
    }
    final primary = res.themes.first;
    final others = res.themes.skip(1).toList();
    final metrics = primary.topSensitiveMetrics ?? const <SensitiveMetric>[];
    final maxAbs = metrics.fold<double>(
        0, (m, e) => e.beta.abs() > m ? e.beta.abs() : m);

    return DsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Text('테마', style: AppText.headlineSm),
            Spacer(),
            DemoTag(),
          ]),
          const SizedBox(height: AppSpace.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: Text(primary.name, style: AppText.headlineMd)),
              Text(
                '${(primary.probability * 100).round()}%',
                style: AppText.numericMetric.copyWith(color: AppColors.accent),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: primary.probability.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: AppColors.subtle,
              valueColor: const AlwaysStoppedAnimation(AppColors.accent),
            ),
          ),
          if (others.isNotEmpty) ...[
            const SizedBox(height: AppSpace.sm + 4),
            Wrap(
              spacing: AppSpace.sm,
              runSpacing: AppSpace.sm,
              children: [
                for (final t in others)
                  DsPill(
                    '#${t.rank} ${t.name} ${(t.probability * 100).round()}%',
                    background: AppColors.subtle,
                    foreground: AppColors.textSecondary,
                  ),
              ],
            ),
          ],
          if (metrics.isNotEmpty) ...[
            const SizedBox(height: AppSpace.lg),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: AppSpace.md),
            const Row(children: [
              Text('핵심 민감 지표', style: AppText.labelLg),
              SizedBox(width: 4),
              InfoButton(
                title: 'β(민감도)란?',
                body: '이 지표가 1%p 변할 때 공시 반응(CAR)이 얼마나 움직이는지를 나타내요. '
                    '플러스면 지표가 오를수록 반응이 커지고, 마이너스면 작아져요.',
              ),
            ]),
            const SizedBox(height: AppSpace.sm + 4),
            for (final m in metrics) _BetaRow(metric: m, maxAbs: maxAbs),
          ],
        ],
      ),
    );
  }
}

class _BetaRow extends StatelessWidget {
  final SensitiveMetric metric;
  final double maxAbs;
  const _BetaRow({required this.metric, required this.maxAbs});

  @override
  Widget build(BuildContext context) {
    final b = metric.beta;
    final sign = b > 0 ? '+' : (b < 0 ? '-' : '');
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm + 2),
      child: Row(children: [
        SizedBox(
          width: 88,
          child: Text(metric.displayName,
              style: AppText.bodySm, overflow: TextOverflow.ellipsis),
        ),
        Expanded(child: ContributionBar(value: b, maxAbs: maxAbs, height: 6)),
        const SizedBox(width: AppSpace.sm + 4),
        SizedBox(
          width: 56,
          child: Text(
            'β $sign${b.abs().toStringAsFixed(2)}',
            textAlign: TextAlign.right,
            style: AppText.labelMd.copyWith(
                color: AppColors.market(b),
                fontFeatures: AppText.numeric.fontFeatures),
          ),
        ),
      ]),
    );
  }
}

// ─── ML 60거래일 전망 ─────────────────────────────────────────────────────────

class _PredictionSection extends StatelessWidget {
  final Future<PredictionResponse?> future;
  final VoidCallback onRetry;
  const _PredictionSection({required this.future, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PredictionResponse?>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SkeletonBox(height: 180, radius: AppRadius.lg);
        }
        if (snapshot.hasError) {
          return DsCard(
            outlined: true,
            child: ErrorRetry(message: snapshot.error.toString(), onRetry: onRetry),
          );
        }
        final p = snapshot.data;
        if (p == null || !p.available) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
            child: Text('이 종목은 ML 예측 대상이 아니에요',
                style: AppText.bodySm.copyWith(color: AppColors.textTertiary)),
          );
        }
        return _PredictionCard(prediction: p);
      },
    );
  }
}

class _PredictionCard extends StatelessWidget {
  final PredictionResponse prediction;
  const _PredictionCard({required this.prediction});

  @override
  Widget build(BuildContext context) {
    final p = prediction;
    final ret = p.excessReturn60d;
    final rank = p.percentile == null
        ? null
        : ((1 - p.percentile!) * 100).round().clamp(1, 100);
    final price = p.scenarioPriceKospiFlat;
    return DsCard(
      outlined: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Text('60거래일 전망 (ML)', style: AppText.headlineSm),
            SizedBox(width: 4),
            InfoButton(
              title: '60거래일 전망이란?',
              body: '머신러닝 모델이 앞으로 60거래일 동안 이 종목이 KOSPI보다 얼마나 '
                  '더 오르거나 덜 오를지 예측한 상대 순위예요. 공시별 예상 CAR과는 다른 예측이에요.',
            ),
          ]),
          if (rank != null) ...[
            const SizedBox(height: AppSpace.sm + 4),
            Text('KOSPI 대비 상위 $rank%',
                style: AppText.numericMetric.copyWith(color: AppColors.brand)),
          ],
          const SizedBox(height: AppSpace.sm + 4),
          if (ret != null)
            _row(
              '예상 초과수익률',
              Text(signedPct(ret * 100, digits: 1),
                  style: AppText.labelLg.copyWith(
                      color: AppColors.market(ret),
                      fontFeatures: AppText.numeric.fontFeatures)),
            ),
          if (p.agreementScore != null)
            _row('모델 일치도', _value(p.agreementScore!.toStringAsFixed(2))),
          if (price != null) _row('KOSPI 보합 가정 시 참고 가격', _value(won(price))),
          if (p.featureCoverage != null)
            _row('데이터 충족률', _value('${(p.featureCoverage! * 100).round()}%')),
          if (p.asOfDate != null) _row('기준일', _value(p.asOfDate!)),
          const SizedBox(height: AppSpace.sm),
          const Text('KOSPI 대비 상대 순위입니다', style: AppText.labelSm),
        ],
      ),
    );
  }

  Widget _value(String v) => Text(v,
      style: AppText.labelLg.copyWith(fontFeatures: AppText.numeric.fontFeatures));

  Widget _row(String label, Widget value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(child: Text(label, style: AppText.bodySm)),
          value,
        ]),
      );
}

// ─── 보고서 목록 ──────────────────────────────────────────────────────────────

class _ReportRow extends StatelessWidget {
  final AnalysisReport report;
  const _ReportRow({required this.report});

  @override
  Widget build(BuildContext context) {
    final at = DateTime.tryParse(report.generatedAt);
    return DsCard(
      padding: const EdgeInsets.all(AppSpace.md),
      onTap: () => Navigator.pushNamed(context, '/report', arguments: report.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            if (!report.isRead) ...[
              const UnreadDot(),
              const SizedBox(width: AppSpace.sm),
            ],
            Expanded(
              child: Text(
                report.title.trim(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: report.isRead
                    ? AppText.labelLg.copyWith(fontWeight: FontWeight.w500)
                    : AppText.labelLg,
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.textTertiary),
          ]),
          const SizedBox(height: AppSpace.sm),
          Row(children: [
            CarBadge(report.expectedCar),
            if (report.appliedTheme != null) ...[
              const SizedBox(width: 6),
              Flexible(child: ThemeChip(report.appliedTheme!.name)),
            ],
            const Spacer(),
            if (at != null) Text(relativeTime(at), style: AppText.labelSm),
          ]),
        ],
      ),
    );
  }
}

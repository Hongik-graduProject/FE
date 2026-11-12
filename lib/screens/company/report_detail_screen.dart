// lib/screens/company/report_detail_screen.dart — W-16 분석 보고서 상세 (Stitch "Disclosure Dossier").
// 브리핑 두 번째 문장, 시장 구분, 이벤트 코드, 시뮬레이션·추적 알림은 데모용(lib/demo).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../demo/demo_data.dart';
import '../../models/analysis_model.dart';
import '../../services/api_service.dart';
import '../../utils/design_tokens.dart';
import '../../utils/format.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/ds.dart';
import 'report_extras.dart';

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
        title: const Text('Disclosure Dossier', style: AppText.headlineMd),
        actions: [
          FutureBuilder<ReportDetail>(
            future: _future,
            builder: (context, s) => IconButton(
              tooltip: '공유',
              icon: const Icon(Icons.share_outlined),
              onPressed: s.data?.sourceDisclosure == null
                  ? null
                  : () {
                      Clipboard.setData(ClipboardData(text: s.data!.sourceDisclosure!.dartUrl));
                      ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(content: Text('공시 링크를 복사했어요')));
                    },
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(right: AppSpace.md),
            child: CircleAvatar(
              radius: 15,
              backgroundColor: AppColors.accentTint,
              child: Icon(Icons.person_outline_rounded, size: 17, color: AppColors.accent),
            ),
          ),
        ],
      ),
      body: FutureBuilder<ReportDetail>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(AppSpace.md),
              child: Column(children: [
                SkeletonBox(height: 260, radius: AppRadius.lg),
                SizedBox(height: AppSpace.xl),
                SkeletonList(count: 2, itemHeight: 120),
              ]),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: ErrorRetry(message: snapshot.error.toString(), onRetry: _retry),
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
    const gap = SizedBox(height: AppSpace.md);
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpace.md, 0, AppSpace.md, AppSpace.lg),
      children: [
        _TerminalStrip(report: report),
        gap,
        _HeroCard(report: report),
        gap,
        _BriefingPanel(report: report),
        gap,
        ReplaySection(reportId: report.id, name: report.name),
        gap,
        CritiqueSection(reportId: report.id, ticker: report.ticker),
        gap,
        _ActionRow(report: report),
        if (report.metricContributions.isNotEmpty) ...[
          const SizedBox(height: AppSpace.xl),
          const SectionTitle('지표별 기여도 상세'),
          _ContributionsCard(items: report.metricContributions),
        ],
        if (_FinanceCard.hasData(report.metrics)) ...[
          const SizedBox(height: AppSpace.xl),
          const SectionTitle('핵심 재무'),
          _FinanceCard(metrics: report.metrics),
        ],
        if (src != null) ...[
          const SizedBox(height: AppSpace.xl),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => openExternalUrl(context, src.dartUrl),
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('DART에서 원문 보기'),
            ),
          ),
        ],
        const Disclaimer(),
      ],
    );
  }
}

// ─── 터미널 줄 ────────────────────────────────────────────────────────────────

class _TerminalStrip extends StatelessWidget {
  final ReportDetail report;
  const _TerminalStrip({required this.report});

  @override
  Widget build(BuildContext context) {
    final isPeriodic = RegExp(r'보고서').hasMatch(report.title);
    const style = TextStyle(
        fontFamily: AppText.mono, fontSize: 11, letterSpacing: 0.6, color: AppColors.textSecondary, height: 1.4);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
      child: Row(children: [
        Container(width: 7, height: 7, decoration: const BoxDecoration(color: AppColors.brand, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        const Expanded(child: Text('QUANT RADAR INTEL ·\nTERMINAL ACTIVE', style: style)),
        Text('DART REF:\n${demoDartRef(report)}', style: style.copyWith(color: AppColors.textPrimary)),
        Container(width: 1, height: 26, margin: const EdgeInsets.symmetric(horizontal: 8), color: AppColors.border),
        Text(isPeriodic ? 'R-1\nREPORT' : 'C-1\nEVENT', style: style),
      ]),
    );
  }
}

// ─── Hero ────────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final ReportDetail report;
  const _HeroCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final car = report.expectedCar;
    final date = DateTime.tryParse(report.sourceDisclosure?.filedAt ?? report.generatedAt);
    final (signal, sigFg, sigBg) = car == null
        ? ('분석 대기', AppColors.textSecondary, AppColors.raised)
        : car >= 0.5
            ? ('BULLISH 시그널', AppColors.bull, AppColors.bullTint)
            : car <= -0.5
                ? ('BEARISH 시그널', AppColors.bear, AppColors.bearTint)
                : ('NEUTRAL', AppColors.textSecondary, AppColors.raised);
    final lo = report.carLower, hi = report.carUpper;

    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadow.raised,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 4, children: [
              Text(report.name, style: AppText.headlineLg),
              Text(report.ticker, style: AppText.numericMetric.copyWith(fontSize: 15, color: AppColors.textSecondary)),
              MonoBadge(demoLargeCap(report.ticker) ? 'KOSPI 대형주' : 'KOSPI 중소형', fg: AppColors.accent, bg: AppColors.accentTint),
            ]),
          ),
          MonoBadge(signal, fg: sigFg, bg: sigBg, icon: Icons.show_chart_rounded),
        ]),
        const SizedBox(height: 6),
        Text('${report.title.trim()}${date == null ? '' : ' · ${ymd(date, sep: '.')} 공시 접수'}',
            style: AppText.bodySm),
        if (report.appliedTheme != null) ...[
          const SizedBox(height: 8),
          Row(children: [
            Flexible(child: ThemeChip(report.appliedTheme!.name)),
            if (report.appliedTheme!.routingScore != null) ...[
              const SizedBox(width: 8),
              Text('테마 일치도 ${report.appliedTheme!.routingScore!.toStringAsFixed(2)}', style: AppText.monoLabel),
            ],
          ]),
        ],
        const SizedBox(height: AppSpace.md),
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              child: _HeroTile(
                label: '예상 CAR (누적초과수익)',
                info: true,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(car == null ? '분석 대기' : '${arrow(car)} ${signedPct(car, digits: 1)}',
                      style: AppText.numericHero.copyWith(color: AppColors.market(car), fontSize: 28)),
                  const SizedBox(height: 4),
                  const Text('이벤트 윈도우: T-1 ~ T+60', style: AppText.monoLabel),
                ]),
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: _HeroTile(
                label: '95% 신뢰 밴드 (CI)',
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(lo == null || hi == null ? '—' : '${signedPct(lo, digits: 1)} ~\n${signedPct(hi, digits: 1)}',
                      style: AppText.numericMetric.copyWith(fontSize: 17)),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: Container(
                      height: 6,
                      color: AppColors.raised,
                      alignment: Alignment.center,
                      child: FractionallySizedBox(
                        widthFactor: 0.62,
                        child: Container(
                          decoration: const BoxDecoration(
                              gradient: LinearGradient(colors: [Color(0xFFDCE1FF), Color(0xFFFFB4AA)])),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _HeroTile extends StatelessWidget {
  final String label;
  final Widget child;
  final bool info;
  const _HeroTile({required this.label, required this.child, this.info = false});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: AppColors.canvas,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadius.sm)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(label, style: AppText.monoLabel)),
            if (info)
              const InfoButton(
                title: '예상 CAR이란?',
                body: '공시가 나온 뒤 주가가 시장 평균보다 얼마나 더 오르거나 내릴지(누적 초과수익률) '
                    '예측한 값이에요. 플러스면 긍정, 마이너스면 부정적인 반응을 뜻해요.',
              ),
          ]),
          const SizedBox(height: 8),
          child,
        ]),
      );
}

// ─── AI 브리핑 ────────────────────────────────────────────────────────────────

class _BriefingPanel extends StatelessWidget {
  final ReportDetail report;
  const _BriefingPanel({required this.report});

  @override
  Widget build(BuildContext context) {
    final top = [...report.metricContributions]
      ..sort((a, b) => b.contribution.abs().compareTo(a.contribution.abs()));
    final sum = top.fold<double>(0, (s, m) => s + m.contribution.abs());
    final tiles = top.where((m) => m.contribution != 0).take(3).toList();
    final quote = report.summary.trim().isNotEmpty
        ? report.summary.trim()
        : (report.keyFindings.isNotEmpty ? report.keyFindings.first : report.title);
    return DossierPanel(
      icon: Icons.psychology_alt_rounded,
      title: 'AI 펀드매니저 핵심 분석 브리핑',
      badge: const MonoBadge('ALPHA ENGINE v4.2', fg: AppColors.textSecondary, bg: AppColors.raised),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: AppColors.canvas,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppRadius.sm)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('"$quote"',
                style: AppText.bodyLg.copyWith(color: const Color(0xFFFFB4AA), fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(demoBriefing(report), style: AppText.bodySm),
            for (final f in report.keyFindings.skip(report.summary.trim().isEmpty ? 1 : 0).take(3)) ...[
              const SizedBox(height: 6),
              Text('· $f', style: AppText.bodySm),
            ],
          ]),
        ),
        if (tiles.isNotEmpty) ...[
          const SizedBox(height: AppSpace.sm),
          Row(children: [
            for (var i = 0; i < tiles.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: AppColors.raised, borderRadius: BorderRadius.circular(AppRadius.sm)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tiles[i].displayName,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.monoLabel),
                    const SizedBox(height: 4),
                    Text('${signedPct(tiles[i].contribution, digits: 1)}p',
                        style: AppText.numericMetric
                            .copyWith(fontSize: 15, color: AppColors.market(tiles[i].contribution))),
                    Text('기여도 ${(tiles[i].contribution.abs() / (sum == 0 ? 1 : sum) * 100).round()}%',
                        style: AppText.monoLabel),
                  ]),
                ),
              ),
            ],
          ]),
        ],
      ]),
    );
  }
}

// ─── 하단 동작 ────────────────────────────────────────────────────────────────

class _ActionRow extends StatefulWidget {
  final ReportDetail report;
  const _ActionRow({required this.report});

  @override
  State<_ActionRow> createState() => _ActionRowState();
}

class _ActionRowState extends State<_ActionRow> {
  bool _tracking = false;

  void _simulate() {
    final base = widget.report.expectedCar ?? 0;
    var beta = 1.0;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet))),
      builder: (context) => StatefulBuilder(
        builder: (context, set) {
          final car = base * beta;
          return Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.lg, AppSpace.lg, AppSpace.xl),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('가설 시뮬레이션 조정', style: AppText.headlineMd),
              const SizedBox(height: 4),
              const Text('테마 민감도(β) 가정을 바꾸면 예상 CAR 이 어떻게 달라지는지 봅니다.', style: AppText.bodySm),
              const SizedBox(height: AppSpace.lg),
              Row(children: [
                const Text('β 배율', style: AppText.monoLabel),
                const Spacer(),
                Text('×${beta.toStringAsFixed(2)}', style: AppText.numericMetric.copyWith(fontSize: 15)),
              ]),
              Slider(value: beta, min: 0, max: 2, divisions: 40, onChanged: (v) => set(() => beta = v)),
              const SizedBox(height: AppSpace.sm),
              Row(children: [
                const Text('시뮬레이션 예상 CAR', style: AppText.labelLg),
                const Spacer(),
                Text('${arrow(car)} ${signedPct(car, digits: 1)}',
                    style: AppText.numericHero.copyWith(fontSize: 26, color: AppColors.market(car))),
              ]),
            ]),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          onPressed: _simulate,
          icon: const Icon(Icons.tune_rounded, size: 18),
          label: const Text('시뮬레이션 조정'),
        ),
      ),
      const SizedBox(width: AppSpace.sm),
      Expanded(
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          onPressed: () {
            setState(() => _tracking = !_tracking);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(_tracking ? '판정일까지 추적 알림을 보내드릴게요' : '추적 알림을 껐어요')));
          },
          icon: Icon(_tracking ? Icons.notifications_active : Icons.notification_add_outlined, size: 18),
          label: Text(_tracking ? '추적 알림 켜짐' : '추적 알림 설정'),
        ),
      ),
    ]);
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

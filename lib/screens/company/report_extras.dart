// lib/screens/company/report_extras.dart — 보고서 상세(Disclosure Dossier)의 타임머신·반박 모드 패널과
// 분석 탭의 모델 성적표. Stitch "Disclosure Radar" 시안.
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../demo/demo_data.dart';
import '../../models/analysis_model.dart';
import '../../services/api_service.dart';
import '../../utils/design_tokens.dart';
import '../../utils/format.dart';
import '../../widgets/ds.dart';

// ─── 공용 조각 ────────────────────────────────────────────────────────────────

/// 시안의 패널: 아이콘 + 제목 + 오른쪽 배지.
class DossierPanel extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final String title;
  final Widget? badge;
  final Widget child;
  const DossierPanel(
      {super.key,
      required this.icon,
      required this.title,
      required this.child,
      this.badge,
      this.iconBg = AppColors.brand});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpace.md),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: AppText.headlineSm.copyWith(fontSize: 17))),
            if (badge != null) ...[const SizedBox(width: 8), badge!],
          ]),
          const SizedBox(height: AppSpace.md),
          child,
        ]),
      );
}

class MonoBadge extends StatelessWidget {
  final String text;
  final Color fg, bg;
  final IconData? icon;
  const MonoBadge(this.text,
      {super.key, this.fg = AppColors.textSecondary, this.bg = AppColors.raised, this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 12, color: fg), const SizedBox(width: 4)],
          Flexible(
            child: Text(text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.monoBadge.copyWith(color: fg, fontSize: 10.5)),
          ),
        ]),
      );
}

/// 어두운 칸 안의 라벨 + 큰 숫자 + 보조줄.
class MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final String? sub;
  final Widget? trailing;
  const MetricTile(
      {super.key, required this.label, required this.value, this.valueColor, this.sub, this.trailing});

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
            if (trailing != null) trailing!,
          ]),
          const SizedBox(height: 6),
          Text(value,
              style: AppText.numericMetric
                  .copyWith(fontSize: 20, color: valueColor ?? AppColors.textPrimary)),
          if (sub != null) ...[
            const SizedBox(height: 4),
            Text(sub!, style: AppText.monoLabel),
          ],
        ]),
      );
}

// ─── 타임머신 리플레이 ────────────────────────────────────────────────────────

class ReplaySection extends StatefulWidget {
  final int reportId;
  final String name;
  const ReplaySection({super.key, required this.reportId, required this.name});

  @override
  State<ReplaySection> createState() => _ReplaySectionState();
}

class _ReplaySectionState extends State<ReplaySection> {
  late Future<ReplayResponse> _future = ApiService().getReplay(widget.reportId);

  void _load() {
    setState(() {
      _future = ApiService().getReplay(widget.reportId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ReplayResponse>(
      future: _future,
      builder: (context, snap) {
        final r = snap.data;
        return DossierPanel(
          icon: Icons.schedule_rounded,
          title: '타임머신 리플레이 (실시간 성적표)',
          badge: r == null ? null : _statusBadge(r),
          child: snap.connectionState == ConnectionState.waiting
              ? const SkeletonBox(height: 260, radius: AppRadius.sm)
              : snap.hasError
                  ? ErrorRetry(message: snap.error.toString(), onRetry: _load)
                  : _ReplayBody(r: r!, name: widget.name),
        );
      },
    );
  }
}

Widget _statusBadge(ReplayResponse r) => switch (r.status) {
      'HIT' => const MonoBadge('적중 (HIT)', fg: AppColors.accent, bg: AppColors.accentTint, icon: Icons.check_circle),
      'MISS' => const MonoBadge('빗나감 (MISS)', fg: AppColors.error, bg: AppColors.errorTint, icon: Icons.cancel),
      'NEUTRAL' => const MonoBadge('판정 제외 (±0.5%p 미만)', icon: Icons.remove_circle_outline),
      'PENDING' => MonoBadge('판정 대기 (D-${r.daysRemaining ?? '?'} / 60거래일)',
          fg: AppColors.textPrimary, icon: Icons.circle),
      _ => const MonoBadge('시세 부족', icon: Icons.help_outline),
    };

class _ReplayBody extends StatelessWidget {
  final ReplayResponse r;
  final String name;
  const _ReplayBody({required this.r, required this.name});

  @override
  Widget build(BuildContext context) {
    final car = r.expectedCar;
    final last = r.series.isEmpty ? null : r.series.last;
    final elapsed = math.max(0, r.series.length - 1);
    final actual = r.actualExcessReturnPct ?? last?.excessPct;
    final gap = (car != null && actual != null) ? actual - car : null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: MetricTile(
            label: 'AI 공시 직후 예측',
            value: signedPct(car, digits: 1),
            valueColor: AppColors.market(car),
            sub: '목표 CAR 지점 (T+60)',
            trailing: const Icon(Icons.track_changes_rounded, size: 16, color: AppColors.bull),
          ),
        ),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: MetricTile(
            label: r.actualExcessReturnPct != null ? '최종 KOSPI 대비 실현치' : '현재 KOSPI 대비 실현치',
            value: signedPct(actual, digits: 1),
            valueColor: AppColors.market(actual),
            sub: gap == null ? null : '괴리율 ${signedPct(gap, digits: 1)}p ($elapsed거래일 차)',
            trailing: Icon(
                (actual ?? 0) >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                size: 16,
                color: AppColors.market(actual)),
          ),
        ),
      ]),
      if (r.series.length >= 2) ...[
        const SizedBox(height: AppSpace.md),
        Row(children: [
          const Expanded(child: Text('누적 초과수익 궤적 (CAR %)', style: AppText.monoLabel)),
          _Legend(color: AppColors.accent, text: name),
          const SizedBox(width: 8),
          const _Legend(color: AppColors.flat, text: 'KOSPI'),
          const SizedBox(width: 8),
          const _Legend(color: AppColors.bull, text: 'AI 궤적', dashed: true),
        ]),
        const SizedBox(height: AppSpace.sm),
        _ReplayChart(r: r),
        const SizedBox(height: AppSpace.md),
        _Progress(elapsed: elapsed),
      ],
    ]);
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String text;
  final bool dashed;
  const _Legend({required this.color, required this.text, this.dashed = false});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        if (dashed) ...[
          Container(width: 4, height: 2, color: color),
          const SizedBox(width: 2),
          Container(width: 4, height: 2, color: color),
        ] else
          Container(width: 10, height: 2, color: color),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 64),
          child: Text(text, overflow: TextOverflow.ellipsis, style: AppText.monoLabel),
        ),
      ]);
}

/// 종목·KOSPI 누적 수익률 + AI 궤적(관측 구간은 KOSPI + CAR × t/60, 이후는 T+60 목표까지 점선과 원뿔).
class _ReplayChart extends StatelessWidget {
  final ReplayResponse r;
  const _ReplayChart({required this.r});

  @override
  Widget build(BuildContext context) {
    final s = r.series;
    final car = r.expectedCar ?? 0;
    final n = s.length;
    final kLast = s.last.kospiReturnPct;
    double ai(double i) => i < n ? s[i.toInt()].kospiReturnPct + car * i / 60 : kLast + car * i / 60;
    final aiSpots = [for (var i = 0; i < n; i++) FlSpot(i.toDouble(), ai(i.toDouble())), FlSpot(60, kLast + car)];
    final band = (car.abs() * 0.6).clamp(2.0, 12.0);
    final ys = [for (final p in s) ...[p.stockReturnPct, p.kospiReturnPct], kLast + car + band, kLast + car - band, 0.0];
    final lo = ys.reduce(math.min), hi = ys.reduce(math.max);
    final pad = (hi - lo) * 0.12 + 1;
    final lastX = (n - 1).toDouble();
    final lastStock = s.last.stockReturnPct;

    LineChartBarData line(List<FlSpot> spots, Color c,
            {double w = 2, List<int>? dash, bool area = false, Color? areaColor}) =>
        LineChartBarData(
          spots: spots,
          color: c,
          barWidth: w,
          dashArray: dash,
          isCurved: false,
          dotData: const FlDotData(show: false),
          belowBarData: area ? BarAreaData(show: true, color: areaColor) : BarAreaData(show: false),
        );

    return Container(
      height: 210,
      padding: const EdgeInsets.fromLTRB(6, 10, 10, 6),
      decoration: BoxDecoration(
          color: AppColors.canvas,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppRadius.sm)),
      child: Stack(children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 1600),
          builder: (context, t, _) {
            final k = math.max(2, (n * t).ceil());
            return LineChart(
              duration: Duration.zero,
              LineChartData(
                minX: 0,
                maxX: 60,
                minY: lo - pad,
                maxY: hi + pad,
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: 10,
                  getDrawingHorizontalLine: (_) => const FlLine(color: Color(0x14FFFFFF), strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: const FlTitlesData(show: false),
                lineTouchData: const LineTouchData(enabled: false),
                extraLinesData: ExtraLinesData(horizontalLines: [
                  HorizontalLine(y: 0, color: const Color(0x40FFFFFF), strokeWidth: 1),
                ]),
                betweenBarsData: [BetweenBarsData(fromIndex: 0, toIndex: 1, color: const Color(0x2EF04438))],
                lineBarsData: [
                  // 0,1: 원뿔 위·아래 (관측 끝에서 T+60 까지 벌어진다)
                  line([FlSpot(lastX, ai(lastX)), FlSpot(60, kLast + car + band)], Colors.transparent, w: 0),
                  line([FlSpot(lastX, ai(lastX)), FlSpot(60, kLast + car - band)], Colors.transparent, w: 0),
                  line(aiSpots, AppColors.bull, w: 1.6, dash: [4, 4]),
                  line([for (var i = 0; i < k; i++) FlSpot(i.toDouble(), s[i].kospiReturnPct)], AppColors.flat, w: 1.6),
                  line([for (var i = 0; i < k; i++) FlSpot(i.toDouble(), s[i].stockReturnPct)], AppColors.accent,
                      w: 2.4),
                ],
              ),
            );
          },
        ),
        Positioned(left: 4, top: 0, child: MonoBadge('T0: ${r.ticker} 기저', bg: const Color(0xCC0A1128))),
        Positioned(
          right: 0,
          top: 0,
          child: MonoBadge('목표 ${signedPct(car, digits: 1)} (T+60)', fg: Colors.white, bg: AppColors.bull),
        ),
        const Positioned(left: 4, bottom: 0, child: Text('T0 공시 발표', style: AppText.monoBadge)),
        Positioned(
          right: 0,
          bottom: 0,
          child: MonoBadge('경과 T+${n - 1}: ${signedPct(lastStock - kLast, digits: 1)}',
              fg: AppColors.textPrimary, bg: AppColors.raised),
        ),
      ]),
    );
  }
}

class _Progress extends StatelessWidget {
  final int elapsed;
  const _Progress({required this.elapsed});

  @override
  Widget build(BuildContext context) {
    final f = (elapsed / 60).clamp(0.0, 1.0);
    return Column(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Stack(children: [
          Container(height: 8, color: AppColors.raised),
          FractionallySizedBox(
            widthFactor: f,
            child: Container(
              height: 8,
              decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.brand, Color(0xFFDCE1FF)])),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 6),
      Row(children: [
        const Text('T0 (공시일)', style: AppText.monoLabel),
        const Spacer(),
        Text('T+$elapsed (${elapsed >= 60 ? '종결' : '오늘'})',
            style: AppText.monoLabel.copyWith(color: AppColors.textPrimary)),
        const Spacer(),
        const Text('T+60 (종결일)', style: AppText.monoLabel),
      ]),
    ]);
  }
}

// ─── 반박 모드 ────────────────────────────────────────────────────────────────

class CritiqueSection extends StatefulWidget {
  final int reportId;
  final String ticker;
  const CritiqueSection({super.key, required this.reportId, required this.ticker});

  @override
  State<CritiqueSection> createState() => _CritiqueSectionState();
}

class _CritiqueSectionState extends State<CritiqueSection> {
  late Future<(CritiqueResponse, TrackRecordResponse?)> _future = _fetch();

  Future<(CritiqueResponse, TrackRecordResponse?)> _fetch() async {
    final c = ApiService().getCritique(widget.reportId);
    // 전적은 부가 정보라 실패해도 반박 카드는 보여준다.
    final t = ApiService().getTrackRecord(widget.ticker).then<TrackRecordResponse?>((v) => v,
        onError: (_) => null);
    return (await c, await t);
  }

  void _load() {
    setState(() {
      _future = _fetch();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(CritiqueResponse, TrackRecordResponse?)>(
      future: _future,
      builder: (context, snap) => DossierPanel(
        icon: Icons.gavel_rounded,
        iconBg: const Color(0xFFB42318),
        title: '"이 분석이 틀렸다면?" (자가 검증)',
        badge: const MonoBadge('SELF-CRITIQUE MODE', fg: AppColors.bull, bg: AppColors.bullTint),
        child: snap.connectionState == ConnectionState.waiting
            ? const SkeletonBox(height: 280, radius: AppRadius.sm)
            : snap.hasError
                ? ErrorRetry(message: snap.error.toString(), onRetry: _load)
                : _CritiqueBody(c: snap.data!.$1, t: snap.data!.$2, ticker: widget.ticker),
      ),
    );
  }
}

class _CritiqueBody extends StatelessWidget {
  final CritiqueResponse c;
  final TrackRecordResponse? t;
  final String ticker;
  const _CritiqueBody({required this.c, required this.t, required this.ticker});

  static const _segments = 8;

  @override
  Widget build(BuildContext context) {
    final (gradeColor, gradeBg, verdict, note) = switch (c.grade) {
      '상' => (AppColors.accent, AppColors.accentTint, '근거 견고 판정', '신뢰 점수가 상위 구간입니다. 핵심 근거가 고르게 확인됩니다.'),
      '중' => (const Color(0xFFF79009), const Color(0xFF33261A), '부분 신뢰 판정', '신뢰 점수가 중간 구간입니다. 일부 근거에 불확실성이 있습니다.'),
      _ => (AppColors.bull, AppColors.bullTint, '과적합 리스크 감지됨',
          '신뢰 점수가 최저 구간입니다. 본 이벤트 단기 급등 시나리오는 극심한 노이즈를 포함할 수 있습니다.'),
    };
    final warnings = c.items.where((i) => i.isWarning).toList();
    // 판정 전적이 없으면 아래에 데모 전적을 보여주므로 "표본 부족" 안내는 뺀다 (서로 모순).
    final demoRecord = t == null || t!.record.judged == 0;
    final infos = c.items
        .where((i) => !i.isWarning && !(demoRecord && i.code == 'PAST_MISSES'))
        .toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: AppColors.canvas,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadius.sm)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('공시 해석 신뢰 등급', style: AppText.monoLabel),
                const SizedBox(height: 4),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('${c.score}', style: AppText.numericHero.copyWith(color: gradeColor)),
                  Text(' / $_segments점', style: AppText.labelLg.copyWith(color: AppColors.textTertiary)),
                  const SizedBox(width: 8),
                  MonoBadge("경고 등급 : '${c.grade}'", fg: Colors.white, bg: gradeColor),
                ]),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const Text('정직한 알고리즘 판정', style: AppText.labelSm),
              Text(verdict, style: AppText.labelMd.copyWith(color: gradeColor)),
            ]),
          ]),
          const SizedBox(height: AppSpace.sm),
          Row(children: [
            for (var i = 0; i < _segments; i++)
              Expanded(
                child: Container(
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                      color: i < c.score ? gradeColor : AppColors.raised,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
          ]),
          const SizedBox(height: AppSpace.sm),
          Text(note, style: AppText.bodySm.copyWith(color: gradeBg == AppColors.bullTint ? AppColors.bull : null)),
        ]),
      ),
      const SizedBox(height: AppSpace.sm),
      if (warnings.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: Text('이 리포트는 근거가 비교적 탄탄합니다', style: AppText.labelLg),
        ),
      for (final w in warnings) _Callout(item: w),
      for (final i in infos) _Callout(item: i),
      const SizedBox(height: AppSpace.sm),
      _TrackRecordStrip(t: t, ticker: ticker),
    ]);
  }
}

class _Callout extends StatelessWidget {
  final CritiqueItem item;
  const _Callout({required this.item});

  @override
  Widget build(BuildContext context) {
    final warn = item.isWarning;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpace.sm),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: warn ? AppColors.bullTint : AppColors.canvas,
          border: Border.all(color: warn ? const Color(0x55F04438) : AppColors.border),
          borderRadius: BorderRadius.circular(AppRadius.sm)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(warn ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
            size: 18, color: warn ? AppColors.bull : AppColors.textTertiary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.summary,
                style: warn
                    ? AppText.labelLg.copyWith(color: AppColors.bull)
                    : AppText.labelLg.copyWith(color: AppColors.textSecondary)),
            if (item.evidence.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(item.evidence, style: AppText.bodySm),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _TrackRecordStrip extends StatelessWidget {
  final TrackRecordResponse? t;
  final String ticker;
  const _TrackRecordStrip({required this.t, required this.ticker});

  @override
  Widget build(BuildContext context) {
    // 판정 끝난 전적이 없으면 데모 전적을 보여준다 (lib/demo).
    final real = t != null && t!.record.judged > 0;
    final demo = demoTrackRecord(ticker);
    final judged = real ? t!.record.judged : demo.judged;
    final hits = real ? t!.record.hits : demo.hits;
    final recent = real ? [for (var i = 0; i < judged; i++) i < hits] : demo.recent;
    final rate = judged == 0 ? 0.0 : hits / judged * 100;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: AppColors.canvas,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppRadius.sm)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Text('해당 알고리즘 공시 유사 승률 (TRACK RECORD)', style: AppText.monoLabel)),
          Text('$judged전 $hits승 ${judged - hits}패',
              style: AppText.numericMetric.copyWith(fontSize: 14, color: AppColors.accent)),
        ]),
        const SizedBox(height: AppSpace.sm),
        Row(children: [
          Text('${rate.toStringAsFixed(1)}%', style: AppText.numericMetric.copyWith(fontSize: 22)),
          const SizedBox(width: 6),
          const Text('역대 유효 적중률', style: AppText.labelSm),
          const Spacer(),
          Flexible(
            child: Wrap(spacing: 4, runSpacing: 4, alignment: WrapAlignment.end, children: [
              for (final h in recent.take(14))
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                      color: h ? AppColors.accent : AppColors.flat, shape: BoxShape.circle),
                ),
            ]),
          ),
        ]),
        const SizedBox(height: AppSpace.sm),
        const Text('과거 성과가 미래 수익을 보장하지 않습니다. 단일 공시 지표 외 매크로 및 환율 변수를 반드시 교차 검증하십시오.',
            style: AppText.labelSm),
      ]),
    );
  }
}

// ─── 타임머신: 종목 성적표 (분석 탭) ──────────────────────────────────────────

const _recordInfo = InfoButton(
  title: '모델 성적표란?',
  body: '이 종목의 과거 공시마다 예상 CAR의 방향이 실제 60거래일 KOSPI 대비 초과수익률과 '
      '같았는지 센 결과예요. 예측이 ±0.5%p 미만이거나 60거래일이 안 지난 공시는 빼요.',
);

/// 판정 끝난 전적이 없을 때: 보고서 상세(반박 모드)와 같은 데모 전적을 보여준다 (lib/demo).
Widget _demoCard(({int judged, int hits, List<bool> recent}) d, TrackRecord real) => DsCard(
      outlined: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [Text('모델 성적표', style: AppText.headlineSm), SizedBox(width: 4), _recordInfo]),
        const SizedBox(height: AppSpace.sm + 4),
        Text('${d.judged}전 ${d.hits}승 · 적중률 ${(d.hits / d.judged * 100).toStringAsFixed(1)}%',
            style: AppText.numericMetric.copyWith(color: AppColors.accent)),
        const SizedBox(height: AppSpace.sm),
        Wrap(spacing: 4, runSpacing: 4, children: [
          for (final h in d.recent)
            Container(
              width: 10,
              height: 10,
              decoration:
                  BoxDecoration(color: h ? AppColors.accent : AppColors.flat, shape: BoxShape.circle),
            ),
        ]),
        const SizedBox(height: AppSpace.sm),
        Text('판정 대기 ${real.pending}건 · 판정 제외 ${real.neutral}건', style: AppText.labelSm),
      ]),
    );

const _typeLabels = {
  'report': '사업보고서',
  'quarterly': '분기보고서',
  'interim': '반기보고서',
  'event': '수시공시',
};

String _recordLine(TrackRecord t) {
  if (t.judged == 0) return '판정된 공시 없음';
  final base = '${t.judged}전 ${t.hits}승';
  return t.hitRate == null
      ? '$base · 표본 부족 (${t.judged}건)'
      : '$base · 적중률 ${(t.hitRate! * 100).round()}%';
}

class TrackRecordCard extends StatelessWidget {
  final TrackRecordResponse res;
  const TrackRecordCard({super.key, required this.res});

  @override
  Widget build(BuildContext context) {
    final t = res.record;
    if (t.judged == 0) return _demoCard(demoTrackRecord(res.ticker), t);
    return DsCard(
      outlined: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Text('모델 성적표', style: AppText.headlineSm),
            SizedBox(width: 4),
            InfoButton(
              title: '모델 성적표란?',
              body: '이 종목의 과거 공시마다 예상 CAR의 방향이 실제 60거래일 KOSPI 대비 초과수익률과 '
                  '같았는지 센 결과예요. 예측이 ±0.5%p 미만이거나 60거래일이 안 지난 공시는 빼요. '
                  '10건 미만이면 비율을 숨겨요.',
            ),
          ]),
          const SizedBox(height: AppSpace.sm + 4),
          Text(_recordLine(t), style: AppText.numericMetric.copyWith(color: AppColors.accent)),
          const SizedBox(height: AppSpace.xs),
          Text('전체 ${t.total}건 · 대기 ${t.pending} · 판정 제외 ${t.neutral} · 시세 부족 ${t.insufficient}',
              style: AppText.labelSm),
          if (res.byType.isNotEmpty) ...[
            const SizedBox(height: AppSpace.md),
            for (final (type, r) in res.byType)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  Expanded(child: Text(_typeLabels[type] ?? type, style: AppText.bodySm)),
                  Text(_recordLine(r), style: AppText.labelMd.copyWith(fontFamily: AppText.mono)),
                ]),
              ),
          ],
        ],
      ),
    );
  }
}

// lib/screens/company/report_detail_screen.dart — W-16 분석 보고서 상세
import 'package:flutter/material.dart';
import '../../models/analysis_model.dart';
import '../../services/api_service.dart';

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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('분석 보고서',
            style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('공유 기능은 준비 중입니다')),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<ReportDetail>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorBody(
                message: snapshot.error.toString(), onRetry: _retry);
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
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeroHeader(report: report),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (report.metricContributions.isNotEmpty) ...[
                  _MetricContributionsSection(
                      metrics: report.metricContributions),
                  const SizedBox(height: 14),
                ],
                _SummarySection(summary: report.summary),
                if (report.keyFindings.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _KeyFindingsSection(findings: report.keyFindings),
                ],
                if (report.sourceDisclosure != null) ...[
                  const SizedBox(height: 14),
                  _SourceDisclosureSection(
                      disclosure: report.sourceDisclosure!),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Hero Header ─────────────────────────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  final ReportDetail report;
  const _HeroHeader({required this.report});

  @override
  Widget build(BuildContext context) {
    final car = report.expectedCar;
    final carPositive = car >= 0;
    final carStr =
        carPositive ? '+${car.toStringAsFixed(1)}%' : '${car.toStringAsFixed(1)}%';
    final dateStr = _formatDate(report.generatedAt, dateOnly: true);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A237E), Color(0xFF283593)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${report.name} (${report.ticker})',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            report.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 좌측: 테마 뱃지 + 날짜
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (report.appliedTheme != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '📊 ${report.appliedTheme!.name}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    Text(
                      dateStr,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 11),
                    ),
                  ],
                ),
              ),
              // 우측: CAR + CI
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '예상 CAR',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 10),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    carStr,
                    style: TextStyle(
                      color: carPositive
                          ? const Color(0xFF86EFAC)
                          : const Color(0xFF93C5FD),
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                    ),
                  ),
                  if (report.carLower != null && report.carUpper != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      '${_signStr(report.carLower!)}${report.carLower!.toStringAsFixed(1)}%'
                      ' ~ '
                      '${_signStr(report.carUpper!)}${report.carUpper!.toStringAsFixed(1)}%'
                      ' (95% CI)',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 9.5),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _signStr(double v) => v >= 0 ? '+' : '';
}

// ─── Metric Contributions ─────────────────────────────────────────────────────

class _MetricContributionsSection extends StatelessWidget {
  final List<MetricContribution> metrics;
  const _MetricContributionsSection({required this.metrics});

  @override
  Widget build(BuildContext context) {
    final sorted = [...metrics]
      ..sort((a, b) => b.contribution.abs().compareTo(a.contribution.abs()));
    final maxAbs = sorted.isEmpty ? 1.0 : sorted.first.contribution.abs();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('민감 지표별 기여도'),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            children: [
              for (int i = 0; i < sorted.length; i++)
                _DivergingBarRow(
                  metric: sorted[i],
                  maxAbs: maxAbs,
                  isLast: i == sorted.length - 1,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DivergingBarRow extends StatelessWidget {
  final MetricContribution metric;
  final double maxAbs;
  final bool isLast;

  const _DivergingBarRow({
    required this.metric,
    required this.maxAbs,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = metric.contribution >= 0;
    final betaStr = metric.beta >= 0
        ? 'β +${metric.beta.toStringAsFixed(2)}'
        : 'β ${metric.beta.toStringAsFixed(2)}';
    final contStr = isPositive
        ? '+${metric.contribution.toStringAsFixed(2)}%p'
        : '${metric.contribution.toStringAsFixed(2)}%p';

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 지표명 / β / 기여도
          Row(
            children: [
              Expanded(
                child: Text(
                  metric.displayName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              Text(
                betaStr,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF6B7280),
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(width: 8),
              Text(
                contStr,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isPositive
                      ? const Color(0xFF16A34A)
                      : const Color(0xFF1976D2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          // 분기 막대
          LayoutBuilder(
            builder: (context, constraints) {
              final halfWidth = constraints.maxWidth / 2;
              final fraction =
                  (metric.contribution.abs() / maxAbs).clamp(0.0, 1.0);
              final barWidth = fraction * halfWidth;

              return ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: SizedBox(
                  height: 8,
                  child: Stack(
                    children: [
                      // 배경
                      Container(color: const Color(0xFFF3F4F6)),
                      // 중앙선
                      Positioned(
                        left: halfWidth - 0.5,
                        top: 0,
                        bottom: 0,
                        width: 1,
                        child: Container(color: const Color(0xFFD1D5DB)),
                      ),
                      // 막대
                      if (isPositive)
                        Positioned(
                          left: halfWidth,
                          top: 0,
                          bottom: 0,
                          width: barWidth,
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFF1A237E),
                                  Color(0xFF16A34A),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        Positioned(
                          left: halfWidth - barWidth,
                          top: 0,
                          bottom: 0,
                          width: barWidth,
                          child: Container(
                              color: const Color(0xFF1976D2)),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 3),
          // raw 값
          Text(
            metric.rawValue,
            style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }
}

// ─── Summary ─────────────────────────────────────────────────────────────────

class _SummarySection extends StatelessWidget {
  final String summary;
  const _SummarySection({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('요약'),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Text(
            summary,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF374151),
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Key Findings ─────────────────────────────────────────────────────────────

class _KeyFindingsSection extends StatelessWidget {
  final List<String> findings;
  const _KeyFindingsSection({required this.findings});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('핵심 발견'),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < findings.length; i++)
                Padding(
                  padding: EdgeInsets.only(
                      bottom: i == findings.length - 1 ? 0 : 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 6, right: 8),
                        child: CircleAvatar(
                          radius: 3,
                          backgroundColor: Color(0xFF1A237E),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          findings[i],
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF374151),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Source Disclosure ────────────────────────────────────────────────────────

class _SourceDisclosureSection extends StatelessWidget {
  final SourceDisclosure disclosure;
  const _SourceDisclosureSection({required this.disclosure});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('원본 공시'),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                disclosure.title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatDate(disclosure.filedAt),
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF9CA3AF)),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    // 백엔드 연동 시 url_launcher 패키지로 dart_url 열기
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('DART 원문: ${disclosure.dartUrl}'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('DART 원문 보기'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1A237E),
                    side: const BorderSide(color: Color(0xFF1A237E)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Error ────────────────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBody({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: Color(0xFF9CA3AF)),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 16),
            TextButton(onPressed: onRetry, child: const Text('다시 시도')),
          ],
        ),
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

Widget _sectionTitle(String title) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Color(0xFF6B7280),
        letterSpacing: 0.2,
      ),
    ),
  );
}

String _formatDate(String isoStr, {bool dateOnly = false}) {
  try {
    final dt = DateTime.parse(isoStr).toLocal();
    if (dateOnly) {
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    }
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  } catch (_) {
    return isoStr;
  }
}

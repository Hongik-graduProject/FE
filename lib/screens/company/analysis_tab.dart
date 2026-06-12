// lib/screens/company/analysis_tab.dart — W-15 기업 상세 분석 탭
import 'package:flutter/material.dart';
import '../../models/analysis_model.dart';
import '../../services/api_service.dart';

class AnalysisTab extends StatefulWidget {
  final String ticker;

  const AnalysisTab({super.key, required this.ticker});

  @override
  State<AnalysisTab> createState() => _AnalysisTabState();
}

class _AnalysisTabState extends State<AnalysisTab>
    with AutomaticKeepAliveClientMixin {
  late Future<(ThemesResponse, ReportsResponse)> _future;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _future = Future.wait([
      ApiService().getStockThemes(widget.ticker),
      ApiService().getStockReports(widget.ticker),
    ]).then((results) => (results[0] as ThemesResponse, results[1] as ReportsResponse));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<(ThemesResponse, ReportsResponse)>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ErrorState(
            message: snapshot.error.toString(),
            onRetry: () => setState(_loadData),
          );
        }
        final (themes, reports) = snapshot.data!;
        return RefreshIndicator(
          onRefresh: () async => setState(_loadData),
          child: ListView(
            padding: const EdgeInsets.all(14),
            children: [
              _ThemeSection(themesResponse: themes),
              const SizedBox(height: 14),
              _ReportSection(ticker: widget.ticker, reportsResponse: reports),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}

// ─── ThemeSection ────────────────────────────────────────────────────────────

class _ThemeSection extends StatelessWidget {
  final ThemesResponse themesResponse;

  const _ThemeSection({required this.themesResponse});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('예측 테마 (ThemeSense)'),
        if (!themesResponse.hasThemes)
          _NoThemePlaceholder(message: themesResponse.message)
        else ...[
          _PrimaryThemeCard(theme: themesResponse.themes.first),
          if (themesResponse.themes.length > 1) ...[
            const SizedBox(height: 8),
            Row(
              children: themesResponse.themes
                  .skip(1)
                  .map((t) => Expanded(child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _SecondaryThemeCard(theme: t),
                      )))
                  .toList(),
            ),
          ],
        ],
      ],
    );
  }
}

class _NoThemePlaceholder extends StatelessWidget {
  final String? message;
  const _NoThemePlaceholder({this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('⏳', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '테마 분류 대기 중',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message ?? 'ThemeSense 학습 universe 외 종목입니다',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF92400E),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryThemeCard extends StatelessWidget {
  final StockTheme theme;
  const _PrimaryThemeCard({required this.theme});

  @override
  Widget build(BuildContext context) {
    final pct = (theme.probability * 100).toStringAsFixed(1);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A237E), Color(0xFF283593)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Primary',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '$pct%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            theme.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          // 확률 막대
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: theme.probability,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 5,
            ),
          ),
          if (theme.topSensitiveMetrics != null &&
              theme.topSensitiveMetrics!.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 10),
            const Text(
              '핵심 민감 지표 (β 계수)',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            ...theme.topSensitiveMetrics!.map(
              (m) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: _MetricRow(metric: m),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final SensitiveMetric metric;
  const _MetricRow({required this.metric});

  @override
  Widget build(BuildContext context) {
    final isPositive = metric.beta >= 0;
    final betaStr = isPositive
        ? '+${metric.beta.toStringAsFixed(2)}'
        : metric.beta.toStringAsFixed(2);
    final barColor =
        isPositive ? const Color(0xFF86EFAC) : const Color(0xFF93C5FD);
    final barWidth = (metric.beta.abs() / 1.0).clamp(0.05, 1.0);

    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(
            metric.displayName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: barWidth,
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
              minHeight: 4,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'β $betaStr',
          style: TextStyle(
            color: barColor,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}

class _SecondaryThemeCard extends StatelessWidget {
  final StockTheme theme;
  const _SecondaryThemeCard({required this.theme});

  @override
  Widget build(BuildContext context) {
    final pct = (theme.probability * 100).toStringAsFixed(1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE8EAF6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFC5CAE9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '#${theme.rank}',
            style: const TextStyle(
              color: Color(0xFF7986CB),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            theme.name,
            style: const TextStyle(
              color: Color(0xFF1A237E),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$pct%',
            style: const TextStyle(
              color: Color(0xFF3949AB),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── ReportSection ────────────────────────────────────────────────────────────

class _ReportSection extends StatelessWidget {
  final String ticker;
  final ReportsResponse reportsResponse;

  const _ReportSection(
      {required this.ticker, required this.reportsResponse});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('분석 보고서 (최신순)'),
        if (reportsResponse.reports.isEmpty)
          _EmptyReports()
        else
          ...reportsResponse.reports
              .map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ReportCard(report: r),
                  )),
      ],
    );
  }
}

class _EmptyReports extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const Column(
        children: [
          Text('📊', style: TextStyle(fontSize: 28)),
          SizedBox(height: 8),
          Text(
            '아직 분석 보고서가 없습니다',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF9CA3AF),
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '공시 등록 후 자동으로 생성됩니다',
            style: TextStyle(fontSize: 12, color: Color(0xFFD1D5DB)),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final AnalysisReport report;
  const _ReportCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final car = report.expectedCar;
    final carPositive = car != null && car >= 0;
    final carStr = car != null
        ? (carPositive ? '+${car.toStringAsFixed(1)}%' : '${car.toStringAsFixed(1)}%')
        : null;

    final dateStr = _formatDate(report.generatedAt);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          Navigator.pushNamed(context, '/report', arguments: report.id);
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 미읽음 마커
              Padding(
                padding: const EdgeInsets.only(top: 5, right: 8),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: report.isRead
                        ? Colors.transparent
                        : const Color(0xFFEF4444),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: report.isRead
                            ? FontWeight.w600
                            : FontWeight.w800,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      report.summary,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (report.appliedTheme != null)
                          _ThemeBadge(name: report.appliedTheme!.name),
                        if (carStr != null) ...[
                          const SizedBox(width: 6),
                          _CarBadge(carStr: carStr, isPositive: carPositive),
                        ],
                        const Spacer(),
                        Text(
                          dateStr,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: Color(0xFF9CA3AF),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String isoStr) {
    try {
      final dt = DateTime.parse(isoStr).toLocal();
      return '${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoStr;
    }
  }
}

class _ThemeBadge extends StatelessWidget {
  final String name;
  const _ThemeBadge({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFE8EAF6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        name,
        style: const TextStyle(
          fontSize: 11,
          color: Color(0xFF1A237E),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CarBadge extends StatelessWidget {
  final String carStr;
  final bool isPositive;
  const _CarBadge({required this.carStr, required this.isPositive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: isPositive
            ? const Color(0xFFDCFCE7)
            : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '예상 CAR $carStr',
        style: TextStyle(
          fontSize: 11,
          color: isPositive ? const Color(0xFF16A34A) : const Color(0xFF1976D2),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─── 공통 헬퍼 ────────────────────────────────────────────────────────────────

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

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 40, color: Color(0xFF9CA3AF)),
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

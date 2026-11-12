import 'package:flutter/material.dart';

import '../../../models/stock_model.dart';
import '../../../services/api_service.dart';
import '../../../utils/design_tokens.dart';
import '../../../utils/format.dart';
import '../../../widgets/common_widgets.dart';
import '../../../widgets/ds.dart';

/// 종목 상세 · 공시 탭 (Stitch _2). 공시 API 에 보고서 연결 정보가 없어 예상 CAR 배지는 붙이지 않는다.
class DisclosuresTab extends StatefulWidget {
  final String ticker;
  const DisclosuresTab({super.key, required this.ticker});

  @override
  State<DisclosuresTab> createState() => _DisclosuresTabState();
}

class _DisclosuresTabState extends State<DisclosuresTab>
    with AutomaticKeepAliveClientMixin {
  late Future<StockDisclosuresResponse> _future;
  String? _type; // null = 전체

  static const _typeLabels = {
    'REPORT': '사업보고서',
    'INTERIM': '반기보고서',
    'QUARTERLY': '분기보고서',
    'EVENT': '주요사항',
  };

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  // 유형 필터는 클라이언트에서 거르므로 한 번에 넉넉히 받는다.
  Future<StockDisclosuresResponse> _load() =>
      ApiService().getStockDisclosures(widget.ticker, size: 100);

  Future<void> _refresh() async {
    setState(() { _future = _load(); });
    try {
      await _future;
    } catch (_) {} // 오류는 FutureBuilder 가 보여준다.
  }

  static String _label(String type) => _typeLabels[type] ?? type;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<StockDisclosuresResponse>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(AppSpace.lg),
            child: SkeletonList(count: 4),
          );
        }
        if (snapshot.hasError) {
          return _scroll([
            ErrorRetry(message: snapshot.error.toString(), onRetry: _refresh),
          ]);
        }
        final all = snapshot.data!.items;
        if (all.isEmpty) {
          return _scroll(const [
            EmptyState(icon: Icons.article_outlined, title: '공시가 없어요'),
          ]);
        }
        final types = <String>{for (final d in all) d.type}.toList();
        final items =
            _type == null ? all : all.where((d) => d.type == _type).toList();

        return _scroll([
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _chip('전체 ${all.length}', _type == null,
                    () => setState(() => _type = null)),
                for (final t in types)
                  _chip(_label(t), _type == t, () => setState(() => _type = t)),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.md),
          for (final d in items) ...[
            _DisclosureCard(item: d, typeLabel: _label(d.type)),
            const SizedBox(height: AppSpace.sm + 4),
          ],
          const Disclaimer(),
        ]);
      },
    );
  }

  Widget _scroll(List<Widget> children) => RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
              AppSpace.lg, AppSpace.md, AppSpace.lg, 0),
          children: children,
        ),
      );

  Widget _chip(String label, bool selected, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: AppSpace.sm),
        child: ChoiceChip(
          label: Text(label,
              style: AppText.labelMd.copyWith(
                  color: selected ? Colors.white : AppColors.textSecondary)),
          selected: selected,
          showCheckmark: false,
          onSelected: (_) => onTap(),
        ),
      );
}

class _DisclosureCard extends StatelessWidget {
  final StockDisclosureItem item;
  final String typeLabel;
  const _DisclosureCard({required this.item, required this.typeLabel});

  @override
  Widget build(BuildContext context) {
    final url = item.dartUrl ?? '';
    final filed = DateTime.tryParse(item.filedAt);
    final hasReport = item.reportId != null;
    return DsCard(
      // 분석된 공시는 보고서로, 아니면 DART 원문으로 간다.
      onTap: hasReport
          ? () =>
              Navigator.pushNamed(context, '/report', arguments: item.reportId)
          : (url.isEmpty ? null : () => openExternalUrl(context, url)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            DsPill(typeLabel,
                height: 20,
                background: AppColors.subtle,
                foreground: AppColors.textSecondary),
            const Spacer(),
            if (filed != null)
              // 접수 시각은 DART 가 일 단위로만 줘서 날짜만 보여준다.
              Text(ymd(filed, sep: '.'),
                  style: AppText.labelSm
                      .copyWith(fontFeatures: AppText.numeric.fontFeatures)),
          ]),
          const SizedBox(height: AppSpace.sm + 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(item.title.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.headlineSm),
              ),
              if (!hasReport && url.isNotEmpty) ...[
                const SizedBox(width: AppSpace.sm),
                const Icon(Icons.open_in_new_rounded,
                    size: 18, color: AppColors.textTertiary),
              ],
            ],
          ),
          if (hasReport) ...[
            const SizedBox(height: AppSpace.sm + 2),
            Row(children: [
              CarBadge(item.expectedCar),
              const Spacer(),
              Text('분석 보고서 보기',
                  style: AppText.labelMd.copyWith(color: AppColors.accent)),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.accent),
            ]),
          ],
        ],
      ),
    );
  }
}

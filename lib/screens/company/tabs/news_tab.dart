import 'package:flutter/material.dart';

import '../../../models/stock_model.dart';
import '../../../services/api_service.dart';
import '../../../utils/design_tokens.dart';
import '../../../utils/format.dart';
import '../../../widgets/common_widgets.dart';
import '../../../widgets/ds.dart';

/// 종목 상세 · 뉴스 탭 (Stitch _5). 카테고리 칩은 데이터가 없어 뺐다.
class NewsTab extends StatefulWidget {
  final String ticker;
  const NewsTab({super.key, required this.ticker});

  @override
  State<NewsTab> createState() => _NewsTabState();
}

class _NewsTabState extends State<NewsTab> with AutomaticKeepAliveClientMixin {
  late Future<StockNewsResponse> _future;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = ApiService().getStockNews(widget.ticker);
  }

  Future<void> _refresh() async {
    setState(() => _future = ApiService().getStockNews(widget.ticker));
    try {
      await _future;
    } catch (_) {} // 오류는 FutureBuilder 가 보여준다.
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<StockNewsResponse>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(AppSpace.lg),
            child: SkeletonList(count: 4),
          );
        }
        final List<Widget> children;
        if (snapshot.hasError) {
          children = [ErrorRetry(message: snapshot.error.toString(), onRetry: _refresh)];
        } else if (snapshot.data!.items.isEmpty) {
          children = const [
            EmptyState(icon: Icons.newspaper_rounded, title: '관련 뉴스가 없어요'),
          ];
        } else {
          children = [
            for (final n in snapshot.data!.items) ...[
              _NewsCard(item: n),
              const SizedBox(height: AppSpace.sm + 4),
            ],
            const Disclaimer(),
          ];
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
}

class _NewsCard extends StatelessWidget {
  final StockNewsItem item;
  const _NewsCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final published = DateTime.tryParse(item.publishedAt);
    final meta = [
      if ((item.source ?? '').isNotEmpty) item.source!,
      if (published != null) relativeTime(published),
    ].join(' · ');
    final thumb = item.thumbnailUrl ?? '';

    return DsCard(
      padding: const EdgeInsets.all(AppSpace.md),
      onTap: item.url.isEmpty ? null : () => openExternalUrl(context, item.url),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (meta.isNotEmpty) Text(meta, style: AppText.labelSm),
                const SizedBox(height: AppSpace.xs + 2),
                Text(item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodyLg.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          if (thumb.isNotEmpty) ...[
            const SizedBox(width: AppSpace.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Image.network(
                thumb,
                width: 72,
                height: 72,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

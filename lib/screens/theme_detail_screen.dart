// lib/screens/theme_detail_screen.dart — 테마 상세: 이 테마가 1순위인 종목 목록
import 'package:flutter/material.dart';
import '../models/theme_model.dart';
import '../services/api_service.dart';
import '../utils/design_tokens.dart';
import '../utils/format.dart';
import '../widgets/ds.dart';
import 'company/company_detail_screen.dart';

class ThemeArgs {
  final int id;
  final String name;
  const ThemeArgs({required this.id, required this.name});
}

class ThemeDetailScreen extends StatefulWidget {
  const ThemeDetailScreen({super.key});

  @override
  State<ThemeDetailScreen> createState() => _ThemeDetailScreenState();
}

class _ThemeDetailScreenState extends State<ThemeDetailScreen> {
  ThemeArgs? _args;
  ThemeSummary? _theme;
  final List<ThemeStockItem> _items = [];
  int _page = 0;
  bool _hasNext = false;
  bool _loading = true;
  bool _loadingMore = false;
  Object? _error;
  // 새로고침 중에 옛 "더 보기" 응답이 오면 목록이 섞이지 않게 버린다.
  int _loadSeq = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_args == null) {
      _args = ModalRoute.of(context)!.settings.arguments as ThemeArgs;
      _load();
    }
  }

  Future<void> _load() async {
    final seq = ++_loadSeq;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await ApiService().getThemeStocks(_args!.id);
      if (!mounted || seq != _loadSeq) return;
      setState(() {
        _theme = r.theme;
        _items
          ..clear()
          ..addAll(r.items);
        _page = r.pagination.page;
        _hasNext = r.pagination.hasNext;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || seq != _loadSeq) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    final seq = _loadSeq;
    setState(() => _loadingMore = true);
    try {
      final r = await ApiService().getThemeStocks(_args!.id, page: _page + 1);
      if (!mounted || seq != _loadSeq) return;
      setState(() {
        _items.addAll(r.items);
        _page = r.pagination.page;
        _hasNext = r.pagination.hasNext;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _openCompany(ThemeStockItem it) => Navigator.pushNamed(
        context,
        '/company',
        arguments: CompanyArgs(
          ticker: it.stock.ticker,
          name: it.stock.name,
          currentPrice: it.stock.currentPrice,
          changeRate: it.stock.changeRate,
          changeAmount: it.stock.changeAmount,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: Text(_theme?.name ?? _args?.name ?? '테마')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(AppSpace.lg),
        child: Column(children: [
          SkeletonBox(height: 120, radius: AppRadius.lg),
          SizedBox(height: AppSpace.xl),
          SkeletonList(count: 6, itemHeight: 56),
        ]),
      );
    }
    if (_error != null && _items.isEmpty) {
      return Center(
          child: ErrorRetry(message: _error.toString(), onRetry: _load));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
            AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.lg),
        children: [
          if (_theme != null) _header(_theme!),
          const SizedBox(height: AppSpace.xl),
          if (_items.isEmpty)
            const EmptyState(
                icon: Icons.category_outlined, title: '이 테마에 묶인 종목이 없어요')
          else
            DsCard(
              padding: EdgeInsets.zero,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: Column(children: [
                  for (var i = 0; i < _items.length; i++) ...[
                    if (i > 0)
                      const Divider(
                          height: 1,
                          indent: AppSpace.md,
                          endIndent: AppSpace.md),
                    _ThemeStockRow(
                        item: _items[i], onTap: () => _openCompany(_items[i])),
                  ],
                ]),
              ),
            ),
          if (_hasNext) ...[
            const SizedBox(height: AppSpace.md),
            Center(
              child: _loadingMore
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : TextButton(onPressed: _loadMore, child: const Text('더 보기')),
            ),
          ],
        ],
      ),
    );
  }

  Widget _header(ThemeSummary t) {
    return DsCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Flexible(
              child: Text(t.name,
                  style: AppText.headlineMd, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: AppSpace.sm),
          const DemoTag(),
          const Spacer(),
          const InfoButton(
            title: '데모 테마',
            body: '업종 코드를 기준으로 나눈 데모 테마예요. 각 종목의 1순위 테마로 묶었어요.',
          ),
        ]),
        if (t.description != null && t.description!.isNotEmpty) ...[
          const SizedBox(height: AppSpace.sm),
          Text(t.description!,
              style: AppText.bodyMd.copyWith(color: AppColors.textSecondary)),
        ],
        const SizedBox(height: AppSpace.sm + 4),
        Text('대표 종목 ${comma(t.stockCount)}개',
            style: AppText.labelLg
                .copyWith(color: AppColors.accent)
                .merge(AppText.numeric)),
      ]),
    );
  }
}

/// 종목 한 줄: 이름 · "코드 · 시장" · 일치도 | 가격 · 등락
class _ThemeStockRow extends StatelessWidget {
  final ThemeStockItem item;
  final VoidCallback onTap;
  const _ThemeStockRow({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = item.stock;
    final sub = s.market.isEmpty ? s.ticker : '${s.ticker} · ${s.market}';
    final p = item.probability;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: 12),
        child: Row(children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.name,
                  style: AppText.bodyLg,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(p == null ? sub : '$sub · 일치도 ${(p * 100).round()}%',
                  style: AppText.labelSm.merge(AppText.numeric)),
            ]),
          ),
          const SizedBox(width: AppSpace.sm),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(won(s.currentPrice),
                style: AppText.labelLg.merge(AppText.numeric)),
            const SizedBox(height: 2),
            PriceChange(
                amount: s.changeAmount,
                rate: s.changeRate,
                style: AppText.labelSm),
          ]),
        ]),
      ),
    );
  }
}

// lib/screens/search_screen.dart — 탐색 탭 / 종목 검색 (W-08·09·10)
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/stock_model.dart';
import '../models/theme_model.dart';
import '../services/api_service.dart';
import '../utils/design_tokens.dart';
import '../utils/format.dart';
import '../widgets/ds.dart';
import '../widgets/favorite_actions.dart';
import '../widgets/favorite_picker_dialog.dart';
import 'company/company_detail_screen.dart';
import 'theme_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  /// 하단 탭(탐색)으로 쓰일 때 true. 뒤로 가기 버튼과 자동 포커스를 끈다.
  final bool isTab;
  const SearchScreen({super.key, this.isTab = false});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  bool _searching = false;

  // 결과
  StockSearchResponse? _results;
  String? _resultsKeyword;

  // 자동완성
  List<StockBriefItem> _suggestions = [];

  // 최근·인기
  Future<RecentSearchResponse>? _recentFuture;
  Future<StockRankingResponse>? _rankingFuture;
  Future<ThemeListResponse>? _themesFuture;

  // 검색 응답에 is_favorite 가 없어 이 화면에서 추가한 종목만 ♥ 로 표시한다.
  final Set<String> _favTickers = {};
  int? _defaultFolderId;

  @override
  void initState() {
    super.initState();
    _loadLanding();
  }

  void _loadLanding() {
    _recentFuture = ApiService().getRecentSearches();
    _rankingFuture = ApiService().getStockRanking();
    _themesFuture = ApiService().getThemes();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    if (text.trim().isEmpty) {
      setState(() {
        _suggestions = [];
        _results = null;
        _resultsKeyword = null;
      });
      return;
    }
    // 검색 결과를 보다가 다시 입력하면 결과를 닫아야 자동완성이 보인다.
    // 결과가 없어도 지우기 버튼 표시를 위해 다시 그린다.
    setState(() {
      _results = null;
      _resultsKeyword = null;
    });
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      try {
        final r = await ApiService().autocompleteStocks(text.trim());
        if (!mounted || _controller.text.trim() != text.trim()) return;
        setState(() => _suggestions = r.items);
      } catch (_) {}
    });
  }

  Future<void> _submitSearch(String keyword) async {
    final q = keyword.trim();
    if (q.isEmpty) return;
    _debounce?.cancel();
    setState(() {
      _searching = true;
      _suggestions = [];
    });
    try {
      final r = await ApiService().searchStocks(q);
      // 검색어 저장 (실패해도 결과는 표시)
      ApiService().addRecentSearch(q).catchError((_) {});
      // 응답을 기다리는 동안 다시 입력했으면 옛 결과로 자동완성을 덮지 않는다.
      if (!mounted || _controller.text.trim() != q) return;
      setState(() {
        _results = r;
        _resultsKeyword = q;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _clearResults() {
    setState(() {
      _results = null;
      _resultsKeyword = null;
      _controller.clear();
      _suggestions = [];
      _loadLanding();
    });
  }

  void _searchKeyword(String k) {
    _controller.text = k;
    _submitSearch(k);
  }

  void _openCompany(StockBriefItem item) => Navigator.pushNamed(
        context,
        '/company',
        arguments: CompanyArgs(
          ticker: item.ticker,
          name: item.name,
          currentPrice: item.currentPrice,
          changeRate: item.changeRate,
          changeAmount: item.changeAmount,
          isFavorite: _favTickers.contains(item.ticker),
        ),
      );

  /// ♥ 탭: 기본 폴더에 바로 추가.
  Future<void> _quickAdd(StockBriefItem item) async {
    final messenger = ScaffoldMessenger.of(context);
    if (_favTickers.contains(item.ticker)) {
      messenger.showSnackBar(const SnackBar(content: Text('이미 관심종목이에요. 길게 누르면 다른 폴더에도 넣을 수 있어요')));
      return;
    }
    try {
      _defaultFolderId ??=
          (await ApiService().getFolders()).folders.firstWhere((f) => f.type == 'default').id;
      final itemId = await ApiService().addFavorite(_defaultFolderId!, item.ticker);
      if (!mounted) return;
      setState(() => _favTickers.add(item.ticker));
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
        content: const Text('기본 폴더에 추가했어요'),
        action: SnackBarAction(label: '변경', onPressed: () => _changeFolder(item, itemId)),
      ));
    } on StateError {
      messenger.showSnackBar(const SnackBar(content: Text('기본 폴더를 찾지 못했어요')));
    } catch (e) {
      // 이미 기본 폴더에 있던 종목이면 서버가 DUPLICATE 로 거절한다. 그래도 ♥ 는 채워 둔다.
      if (mounted && e.toString().contains('이미')) setState(() => _favTickers.add(item.ticker));
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  /// 스낵바 "변경": 방금 기본 폴더에 넣은 항목을 다른 폴더로 옮긴다 (서버 이동 API 한 번).
  Future<void> _changeFolder(StockBriefItem item, int itemId) async {
    if (_defaultFolderId == null) return;
    await showMoveFavoriteDialog(context,
        itemId: itemId, name: item.name, currentFolderId: _defaultFolderId!);
  }

  /// ♥ 길게 누르기: 폴더 고르기.
  Future<bool> _openFavoritePicker(StockBriefItem item) async {
    final added = await showDialog<bool>(
      context: context,
      builder: (_) => FavoritePickerDialog(ticker: item.ticker, name: item.name),
    );
    if (added != true || !mounted) return false;
    setState(() => _favTickers.add(item.ticker));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"${item.name}" 추가했어요')));
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: EdgeInsets.fromLTRB(widget.isTab ? AppSpace.lg : AppSpace.xs, AppSpace.sm + 4, AppSpace.lg, AppSpace.sm),
            child: Row(children: [
              if (!widget.isTab) const BackButton(),
              Expanded(child: _searchField()),
            ]),
          ),
          Expanded(child: _buildBody()),
        ]),
      ),
    );
  }

  Widget _searchField() {
    return SizedBox(
      height: 48,
      child: TextField(
        controller: _controller,
        autofocus: !widget.isTab,
        textInputAction: TextInputAction.search,
        onChanged: _onChanged,
        onSubmitted: _submitSearch,
        style: AppText.bodyLg,
        decoration: InputDecoration(
          hintText: '종목명 또는 6자리 코드',
          filled: true,
          fillColor: AppColors.subtle,
          contentPadding: EdgeInsets.zero,
          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textTertiary),
          suffixIcon: _controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: '지우기',
                  icon: const Icon(Icons.cancel_rounded, size: 20, color: AppColors.textDisabled),
                  onPressed: _clearResults,
                ),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_searching) {
      return const Padding(
        padding: EdgeInsets.all(AppSpace.lg),
        child: SkeletonList(count: 5, itemHeight: 56),
      );
    }
    if (_results != null) {
      final items = _results!.items;
      if (items.isEmpty) {
        return ListView(children: [
          EmptyState(
            icon: Icons.search_off_rounded,
            title: "'$_resultsKeyword' 검색 결과가 없어요",
            message: '종목코드 6자리로도 찾을 수 있어요',
          ),
        ]);
      }
      return _rowsList(items);
    }
    if (_suggestions.isNotEmpty) {
      return _rowsList(_suggestions, highlight: _controller.text.trim());
    }
    return RefreshIndicator(
      onRefresh: () async => setState(_loadLanding),
      child: _LandingView(
        recentFuture: _recentFuture,
        rankingFuture: _rankingFuture,
        themesFuture: _themesFuture,
        onSelectKeyword: _searchKeyword,
        onDeleteRecent: (k) async {
          await ApiService().deleteRecentSearch(keyword: k);
          setState(() { _recentFuture = ApiService().getRecentSearches(); });
        },
        onClearAllRecent: () async {
          await ApiService().deleteRecentSearch();
          setState(() { _recentFuture = ApiService().getRecentSearches(); });
        },
        onRetryRanking: () => setState(() { _rankingFuture = ApiService().getStockRanking(); }),
        onRetryThemes: () => setState(() { _themesFuture = ApiService().getThemes(); }),
        onSelectTheme: (t) => Navigator.pushNamed(context, '/theme',
            arguments: ThemeArgs(id: t.id, name: t.name)),
        onSelectStock: _openCompany,
      ),
    );
  }

  Widget _rowsList(List<StockBriefItem> items, {String? highlight}) {
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.lg),
      children: [
        _RowsCard(children: [
          for (final it in items)
            _StockRow(
              item: it,
              highlight: highlight,
              favorite: _favTickers.contains(it.ticker),
              onTap: () {
                // 자동완성에서 바로 들어가도 최근 검색에 남긴다.
                if (highlight != null) ApiService().addRecentSearch(it.name).catchError((_) {});
                _openCompany(it);
              },
              onFavorite: () => _quickAdd(it),
              onFavoriteLong: () => _openFavoritePicker(it),
            ),
        ]),
      ],
    );
  }
}

// ─── Landing (W-08): 최근 검색어 + 인기 순위 ─────────────────────────────────

class _LandingView extends StatelessWidget {
  final Future<RecentSearchResponse>? recentFuture;
  final Future<StockRankingResponse>? rankingFuture;
  final Future<ThemeListResponse>? themesFuture;
  final ValueChanged<String> onSelectKeyword;
  final ValueChanged<String> onDeleteRecent;
  final VoidCallback onClearAllRecent;
  final VoidCallback onRetryRanking;
  final VoidCallback onRetryThemes;
  final ValueChanged<StockBriefItem> onSelectStock;
  final ValueChanged<ThemeSummary> onSelectTheme;

  const _LandingView({
    required this.recentFuture,
    required this.rankingFuture,
    required this.themesFuture,
    required this.onSelectKeyword,
    required this.onDeleteRecent,
    required this.onClearAllRecent,
    required this.onRetryRanking,
    required this.onRetryThemes,
    required this.onSelectStock,
    required this.onSelectTheme,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.lg),
      children: [
        FutureBuilder<RecentSearchResponse>(
          future: recentFuture,
          builder: (context, snapshot) {
            final items = snapshot.data?.items ?? [];
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SectionTitle('최근 검색',
                  trailing: items.isEmpty
                      ? null
                      : TextButton(onPressed: onClearAllRecent, child: const Text('전체 삭제'))),
              if (snapshot.connectionState == ConnectionState.waiting)
                const SkeletonBox(height: 32, width: 220, radius: 999)
              else if (snapshot.hasError)
                const Text('최근 검색을 불러오지 못했어요', style: AppText.bodySm)
              else if (items.isEmpty)
                Text('최근 검색 기록이 없어요', style: AppText.bodySm.copyWith(color: AppColors.textTertiary))
              else
                Wrap(
                  spacing: AppSpace.sm,
                  runSpacing: AppSpace.sm,
                  children: [
                    for (final e in items)
                      InputChip(
                        label: Text(e.keyword),
                        labelStyle: AppText.labelLg.copyWith(color: AppColors.textSecondary),
                        backgroundColor: AppColors.card,
                        side: const BorderSide(color: AppColors.border),
                        shape: const StadiumBorder(),
                        deleteIcon: const Icon(Icons.close_rounded, size: 16),
                        deleteIconColor: AppColors.textTertiary,
                        onPressed: () => onSelectKeyword(e.keyword),
                        onDeleted: () => onDeleteRecent(e.keyword),
                      ),
                  ],
                ),
            ]);
          },
        ),
        const SizedBox(height: AppSpace.xl),
        const SectionTitle('테마로 둘러보기', info: DemoTag()),
        FutureBuilder<ThemeListResponse>(
          future: themesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SkeletonList(count: 2, itemHeight: 72);
            }
            if (snapshot.hasError) {
              return ErrorRetry(message: snapshot.error.toString(), onRetry: onRetryThemes);
            }
            final themes = snapshot.data?.themes ?? [];
            if (themes.isEmpty) {
              return const EmptyState(icon: Icons.category_outlined, title: '테마 정보가 없어요');
            }
            return GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppSpace.sm + 4,
              crossAxisSpacing: AppSpace.sm + 4,
              childAspectRatio: 2.2,
              children: [
                for (final t in themes)
                  DsCard(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: 12),
                    onTap: () => onSelectTheme(t),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(t.name, style: AppText.labelLg, maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text('${comma(t.stockCount)}종목', style: AppText.labelSm.merge(AppText.numeric)),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpace.xl),
        const SectionTitle('실시간 인기 종목'),
        FutureBuilder<StockRankingResponse>(
          future: rankingFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SkeletonList(count: 5, itemHeight: 52);
            }
            if (snapshot.hasError) {
              return ErrorRetry(message: snapshot.error.toString(), onRetry: onRetryRanking);
            }
            final items = (snapshot.data?.items ?? []).take(10).toList();
            if (items.isEmpty) {
              return const EmptyState(icon: Icons.trending_up_rounded, title: '인기 종목 정보가 없어요');
            }
            return _RowsCard(children: [
              for (var i = 0; i < items.length; i++)
                _StockRow(item: items[i], rank: i + 1, onTap: () => onSelectStock(items[i])),
            ]);
          },
        ),
      ],
    );
  }
}

/// 흰 카드 안에 줄을 구분선으로 쌓는다.
class _RowsCard extends StatelessWidget {
  final List<Widget> children;
  const _RowsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return DsCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Column(children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: AppSpace.md, endIndent: AppSpace.md),
            children[i],
          ],
        ]),
      ),
    );
  }
}

/// 종목 한 줄: [순위] 이름(검색어 굵게) · "코드 · 시장" · 가격 · 등락 · [♥]
class _StockRow extends StatelessWidget {
  final StockBriefItem item;
  final int? rank;
  final String? highlight;
  final bool favorite;
  final VoidCallback onTap;
  final VoidCallback? onFavorite;
  final VoidCallback? onFavoriteLong;

  const _StockRow({
    required this.item,
    required this.onTap,
    this.rank,
    this.highlight,
    this.favorite = false,
    this.onFavorite,
    this.onFavoriteLong,
  });

  Widget _name() {
    final name = item.name;
    final q = highlight ?? '';
    final at = q.isEmpty ? -1 : name.toLowerCase().indexOf(q.toLowerCase());
    if (at < 0) return Text(name, style: AppText.bodyLg, maxLines: 1, overflow: TextOverflow.ellipsis);
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: name.substring(0, at)),
        TextSpan(text: name.substring(at, at + q.length), style: const TextStyle(fontWeight: FontWeight.w700)),
        TextSpan(text: name.substring(at + q.length)),
      ]),
      style: AppText.bodyLg,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sub = item.market.isEmpty ? item.ticker : '${item.ticker} · ${item.market}';
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.fromLTRB(AppSpace.md, 12, onFavorite == null ? AppSpace.md : AppSpace.xs, 12),
        child: Row(children: [
          if (rank != null)
            SizedBox(
              width: 28,
              child: Text('$rank',
                  style: AppText.headlineSm.copyWith(
                      color: rank! <= 3 ? AppColors.brand : AppColors.textTertiary,
                      fontFeatures: AppText.numeric.fontFeatures)),
            ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _name(),
              const SizedBox(height: 2),
              Text(sub, style: AppText.labelSm),
            ]),
          ),
          if (item.currentPrice != null) ...[
            const SizedBox(width: AppSpace.sm),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(won(item.currentPrice), style: AppText.labelLg.merge(AppText.numeric)),
              const SizedBox(height: 2),
              PriceChange(rate: item.changeRate, style: AppText.labelSm),
            ]),
          ],
          if (onFavorite != null)
            // IconButton 툴팁이 길게 누르기를 가로채므로 InkResponse 로 탭·길게 누르기를 함께 받는다.
            Semantics(
              button: true,
              label: favorite ? '관심종목' : '기본 폴더에 추가, 길게 눌러 폴더 선택',
              child: InkResponse(
                radius: 22,
                onTap: onFavorite,
                onLongPress: onFavoriteLong,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: favorite ? AppColors.bull : AppColors.textDisabled),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

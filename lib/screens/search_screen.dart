// lib/screens/search_screen.dart — W-08·09·10 종목 검색
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/folder_model.dart';
import '../models/stock_model.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import 'company/company_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

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

  @override
  void initState() {
    super.initState();
    _loadLanding();
  }

  void _loadLanding() {
    _recentFuture = ApiService().getRecentSearches();
    _rankingFuture = ApiService().getStockRanking();
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
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      try {
        final r = await ApiService().autocompleteStocks(text.trim());
        if (!mounted) return;
        setState(() => _suggestions = r.items);
      } catch (_) {}
    });
  }

  Future<void> _submitSearch(String keyword) async {
    final q = keyword.trim();
    if (q.isEmpty) return;
    setState(() {
      _searching = true;
      _suggestions = [];
    });
    try {
      final r = await ApiService().searchStocks(q);
      // 검색어 저장 (실패해도 결과는 표시)
      ApiService().addRecentSearch(q).catchError((_) {});
      if (!mounted) return;
      setState(() {
        _results = r;
        _resultsKeyword = q;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
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

  Future<void> _openFavoritePicker(StockBriefItem item) async {
    final added = await showDialog<bool>(
      context: context,
      builder: (_) => _FavoritePickerDialog(item: item),
    );
    if (added == true && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('"${item.name}" 추가됨')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppConstants.backgroundColor),
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '종목명 또는 코드 검색',
            border: InputBorder.none,
          ),
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          onSubmitted: _submitSearch,
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: _clearResults,
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_searching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_results != null) {
      return _ResultsList(
        response: _results!,
        keyword: _resultsKeyword!,
        onFavorite: _openFavoritePicker,
      );
    }
    if (_suggestions.isNotEmpty) {
      return _SuggestionsList(
        items: _suggestions,
        onSelect: (item) {
          _controller.text = item.name;
          _submitSearch(item.name);
        },
      );
    }
    return _LandingView(
      recentFuture: _recentFuture,
      rankingFuture: _rankingFuture,
      onSelectKeyword: (k) {
        _controller.text = k;
        _submitSearch(k);
      },
      onDeleteRecent: (k) async {
        await ApiService().deleteRecentSearch(keyword: k);
        setState(() => _recentFuture = ApiService().getRecentSearches());
      },
      onClearAllRecent: () async {
        await ApiService().deleteRecentSearch();
        setState(() => _recentFuture = ApiService().getRecentSearches());
      },
      onSelectStock: (item) => Navigator.pushNamed(
        context,
        '/company',
        arguments: CompanyArgs(
          ticker: item.ticker,
          name: item.name,
          currentPrice: item.currentPrice,
          changeRate: item.changeRate,
          changeAmount: item.changeAmount,
          initialTab: 0,
        ),
      ),
    );
  }
}

// ─── Landing (W-08): 최근 검색어 + 인기 순위 ─────────────────────────────────

class _LandingView extends StatelessWidget {
  final Future<RecentSearchResponse>? recentFuture;
  final Future<StockRankingResponse>? rankingFuture;
  final ValueChanged<String> onSelectKeyword;
  final ValueChanged<String> onDeleteRecent;
  final VoidCallback onClearAllRecent;
  final ValueChanged<StockBriefItem> onSelectStock;

  const _LandingView({
    required this.recentFuture,
    required this.rankingFuture,
    required this.onSelectKeyword,
    required this.onDeleteRecent,
    required this.onClearAllRecent,
    required this.onSelectStock,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // 최근 검색어
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('최근 검색어',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(AppConstants.textPrimary))),
            TextButton(
                onPressed: onClearAllRecent, child: const Text('전체 삭제')),
          ],
        ),
        const SizedBox(height: 4),
        FutureBuilder<RecentSearchResponse>(
          future: recentFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: LinearProgressIndicator(minHeight: 2),
              );
            }
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(snapshot.error.toString(),
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF9CA3AF))),
              );
            }
            final items = snapshot.data?.items ?? [];
            if (items.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('최근 검색 기록이 없습니다',
                    style: TextStyle(
                        fontSize: 12, color: Color(0xFF9CA3AF))),
              );
            }
            return Wrap(
              spacing: 6,
              runSpacing: 6,
              children: items
                  .map((e) => InputChip(
                        label: Text(e.keyword),
                        onPressed: () => onSelectKeyword(e.keyword),
                        onDeleted: () => onDeleteRecent(e.keyword),
                        deleteIconColor: const Color(0xFF9CA3AF),
                      ))
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 20),
        // 인기 순위
        const Text('실시간 인기 종목',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(AppConstants.textPrimary))),
        const SizedBox(height: 8),
        FutureBuilder<StockRankingResponse>(
          future: rankingFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: LinearProgressIndicator(minHeight: 2),
              );
            }
            if (snapshot.hasError) {
              return Text(snapshot.error.toString(),
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)));
            }
            final items = snapshot.data?.items ?? [];
            if (items.isEmpty) {
              return const Text('데이터가 없습니다',
                  style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)));
            }
            return Column(
              children: List.generate(items.length, (i) {
                final it = items[i];
                return _RankingTile(
                  rank: i + 1,
                  item: it,
                  onTap: () => onSelectStock(it),
                );
              }),
            );
          },
        ),
      ],
    );
  }
}

class _RankingTile extends StatelessWidget {
  final int rank;
  final StockBriefItem item;
  final VoidCallback onTap;
  const _RankingTile(
      {required this.rank, required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text('$rank',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(AppConstants.primaryColor))),
            ),
            const SizedBox(width: 6),
            Expanded(
                child: Text(item.name,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827)))),
            Text(item.ticker,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF9CA3AF))),
          ],
        ),
      ),
    );
  }
}

// ─── Suggestions (자동완성) ──────────────────────────────────────────────────

class _SuggestionsList extends StatelessWidget {
  final List<StockBriefItem> items;
  final ValueChanged<StockBriefItem> onSelect;
  const _SuggestionsList({required this.items, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final it = items[i];
        return ListTile(
          leading: const Icon(Icons.search_rounded, size: 18),
          title: Text(it.name),
          subtitle: Text('${it.ticker} · ${it.market}'),
          onTap: () => onSelect(it),
        );
      },
    );
  }
}

// ─── Results (W-09) ──────────────────────────────────────────────────────────

class _ResultsList extends StatelessWidget {
  final StockSearchResponse response;
  final String keyword;
  final ValueChanged<StockBriefItem> onFavorite;

  const _ResultsList({
    required this.response,
    required this.keyword,
    required this.onFavorite,
  });

  @override
  Widget build(BuildContext context) {
    if (response.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('"$keyword" 검색 결과가 없습니다',
              style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: response.items.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
      itemBuilder: (context, index) {
        final item = response.items[index];
        return _StockResultTile(
          item: item,
          onTap: () => Navigator.pushNamed(
            context,
            '/company',
            arguments: CompanyArgs(
              ticker: item.ticker,
              name: item.name,
              currentPrice: item.currentPrice,
              changeRate: item.changeRate,
              changeAmount: item.changeAmount,
              initialTab: 0,
            ),
          ),
          onFavorite: () => onFavorite(item),
        );
      },
    );
  }
}

class _StockResultTile extends StatelessWidget {
  final StockBriefItem item;
  final VoidCallback onTap;
  final VoidCallback onFavorite;

  const _StockResultTile(
      {required this.item, required this.onTap, required this.onFavorite});

  @override
  Widget build(BuildContext context) {
    final rate = item.changeRate;
    final isUp = (rate ?? 0) >= 0;
    final priceColor =
        isUp ? const Color(0xFFE53935) : const Color(0xFF1976D2);

    return Container(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8EAF6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(item.ticker,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A237E),
                        fontFamily: 'monospace')),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827))),
                    if (item.category != null) ...[
                      const SizedBox(height: 2),
                      Text(item.category!,
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF9CA3AF))),
                    ],
                  ],
                ),
              ),
              if (item.currentPrice != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('₩${_format(item.currentPrice!)}',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827))),
                    if (rate != null)
                      Text('${isUp ? '▲' : '▼'} ${rate.abs().toStringAsFixed(2)}%',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: priceColor)),
                  ],
                ),
              IconButton(
                icon: const Icon(Icons.bookmark_add_outlined,
                    color: Color(AppConstants.primaryColor)),
                onPressed: onFavorite,
                tooltip: '폴더에 추가',
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _format(int v) => v.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );
}

// ─── Favorite Picker Dialog (W-10) ───────────────────────────────────────────

class _FavoritePickerDialog extends StatefulWidget {
  final StockBriefItem item;
  const _FavoritePickerDialog({required this.item});

  @override
  State<_FavoritePickerDialog> createState() => _FavoritePickerDialogState();
}

class _FavoritePickerDialogState extends State<_FavoritePickerDialog> {
  late Future<FoldersResponse> _foldersFuture;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _foldersFuture = ApiService().getFolders();
  }

  Future<void> _select(Folder folder) async {
    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ApiService().addFavorite(folder.id, widget.item.ticker);
      navigator.pop(true);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('"${widget.item.name}" 추가'),
      content: SizedBox(
        width: 320,
        height: 320,
        child: FutureBuilder<FoldersResponse>(
          future: _foldersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text(snapshot.error.toString()));
            }
            final folders = snapshot.data!.folders;
            if (folders.isEmpty) {
              return const Center(child: Text('폴더가 없습니다. 먼저 폴더를 만들어주세요.'));
            }
            return ListView.separated(
              itemCount: folders.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final f = folders[i];
                return ListTile(
                  leading: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _hexToColor(f.color),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Center(
                        child: Text('📁', style: TextStyle(fontSize: 14))),
                  ),
                  title: Text(f.name),
                  subtitle: Text('${f.itemCount}개'),
                  onTap: _submitting ? null : () => _select(f),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context, false),
          child: const Text('취소'),
        ),
      ],
    );
  }
}

Color _hexToColor(String hex) {
  final h = hex.replaceFirst('#', '');
  return Color(int.parse('FF$h', radix: 16));
}

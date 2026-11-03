// lib/screens/home_screen.dart — 홈 탭: 새 분석 보고서 피드 + 내 관심종목
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/folder_model.dart';
import '../models/market_model.dart';
import '../services/api_service.dart';
import '../services/auth_provider.dart';
import '../utils/design_tokens.dart';
import '../utils/format.dart';
import '../widgets/ds.dart';
import '../widgets/favorite_actions.dart';
import 'company/company_detail_screen.dart';
import 'main_shell.dart';

/// 화면에 쓰는 관심종목 한 줄. 이동·삭제에 폴더 id 가 필요해 함께 들고 다닌다.
typedef _Entry = ({int folderId, FolderItem item});

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Folder> _folders = [];
  Map<int, List<FolderItem>> _items = {};
  bool _loading = true;
  bool _loaded = false;
  Object? _error;
  DateTime _loadedAt = DateTime.now();
  int? _folderId; // null = 전체
  bool _showAllReports = false;
  int? _lastTab;
  MarketSummary? _market; // 실패하면 null 로 두고 카드를 숨긴다

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 다른 탭에서 종목을 추가·삭제했을 수 있으니 홈 탭으로 돌아올 때마다 새로 불러온다.
    final tab = MainShellScope.maybeOf(context)?.currentIndex;
    if (tab == 0 && _lastTab != null && _lastTab != 0) _load();
    _lastTab = tab;
  }

  // 탭 재진입·화면 복귀·당겨서 새로고침이 겹치면 늦게 온 옛 응답이 새 응답을 덮을 수 있다.
  int _loadSeq = 0;

  Future<void> _load() async {
    final seq = ++_loadSeq;
    setState(() {
      _loading = true;
      _error = null;
    });
    _loadMarket(seq);
    try {
      final folders = (await ApiService().getFolders()).folders;
      final lists = await Future.wait(
          folders.map((f) => ApiService().getFolderItems(f.id)));
      if (!mounted || seq != _loadSeq) return;
      setState(() {
        _folders = folders;
        _items = {
          for (var i = 0; i < folders.length; i++) folders[i].id: lists[i].items
        };
        if (_folderId != null && !_items.containsKey(_folderId)) {
          _folderId = null;
        }
        _loadedAt = DateTime.now();
        _loaded = true;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || seq != _loadSeq) return;
      setState(() {
        _error = e;
        _loading = false;
      });
      if (_loaded) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  // 관심종목 로드와 따로 돌려서, 시장 요약이 느리거나 실패해도 홈이 기다리지 않게 한다.
  Future<void> _loadMarket(int seq) async {
    MarketSummary? m;
    try {
      m = await ApiService().getMarketSummary();
    } catch (_) {}
    if (!mounted || seq != _loadSeq) return;
    setState(() => _market = m);
  }

  /// "전체" 는 폴더 순서대로 모으되 같은 종목은 한 번만.
  List<_Entry> _entries(int? folderId) {
    final seen = <String>{};
    return [
      for (final f in _folders)
        if (folderId == null || f.id == folderId)
          for (final it in _items[f.id] ?? const <FolderItem>[])
            if (seen.add(it.ticker)) (folderId: f.id, item: it),
    ];
  }

  List<FolderItem> _reports(List<_Entry> entries) {
    final list = [
      for (final e in entries)
        if (e.item.analysisSummary?.hasTheme == true &&
            e.item.analysisSummary?.latestReportId != null)
          e.item,
    ];
    final epoch = DateTime.fromMillisecondsSinceEpoch(0);
    list.sort((a, b) => (b.analysisSummary!.generatedAt ?? epoch)
        .compareTo(a.analysisSummary!.generatedAt ?? epoch));
    return list;
  }

  Future<void> _push(String route, Object args) async {
    await Navigator.pushNamed(context, route, arguments: args);
    if (mounted) _load();
  }

  void _openCompany(FolderItem it) => _push(
        '/company',
        CompanyArgs(
          ticker: it.ticker,
          name: it.name,
          currentPrice: it.currentPrice,
          changeRate: it.changeRate,
          changeAmount: it.changeAmount,
          isFavorite: true,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final nickname =
        context.watch<AuthProvider>().currentUser?.nickname ?? '투자자';

    Widget body;
    if (!_loaded && _loading) {
      body = ListView(
        padding: const EdgeInsets.all(AppSpace.lg),
        children: const [
          SkeletonBox(height: 60, width: 240),
          SizedBox(height: AppSpace.xl),
          SkeletonList(count: 2, itemHeight: 120),
          SizedBox(height: AppSpace.xl),
          SkeletonList(count: 4, itemHeight: 56),
        ],
      );
    } else if (!_loaded && _error != null) {
      body =
          Center(child: ErrorRetry(message: _error.toString(), onRetry: _load));
    } else {
      body = _buildFeed(nickname);
    }
    return Scaffold(
        backgroundColor: AppColors.canvas, body: SafeArea(child: body));
  }

  Widget _buildFeed(String nickname) {
    // 공시 수집 범위가 최근 7일이라 "오늘" 로 세면 새벽에는 늘 0건이 된다.
    final since = DateTime.now().subtract(const Duration(days: 7));
    final recentCount = _reports(_entries(null)).where((it) {
      final g = it.analysisSummary!.generatedAt?.toLocal();
      return g != null && g.isAfter(since);
    }).length;
    final entries = _entries(_folderId);
    final reports = _reports(entries);
    final shownReports = _showAllReports ? reports : reports.take(3).toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
            AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.lg),
        children: [
          if (_market != null) ...[
            _MarketCard(
              summary: _market!,
              onOpenStock: (h) => _push(
                  '/company',
                  CompanyArgs(ticker: h.ticker, name: h.name, initialTab: 1)),
            ),
            const SizedBox(height: AppSpace.xl),
          ],
          Text.rich(
            TextSpan(children: [
              TextSpan(text: '$nickname님,\n최근 7일 내 종목에 '),
              TextSpan(
                  text: '새 분석 $recentCount건',
                  style: const TextStyle(color: AppColors.accent)),
            ]),
            style: AppText.headlineLg,
          ),
          const SizedBox(height: AppSpace.md),
          _FolderChips(
            folders: _folders,
            itemCounts: {
              for (final f in _folders) f.id: _items[f.id]?.length ?? 0
            },
            selected: _folderId,
            onSelect: (id) => setState(() {
              _folderId = id;
              _showAllReports = false;
            }),
            onManage: () async {
              await Navigator.pushNamed(context, '/folders');
              if (mounted) _load();
            },
          ),
          const SizedBox(height: AppSpace.xl),
          if (entries.isEmpty)
            EmptyState(
              icon: Icons.star_outline_rounded,
              title: '관심종목을 추가하면 새 공시 분석을 모아 보여드려요',
              actionLabel: '종목 찾아보기',
              onAction: () => MainShellScope.maybeOf(context)?.goTo(1),
            )
          else ...[
            SectionTitle(
              '새 분석 보고서',
              info: const InfoButton(
                title: '예상 CAR',
                body: '공시가 나온 뒤 며칠 동안 시장 평균보다 주가가 얼마나 더(덜) 오를지를 '
                    '테마 분석으로 추정한 값이에요. 빨강은 플러스, 파랑은 마이너스 예상이에요.',
              ),
              trailing: reports.length > 3
                  ? TextButton(
                      onPressed: () =>
                          setState(() => _showAllReports = !_showAllReports),
                      child: Text(_showAllReports ? '접기' : '전체 보기'),
                    )
                  : null,
            ),
            if (reports.isEmpty)
              const EmptyState(
                  icon: Icons.insights_rounded, title: '아직 분석된 공시가 없어요')
            else
              for (final it in shownReports) ...[
                _ReportCard(
                  item: it,
                  onTap: () =>
                      _push('/report', it.analysisSummary!.latestReportId!),
                ),
                const SizedBox(height: AppSpace.sm + 4),
              ],
            const SizedBox(height: AppSpace.sm),
            SectionTitle('내 관심종목',
                info: const InfoButton(
                  title: '오른쪽 칩',
                  body: '종목의 가장 최근 공시 분석에서 나온 예상 CAR이에요. '
                      '빨간 숫자는 읽지 않은 공시 수예요. 줄을 왼쪽으로 밀거나 길게 누르면 폴더 이동·삭제·메모를 할 수 있어요.',
                ),
                trailing:
                    Text('${mdHm(_loadedAt)} 기준', style: AppText.labelSm)),
            DsCard(
              padding: EdgeInsets.zero,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: Column(children: [
                  for (var i = 0; i < entries.length; i++) ...[
                    if (i > 0)
                      const Divider(
                          height: 1,
                          indent: AppSpace.md,
                          endIndent: AppSpace.md),
                    FavoriteStockRow(
                      item: entries[i].item,
                      folderId: entries[i].folderId,
                      onTap: () => _openCompany(entries[i].item),
                      onChanged: _load,
                    ),
                  ],
                ]),
              ),
            ),
            const Disclaimer(),
          ],
        ],
      ),
    );
  }
}

// ─── 시장 요약 카드 ───────────────────────────────────────────────────────────

class _MarketCard extends StatelessWidget {
  final MarketSummary summary;
  final ValueChanged<HotStock> onOpenStock;
  const _MarketCard({required this.summary, required this.onOpenStock});

  /// 5859.08 → "5,859.08"
  static String _fixed2(double v) {
    final s = v.abs().toStringAsFixed(2).split('.');
    return '${v < 0 ? '-' : ''}${comma(int.parse(s[0]))}.${s[1]}';
  }

  Widget _indexTile(MarketIndex ix) {
    final dir = ix.changeRate ?? ix.change;
    final color = AppColors.market(dir);
    final parts = [
      if (arrow(dir).isNotEmpty) arrow(dir),
      if (ix.change != null) _fixed2(ix.change!.abs()),
      if (ix.changeRate != null)
        ix.change != null
            ? '(${signedPct(ix.changeRate)})'
            : signedPct(ix.changeRate),
    ];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: AppColors.marketTint(dir),
          borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(ix.name, style: AppText.labelMd),
        const SizedBox(height: 4),
        Text(_fixed2(ix.value),
            style: AppText.headlineSm.merge(AppText.numeric)),
        const SizedBox(height: 2),
        Text(parts.isEmpty ? '—' : parts.join(' '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.labelSm.copyWith(
                color: color, fontFeatures: AppText.numeric.fontFeatures)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final date = summary.latestDisclosureDate;
    final count = summary.latestDisclosureCount;
    final hot = summary.hotStocks.take(5).toList();
    return DsCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('시장 요약', style: AppText.headlineSm),
        if (summary.indices.isNotEmpty) ...[
          const SizedBox(height: AppSpace.sm + 4),
          Row(children: [
            for (var i = 0; i < summary.indices.length; i++) ...[
              if (i > 0) const SizedBox(width: AppSpace.sm),
              Expanded(child: _indexTile(summary.indices[i])),
            ],
          ]),
        ],
        if (date != null && count != null) ...[
          const SizedBox(height: AppSpace.sm + 4),
          Text('최근 공시 ${ymd(date, sep: '/').substring(5)} · ${comma(count)}건',
              style: AppText.bodySm.merge(AppText.numeric)),
        ],
        if (hot.isNotEmpty) ...[
          const SizedBox(height: AppSpace.sm + 4),
          const Text('공시 많은 종목 (최근 7일)', style: AppText.labelMd),
          const SizedBox(height: AppSpace.sm),
          Wrap(spacing: AppSpace.sm, runSpacing: AppSpace.sm, children: [
            for (final h in hot)
              Material(
                color: AppColors.subtle,
                shape: const StadiumBorder(),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: () => onOpenStock(h),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Text('${h.name} ${comma(h.disclosureCount)}건',
                        style: AppText.labelMd
                            .copyWith(fontFeatures: AppText.numeric.fontFeatures)),
                  ),
                ),
              ),
          ]),
        ],
      ]),
    );
  }
}

// ─── 폴더 필터 칩 ─────────────────────────────────────────────────────────────

class _FolderChips extends StatelessWidget {
  final List<Folder> folders;
  final Map<int, int> itemCounts;
  final int? selected;
  final ValueChanged<int?> onSelect;
  final VoidCallback onManage;

  const _FolderChips({
    required this.folders,
    required this.itemCounts,
    required this.selected,
    required this.onSelect,
    required this.onManage,
  });

  Widget _chip(String label,
      {required bool active, required VoidCallback onTap, Color? fg}) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpace.sm),
      child: Material(
        color: active ? AppColors.brand : AppColors.card,
        shape: StadiumBorder(
            side:
                BorderSide(color: active ? AppColors.brand : AppColors.border)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(label,
                style: AppText.labelLg.copyWith(
                    color:
                        active ? Colors.white : (fg ?? AppColors.textSecondary),
                    fontFeatures: AppText.numeric.fontFeatures)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        _chip('전체', active: selected == null, onTap: () => onSelect(null)),
        for (final f in folders)
          _chip('${f.name} ${itemCounts[f.id] ?? 0}',
              active: selected == f.id, onTap: () => onSelect(f.id)),
        _chip('+ 폴더', active: false, onTap: onManage, fg: AppColors.accent),
      ]),
    );
  }
}

// ─── 새 분석 보고서 카드 ──────────────────────────────────────────────────────

class _ReportCard extends StatelessWidget {
  final FolderItem item;
  final VoidCallback onTap;
  const _ReportCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = item.analysisSummary!;
    final car = s.expectedCar;
    return DsCard(
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Flexible(
              child: Text(item.name,
                  style: AppText.labelLg, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 6),
          Text(item.ticker, style: AppText.labelSm),
          const Spacer(),
          if (s.generatedAt != null)
            Text(relativeTime(s.generatedAt!), style: AppText.labelSm),
        ]),
        if (s.summary != null && s.summary!.isNotEmpty) ...[
          const SizedBox(height: AppSpace.sm),
          Text(s.summary!,
              style: AppText.bodyMd.copyWith(color: AppColors.textSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ],
        const SizedBox(height: AppSpace.sm + 4),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          if (s.themeName != null) ThemeChip(s.themeName!),
          const Spacer(),
          if (car == null)
            const CarBadge(null)
          else
            // CarBadge 와 같은 채운 바탕을 크게: ML 60일 전망(테두리 카드)과 헷갈리지 않게 한다.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                  color: AppColors.marketTint(car),
                  borderRadius: BorderRadius.circular(AppRadius.md)),
              child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('${arrow(car)} ${signedPct(car, digits: 1)}'.trim(),
                        style: AppText.numericMetric
                            .copyWith(color: AppColors.market(car))),
                    const SizedBox(width: 4),
                    Text('예상 CAR',
                        style: AppText.labelMd
                            .copyWith(color: AppColors.market(car))),
                  ]),
            ),
        ]),
      ]),
    );
  }
}

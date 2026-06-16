// lib/screens/company/company_detail_screen.dart — W-11~15 기업 상세 (탭 쉘)
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/stock_model.dart';
import '../../services/api_service.dart';
import 'analysis_tab.dart';

class CompanyArgs {
  final String ticker;
  final String name;
  final int? currentPrice;
  final double? changeRate;
  final int? changeAmount;
  final bool isFavorite;
  final int initialTab; // 0=정보, 1=뉴스, 2=재무, 3=공시, 4=분석

  const CompanyArgs({
    required this.ticker,
    required this.name,
    this.currentPrice,
    this.changeRate,
    this.changeAmount,
    this.isFavorite = false,
    this.initialTab = 4, // W-15 진입 기본값
  });
}

class CompanyDetailScreen extends StatefulWidget {
  const CompanyDetailScreen({super.key});

  @override
  State<CompanyDetailScreen> createState() => _CompanyDetailScreenState();
}

class _CompanyDetailScreenState extends State<CompanyDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late CompanyArgs _args;
  bool _argsInitialized = false;

  static const _tabs = ['정보', '뉴스', '재무', '공시', '분석'];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_argsInitialized) {
      final args =
          ModalRoute.of(context)?.settings.arguments as CompanyArgs?;
      _args = args ??
          const CompanyArgs(ticker: '005930', name: '삼성전자', initialTab: 4);
      _tabController = TabController(
        length: _tabs.length,
        vsync: this,
        initialIndex: _args.initialTab,
      );
      _argsInitialized = true;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildAppBar(innerBoxIsScrolled),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _InfoTab(ticker: _args.ticker),
            _NewsTab(ticker: _args.ticker),
            _FinanceTab(ticker: _args.ticker),
            _DisclosuresTab(ticker: _args.ticker),
            AnalysisTab(ticker: _args.ticker),
          ],
        ),
      ),
    );
  }

  SliverAppBar _buildAppBar(bool innerBoxIsScrolled) {
    final price = _args.currentPrice;
    final rate = _args.changeRate;
    final amount = _args.changeAmount;
    final isUp = (rate ?? 0) >= 0;
    final priceColor =
        isUp ? const Color(0xFFE53935) : const Color(0xFF1976D2);

    return SliverAppBar(
      pinned: true,
      floating: false,
      snap: false,
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF111827),
      elevation: 0,
      scrolledUnderElevation: 1,
      leading: const BackButton(),
      title: Text(
        _args.name,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: Color(0xFF111827),
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(
            _args.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: _args.isFavorite ? const Color(0xFFE53935) : const Color(0xFF9CA3AF),
          ),
          onPressed: () {
            // TODO: W-10 폴더 선택 모달
          },
        ),
      ],
      // 종목코드 + 현재가 바
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(88),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 가격 바
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Color(0xFFF3F4F6), width: 1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _args.ticker,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (price != null) ...[
                    Text(
                      '₩${_formatPrice(price)}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: priceColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (rate != null && amount != null)
                      Text(
                        '${isUp ? '▲' : '▼'} ${_formatPrice(amount.abs())} (${rate.abs().toStringAsFixed(2)}%)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: priceColor,
                        ),
                      ),
                  ] else
                    const Text(
                      '—',
                      style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                    ),
                ],
              ),
            ),
            // 탭 바
            TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF1A237E),
              unselectedLabelColor: const Color(0xFF6B7280),
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
              indicatorColor: const Color(0xFF1A237E),
              indicatorWeight: 2,
              dividerColor: const Color(0xFFE5E7EB),
              tabs: _tabs.map((t) => Tab(text: t)).toList(),
            ),
          ],
        ),
      ),
    );
  }

  String _formatPrice(int price) {
    final str = price.toString();
    final result = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) result.write(',');
      result.write(str[i]);
    }
    return result.toString();
  }
}

// ─── Info Tab (W-11) ─────────────────────────────────────────────────────────

class _InfoTab extends StatefulWidget {
  final String ticker;
  const _InfoTab({required this.ticker});

  @override
  State<_InfoTab> createState() => _InfoTabState();
}

class _InfoTabState extends State<_InfoTab>
    with AutomaticKeepAliveClientMixin {
  late Future<StockDetailResponse> _future;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = ApiService().getStockDetail(widget.ticker);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<StockDetailResponse>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _Err(message: snapshot.error.toString());
        }
        final s = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _kv('종목 코드', s.ticker),
            _kv('이름', s.name),
            _kv('시장', s.market),
            if (s.category != null) _kv('업종', s.category!),
            if (s.listedAt != null) _kv('상장일', s.listedAt!),
            if (s.currentPrice != null) _kv('현재가', '₩${_n(s.currentPrice!)}'),
            if (s.changeRate != null)
              _kv('등락률', '${s.changeRate!.toStringAsFixed(2)}%'),
            if (s.description != null && s.description!.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('소개',
                  style:
                      TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(s.description!,
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF374151), height: 1.4)),
            ],
          ],
        );
      },
    );
  }
}

// ─── News Tab (W-12) ─────────────────────────────────────────────────────────

class _NewsTab extends StatefulWidget {
  final String ticker;
  const _NewsTab({required this.ticker});

  @override
  State<_NewsTab> createState() => _NewsTabState();
}

class _NewsTabState extends State<_NewsTab>
    with AutomaticKeepAliveClientMixin {
  late Future<StockNewsResponse> _future;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = ApiService().getStockNews(widget.ticker);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<StockNewsResponse>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _Err(message: snapshot.error.toString());
        }
        final items = snapshot.data!.items;
        if (items.isEmpty) return const _Empty(label: '관련 뉴스가 없습니다');
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 6),
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final n = items[i];
            return ListTile(
              title: Text(n.title,
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text('${n.source ?? ''} · ${_short(n.publishedAt)}',
                  style: const TextStyle(fontSize: 11)),
              trailing: const Icon(Icons.open_in_new_rounded,
                  size: 18, color: Color(0xFF9CA3AF)),
              onTap: n.url.isEmpty ? null : () => _openExternal(context, n.url),
            );
          },
        );
      },
    );
  }
}

// ─── Finance Tab (W-13) ──────────────────────────────────────────────────────

class _FinanceTab extends StatefulWidget {
  final String ticker;
  const _FinanceTab({required this.ticker});

  @override
  State<_FinanceTab> createState() => _FinanceTabState();
}

class _FinanceTabState extends State<_FinanceTab>
    with AutomaticKeepAliveClientMixin {
  late Future<StockFinanceResponse> _future;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = ApiService().getStockFinance(widget.ticker);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<StockFinanceResponse>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _Err(message: snapshot.error.toString());
        }
        final items = snapshot.data!.items;
        if (items.isEmpty) return const _Empty(label: '재무 데이터가 없습니다');
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          itemBuilder: (_, i) {
            final f = items[i];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${f.period} (${f.periodType})',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    if (f.revenue != null) _kv('매출', '₩${_n(f.revenue!)}'),
                    if (f.operatingProfit != null)
                      _kv('영업이익', '₩${_n(f.operatingProfit!)}'),
                    if (f.netIncome != null)
                      _kv('순이익', '₩${_n(f.netIncome!)}'),
                    if (f.per != null) _kv('PER', f.per!.toStringAsFixed(2)),
                    if (f.pbr != null) _kv('PBR', f.pbr!.toStringAsFixed(2)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ─── Disclosures Tab (W-14) ─────────────────────────────────────────────────

class _DisclosuresTab extends StatefulWidget {
  final String ticker;
  const _DisclosuresTab({required this.ticker});

  @override
  State<_DisclosuresTab> createState() => _DisclosuresTabState();
}

class _DisclosuresTabState extends State<_DisclosuresTab>
    with AutomaticKeepAliveClientMixin {
  late Future<StockDisclosuresResponse> _future;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = ApiService().getStockDisclosures(widget.ticker);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<StockDisclosuresResponse>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _Err(message: snapshot.error.toString());
        }
        final items = snapshot.data!.items;
        if (items.isEmpty) return const _Empty(label: '공시가 없습니다');
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 6),
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final d = items[i];
            final url = d.dartUrl ?? '';
            return ListTile(
              leading: const Icon(Icons.article_outlined, size: 20),
              title: Text(d.title,
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text('${d.type} · ${_short(d.filedAt)}',
                  style: const TextStyle(fontSize: 11)),
              trailing: const Icon(Icons.open_in_new_rounded,
                  size: 18, color: Color(0xFF9CA3AF)),
              onTap: url.isEmpty ? null : () => _openExternal(context, url),
            );
          },
        );
      },
    );
  }
}

Future<void> _openExternal(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('링크를 열 수 없습니다')));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

Widget _kv(String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
              width: 70,
              child: Text(k,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF6B7280)))),
          Expanded(
              child: Text(v,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827)))),
        ],
      ),
    );

String _n(int v) => v.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );

String _short(String iso) {
  if (iso.length >= 10) return iso.substring(0, 10);
  return iso;
}

class _Empty extends StatelessWidget {
  final String label;
  const _Empty({required this.label});

  @override
  Widget build(BuildContext context) => Center(
        child: Text(label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
      );
}

class _Err extends StatelessWidget {
  final String message;
  const _Err({required this.message});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(message,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
        ),
      );
}

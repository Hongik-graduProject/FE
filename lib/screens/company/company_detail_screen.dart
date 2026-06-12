// lib/screens/company/company_detail_screen.dart — W-11~15 기업 상세 (탭 쉘)
import 'package:flutter/material.dart';
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
            const _PlaceholderTab(label: '기업 정보 (W-11) 준비 중'),
            const _PlaceholderTab(label: '뉴스 (W-12) 준비 중'),
            const _PlaceholderTab(label: '재무 (W-13) 준비 중'),
            const _PlaceholderTab(label: '공시 (W-14) 준비 중'),
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

class _PlaceholderTab extends StatelessWidget {
  final String label;
  const _PlaceholderTab({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        label,
        style: const TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
      ),
    );
  }
}

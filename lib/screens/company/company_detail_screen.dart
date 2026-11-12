import 'package:flutter/material.dart';

import '../../models/stock_model.dart';
import '../../services/api_service.dart';
import '../../utils/design_tokens.dart';
import '../../utils/format.dart';
import '../../widgets/ds.dart';
import '../../widgets/favorite_picker_dialog.dart';
import 'analysis_tab.dart';
import 'tabs/chart_info_tab.dart';
import 'tabs/disclosures_tab.dart';
import 'tabs/finance_tab.dart';
import 'tabs/news_tab.dart';

class CompanyArgs {
  final String ticker;
  final String name;
  final int? currentPrice;
  final double? changeRate;
  final int? changeAmount;
  final bool isFavorite;
  final int initialTab; // 0=분석, 1=공시, 2=차트·정보, 3=재무, 4=뉴스

  const CompanyArgs({
    required this.ticker,
    required this.name,
    this.currentPrice,
    this.changeRate,
    this.changeAmount,
    this.isFavorite = false,
    this.initialTab = 0, // 분석 탭이 기본
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
  late bool _isFavorite;
  late Future<StockDetailResponse> _detailFuture;
  StockDetailResponse? _detail;
  DateTime? _loadedAt;

  static const _tabs = ['분석', '공시', '차트·정보', '재무', '뉴스'];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_argsInitialized) {
      final args = ModalRoute.of(context)?.settings.arguments as CompanyArgs?;
      _args = args ?? const CompanyArgs(ticker: '005930', name: '삼성전자');
      _tabController = TabController(
        length: _tabs.length,
        vsync: this,
        initialIndex: _args.initialTab.clamp(0, _tabs.length - 1),
      );
      _isFavorite = _args.isFavorite;
      _argsInitialized = true;
      // 차트·정보 탭을 열지 않으면 아무도 오류를 받지 않으므로 미처리 오류로 남지 않게 한다.
      _detailFuture = _loadDetail()..ignore();
    }
  }

  // 검색·알림 등에서 들어오면 args 의 가격·isFavorite 가 비어 있어 서버 값으로 맞춘다.
  // 헤더와 차트·정보 탭이 이 한 번의 응답을 같이 쓴다.
  Future<StockDetailResponse> _loadDetail() async {
    final d = await ApiService().getStockDetail(_args.ticker);
    if (mounted) {
      setState(() {
        _detail = d;
        _isFavorite = d.isFavorite;
        _loadedAt = DateTime.now();
      });
    }
    return d;
  }

  Future<void> _reloadDetail() async {
    setState(() { _detailFuture = _loadDetail()..ignore(); });
    try {
      await _detailFuture;
    } catch (_) {} // 오류는 차트·정보 탭이 보여준다.
  }

  Future<void> _onFavoritePressed() async {
    if (_isFavorite) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미 관심종목이에요. 폴더에서 이동·삭제할 수 있어요')));
      return;
    }
    final added = await showDialog<bool>(
      context: context,
      builder: (_) =>
          FavoritePickerDialog(ticker: _args.ticker, name: _args.name),
    );
    if (added == true && mounted) {
      setState(() => _isFavorite = true);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('"${_args.name}" 추가됨')));
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
      backgroundColor: AppColors.canvas,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            pinned: true,
            toolbarHeight: 56,
            backgroundColor: AppColors.card,
            surfaceTintColor: Colors.transparent,
            leading: const BackButton(),
            title: Text(_detail?.name ?? _args.name, style: AppText.headlineMd),
            actions: [
              IconButton(
                tooltip: _isFavorite ? '관심종목' : '관심종목 추가',
                icon: Icon(
                  _isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: _isFavorite ? AppColors.bull : AppColors.textTertiary,
                ),
                onPressed: _onFavoritePressed,
              ),
            ],
          ),
          SliverToBoxAdapter(child: _priceHeader()),
          SliverAppBar(
            pinned: true,
            primary: false,
            toolbarHeight: 0,
            automaticallyImplyLeading: false,
            backgroundColor: AppColors.card,
            surfaceTintColor: Colors.transparent,
            bottom: TabBar(
              controller: _tabController,
              // 탭 5개가 고정 폭이라 기본 여백(16)이면 "차트·정보" 가 잘린다.
              labelPadding: const EdgeInsets.symmetric(horizontal: 2),
              tabs: _tabs.map((t) => Tab(text: t)).toList(),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            AnalysisTab(ticker: _args.ticker),
            DisclosuresTab(ticker: _args.ticker),
            ChartInfoTab(
              ticker: _args.ticker,
              detail: _detailFuture,
              onReloadDetail: _reloadDetail,
            ),
            FinanceTab(ticker: _args.ticker),
            NewsTab(ticker: _args.ticker),
          ],
        ),
      ),
    );
  }

  Widget _priceHeader() {
    final d = _detail;
    // 상세 응답 전에는 목록에서 넘겨준 값이 있으면 먼저 보여준다.
    final price = d?.currentPrice ?? _args.currentPrice;
    final rate = d != null ? d.changeRate : _args.changeRate;
    final amount = d != null ? d.changeAmount : _args.changeAmount;
    final market = d?.market ?? '';

    return Container(
      color: AppColors.card,
      padding:
          const EdgeInsets.fromLTRB(AppSpace.lg, 0, AppSpace.lg, AppSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DsPill(market.isEmpty ? _args.ticker : '${_args.ticker} · $market',
              height: 22,
              background: AppColors.subtle,
              foreground: AppColors.textSecondary),
          const SizedBox(height: AppSpace.sm),
          if (price != null)
            Text.rich(TextSpan(children: [
              TextSpan(text: comma(price), style: AppText.numericHero),
              const TextSpan(text: ' 원', style: AppText.headlineSm),
            ]))
          else if (d == null)
            const SkeletonBox(height: 40, width: 160)
          else
            Text('—',
                style: AppText.numericHero.copyWith(color: AppColors.flat)),
          const SizedBox(height: AppSpace.xs),
          Row(children: [
            PriceChange(amount: amount, rate: rate, style: AppText.labelLg),
            if (_loadedAt != null) ...[
              const SizedBox(width: AppSpace.sm),
              Text('${mdHm(_loadedAt!)} 기준', style: AppText.labelSm),
            ],
          ]),
        ],
      ),
    );
  }
}

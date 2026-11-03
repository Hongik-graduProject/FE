// lib/screens/folder/folder_detail_screen.dart — W-05 폴더 상세 + 종목 CRUD
import 'package:flutter/material.dart';
import '../../models/folder_model.dart';
import '../../services/api_service.dart';
import '../../utils/design_tokens.dart';
import '../../utils/format.dart';
import '../../widgets/ds.dart';
import '../../widgets/favorite_actions.dart';
import '../company/company_detail_screen.dart';

class FolderDetailScreen extends StatefulWidget {
  const FolderDetailScreen({super.key});

  @override
  State<FolderDetailScreen> createState() => _FolderDetailScreenState();
}

class _FolderDetailScreenState extends State<FolderDetailScreen> {
  late FolderArgs _args;
  late Future<FolderItemsResponse> _future;
  DateTime _loadedAt = DateTime.now();
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _args = ModalRoute.of(context)!.settings.arguments as FolderArgs;
      _future = ApiService().getFolderItems(_args.id);
    }
  }

  void _reload() {
    setState(() {
      _loadedAt = DateTime.now();
      _future = ApiService().getFolderItems(_args.id);
    });
  }

  Future<void> _addStock() async {
    await Navigator.pushNamed(context, '/search');
    // 검색 화면에서 돌아오면 새로 추가된 종목 반영 위해 reload
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: Text(_initialized ? _args.name : '')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addStock,
        icon: const Icon(Icons.add_rounded),
        label: const Text('종목 추가'),
      ),
      body: FutureBuilder<FolderItemsResponse>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(AppSpace.lg),
              child: SkeletonList(count: 5, itemHeight: 64),
            );
          }
          if (snapshot.hasError) {
            return Center(child: ErrorRetry(message: snapshot.error.toString(), onRetry: _reload));
          }
          final items = snapshot.data!.items;
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, 96),
              children: [
                if (items.isEmpty)
                  EmptyState(
                    icon: Icons.folder_open_rounded,
                    title: '폴더에 종목이 없어요',
                    message: '종목을 추가하면 새 공시 분석을 모아 보여드려요',
                    actionLabel: '종목 추가',
                    onAction: _addStock,
                  )
                else ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.sm),
                    child: Text('종목 ${items.length}개 · ${mdHm(_loadedAt)} 기준', style: AppText.labelSm),
                  ),
                  DsCard(
                    padding: EdgeInsets.zero,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      child: Column(children: [
                        for (var i = 0; i < items.length; i++) ...[
                          if (i > 0) const Divider(height: 1, indent: AppSpace.md, endIndent: AppSpace.md),
                          FavoriteStockRow(
                            item: items[i],
                            folderId: _args.id,
                            onChanged: _reload,
                            onTap: () => Navigator.pushNamed(
                              context,
                              '/company',
                              arguments: CompanyArgs(
                                ticker: items[i].ticker,
                                name: items[i].name,
                                currentPrice: items[i].currentPrice,
                                changeRate: items[i].changeRate,
                                changeAmount: items[i].changeAmount,
                                isFavorite: true,
                              ),
                            ),
                          ),
                        ],
                      ]),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

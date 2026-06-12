// lib/screens/folder/folder_detail_screen.dart — W-05 폴더 상세
import 'package:flutter/material.dart';
import '../../models/folder_model.dart';
import '../../services/api_service.dart';
import '../company/company_detail_screen.dart';

class FolderDetailScreen extends StatefulWidget {
  const FolderDetailScreen({super.key});

  @override
  State<FolderDetailScreen> createState() => _FolderDetailScreenState();
}

class _FolderDetailScreenState extends State<FolderDetailScreen> {
  late FolderArgs _args;
  late Future<FolderItemsResponse> _future;
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
      _future = ApiService().getFolderItems(_args.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(_initialized ? _args.name : ''),
      ),
      body: FutureBuilder<FolderItemsResponse>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorBody(
              message: snapshot.error.toString(),
              onRetry: _reload,
            );
          }
          final items = snapshot.data!.items;
          if (items.isEmpty) {
            return const _EmptyBody();
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: items.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _CompanyCard(
                  item: items[index],
                  onTap: () => Navigator.pushNamed(
                    context,
                    '/company',
                    arguments: CompanyArgs(
                      ticker: items[index].ticker,
                      name: items[index].name,
                      currentPrice: items[index].currentPrice,
                      changeRate: items[index].changeRate,
                      changeAmount: items[index].changeAmount,
                      isFavorite: true,
                      initialTab: 0,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Company Card ─────────────────────────────────────────────────────────────

class _CompanyCard extends StatelessWidget {
  final FolderItem item;
  final VoidCallback onTap;

  const _CompanyCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isUp = item.changeRate >= 0;
    final priceColor =
        isUp ? const Color(0xFFE53935) : const Color(0xFF1976D2);
    final priceIcon = isUp ? '▲' : '▼';
    final changeStr =
        '$priceIcon ${item.changeRate.abs().toStringAsFixed(2)}%';
    final hasUnread = item.unreadDisclosureCount > 0;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              // 종목 코드 배지
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8EAF6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.ticker,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A237E),
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // 종목명
              Expanded(
                child: Row(
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    if (hasUnread) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // 시세
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₩${_formatPrice(item.currentPrice)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    changeStr,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: priceColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: Color(0xFF9CA3AF),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
  }
}

// ─── Empty / Error ────────────────────────────────────────────────────────────

class _EmptyBody extends StatelessWidget {
  const _EmptyBody();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('📁', style: TextStyle(fontSize: 40)),
          SizedBox(height: 12),
          Text(
            '폴더에 종목이 없습니다',
            style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBody({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 40, color: Color(0xFF9CA3AF)),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF6B7280))),
            const SizedBox(height: 16),
            TextButton(onPressed: onRetry, child: const Text('다시 시도')),
          ],
        ),
      ),
    );
  }
}

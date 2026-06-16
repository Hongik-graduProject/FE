// lib/screens/folder/folder_detail_screen.dart — W-05 폴더 상세 + 종목 CRUD
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  Future<void> _openItemActions(FolderItem item) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('메모·평단가 수정'),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_move_outline),
              title: const Text('다른 폴더로 이동'),
              onTap: () => Navigator.pop(context, 'move'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline,
                  color: Color(0xFFEF4444)),
              title: const Text('관심에서 삭제',
                  style: TextStyle(color: Color(0xFFEF4444))),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || action == null) return;

    switch (action) {
      case 'edit':
        await _openEditMemo(item);
        break;
      case 'move':
        await _openMove(item);
        break;
      case 'delete':
        await _confirmDelete(item);
        break;
    }
  }

  Future<void> _openEditMemo(FolderItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _MemoEditDialog(item: item),
    );
    if (ok == true) _reload();
  }

  Future<void> _openMove(FolderItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _MoveDialog(item: item, currentFolderId: _args.id),
    );
    if (ok == true) _reload();
  }

  Future<void> _confirmDelete(FolderItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('"${item.name}" 삭제'),
        content: const Text('이 폴더에서 종목을 제거합니다.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444)),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ApiService().deleteFavorite(item.id);
      messenger
          .showSnackBar(const SnackBar(content: Text('관심에서 삭제되었습니다')));
      _reload();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(_initialized ? _args.name : ''),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.pushNamed(context, '/search');
          // 검색 화면에서 돌아오면 새로 추가된 종목 반영 위해 reload
          if (mounted) _reload();
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('종목 추가'),
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
                  onLongPress: () => _openItemActions(items[index]),
                  onMore: () => _openItemActions(items[index]),
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
  final VoidCallback onLongPress;
  final VoidCallback onMore;

  const _CompanyCard({
    required this.item,
    required this.onTap,
    required this.onLongPress,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final rate = item.changeRate;
    final isUp = (rate ?? 0) >= 0;
    final priceColor =
        isUp ? const Color(0xFFE53935) : const Color(0xFF1976D2);
    final priceIcon = isUp ? '▲' : '▼';
    final priceStr =
        item.currentPrice != null ? '₩${_formatPrice(item.currentPrice!)}' : '-';
    final changeStr =
        rate != null ? '$priceIcon ${rate.abs().toStringAsFixed(2)}%' : '-';
    final hasUnread = item.unreadDisclosureCount > 0;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
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
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                        overflow: TextOverflow.ellipsis,
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    priceStr,
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
              IconButton(
                icon: const Icon(Icons.more_vert_rounded,
                    size: 18, color: Color(0xFF9CA3AF)),
                tooltip: '종목 옵션',
                onPressed: onMore,
                splashRadius: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                    minWidth: 28, minHeight: 28),
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

// ─── Memo Edit Dialog ────────────────────────────────────────────────────────

class _MemoEditDialog extends StatefulWidget {
  final FolderItem item;
  const _MemoEditDialog({required this.item});

  @override
  State<_MemoEditDialog> createState() => _MemoEditDialogState();
}

class _MemoEditDialogState extends State<_MemoEditDialog> {
  // FolderItem에 memo/avgPrice는 없으므로 초기값은 비워둔다.
  // (BE GET /folders/{id}/items 응답에는 memo·avg_price가 없는 상태)
  late final TextEditingController _memo = TextEditingController();
  late final TextEditingController _avgPrice = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _memo.dispose();
    _avgPrice.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final memoText = _memo.text.trim();
    final priceText = _avgPrice.text.replaceAll(',', '').trim();
    int? avgPrice;
    if (priceText.isNotEmpty) {
      avgPrice = int.tryParse(priceText);
      if (avgPrice == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('평단가는 숫자만 입력해주세요')),
        );
        return;
      }
    }
    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ApiService().updateFavorite(
        widget.item.id,
        FavoriteUpdateRequest(
          memo: memoText.isEmpty ? null : memoText,
          avgPrice: avgPrice,
        ),
      );
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
      title: Text('${widget.item.name} 메모'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _memo,
              maxLength: 100,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '메모',
                hintText: '예: 다음 분기 실적 기대',
                counterText: '',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _avgPrice,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: '평단가 (원)',
                hintText: '예: 75000',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context, false),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('저장'),
        ),
      ],
    );
  }
}

// ─── Move Dialog ──────────────────────────────────────────────────────────────

class _MoveDialog extends StatefulWidget {
  final FolderItem item;
  final int currentFolderId;

  const _MoveDialog({required this.item, required this.currentFolderId});

  @override
  State<_MoveDialog> createState() => _MoveDialogState();
}

class _MoveDialogState extends State<_MoveDialog> {
  late Future<FoldersResponse> _foldersFuture;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _foldersFuture = ApiService().getFolders();
  }

  Future<void> _select(Folder target) async {
    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ApiService()
          .moveFavorite(widget.item.id, target.id);
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
      title: Text('"${widget.item.name}" 이동'),
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
            final targets = snapshot.data!.folders
                .where((f) => f.id != widget.currentFolderId)
                .toList();
            if (targets.isEmpty) {
              return const Center(child: Text('이동 가능한 다른 폴더가 없습니다'));
            }
            return ListView.separated(
              itemCount: targets.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final f = targets[i];
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

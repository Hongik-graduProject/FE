// lib/widgets/favorite_actions.dart
// 관심종목 한 줄(홈·폴더 상세 공용)과 그 동작: 메모·평단가 수정 / 다른 폴더로 이동 / 관심에서 삭제.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/folder_model.dart';
import '../services/api_service.dart';
import '../utils/design_tokens.dart';
import '../utils/format.dart';
import 'ds.dart';

/// 동작 시트를 열고, 무엇이든 바뀌었으면 true 를 돌려준다.
/// withEdit=false 는 스와이프용 (이동·삭제만).
Future<bool> showFavoriteActions(BuildContext context, FolderItem item,
    {required int folderId, bool withEdit = true}) async {
  final action = await showDsSheet<String>(
    context,
    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.sm),
        child: Text(item.name, style: AppText.headlineMd),
      ),
      if (withEdit) _sheetTile(context, Icons.edit_outlined, '메모·평단가 수정', 'edit'),
      _sheetTile(context, Icons.drive_file_move_outline, '다른 폴더로 이동', 'move'),
      _sheetTile(context, Icons.delete_outline, '관심에서 삭제', 'delete', color: AppColors.error),
    ]),
  );
  if (!context.mounted || action == null) return false;
  switch (action) {
    case 'edit':
      return await showDialog<bool>(context: context, builder: (_) => _MemoEditDialog(item: item)) == true;
    case 'move':
      return await showDialog<bool>(
              context: context, builder: (_) => _MoveDialog(itemId: item.id, name: item.name, currentFolderId: folderId)) ==
          true;
    case 'delete':
      return _confirmDelete(context, item);
  }
  return false;
}

Widget _sheetTile(BuildContext context, IconData icon, String label, String value, {Color? color}) {
  final c = color ?? AppColors.textPrimary;
  return ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: c),
    title: Text(label, style: AppText.bodyLg.copyWith(color: c)),
    onTap: () => Navigator.pop(context, value),
  );
}

Future<bool> _confirmDelete(BuildContext context, FolderItem item) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('"${item.name}" 삭제'),
      content: const Text('이 폴더에서 종목을 제거합니다.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          child: const Text('삭제'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return false;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ApiService().deleteFavorite(item.id);
    messenger.showSnackBar(const SnackBar(content: Text('관심에서 삭제했어요')));
    return true;
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    return false;
  }
}

/// 관심종목 한 줄. 탭=종목 상세, 길게 누르기=동작 시트, 왼쪽으로 밀기=이동·삭제.
/// 오른쪽 칩은 최신 공시의 예상 CAR (없으면 "분석 없음").
class FavoriteStockRow extends StatelessWidget {
  final FolderItem item;
  final int folderId;
  final VoidCallback onTap;
  final VoidCallback onChanged;

  const FavoriteStockRow(
      {super.key, required this.item, required this.folderId, required this.onTap, required this.onChanged});

  Future<void> _actions(BuildContext context, {bool withEdit = true}) async {
    if (await showFavoriteActions(context, item, folderId: folderId, withEdit: withEdit)) onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final summary = item.analysisSummary;
    final car = summary != null && summary.hasTheme ? summary.expectedCar : null;
    return Dismissible(
      key: ValueKey('fav-$folderId-${item.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
        color: AppColors.subtle,
        child: Text('폴더 이동 · 삭제', style: AppText.labelLg.copyWith(color: AppColors.textSecondary)),
      ),
      // 밀어도 줄을 지우지 않고 시트로 고르게 한다. 실제 삭제는 서버 응답 뒤 목록을 다시 불러와 반영.
      confirmDismiss: (_) async {
        await _actions(context, withEdit: false);
        return false;
      },
      child: InkWell(
        onTap: onTap,
        onLongPress: () => _actions(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: 14),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(
                    child: Text(item.name,
                        style: AppText.labelLg, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  if (item.unreadDisclosureCount > 0) ...[
                    const SizedBox(width: 6),
                    DsPill('${item.unreadDisclosureCount}',
                        height: 18, background: AppColors.bull, foreground: Colors.white),
                  ],
                ]),
                const SizedBox(height: 2),
                Text(
                  item.memo == null || item.memo!.isEmpty ? item.ticker : '${item.ticker} · ${item.memo}',
                  style: AppText.labelSm,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ]),
            ),
            const SizedBox(width: AppSpace.sm),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(won(item.currentPrice), style: AppText.labelLg.merge(AppText.numeric)),
              const SizedBox(height: 2),
              PriceChange(amount: item.changeAmount, rate: item.changeRate, style: AppText.labelSm),
            ]),
            const SizedBox(width: AppSpace.sm + 4),
            SizedBox(
              width: 78,
              child: Align(
                alignment: Alignment.centerRight,
                child: car == null
                    ? const DsPill('분석 없음', background: AppColors.subtle, foreground: AppColors.textTertiary)
                    : CarBadge(car, withLabel: false),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─── 메모·평단가 ─────────────────────────────────────────────────────────────

class _MemoEditDialog extends StatefulWidget {
  final FolderItem item;
  const _MemoEditDialog({required this.item});

  @override
  State<_MemoEditDialog> createState() => _MemoEditDialogState();
}

class _MemoEditDialogState extends State<_MemoEditDialog> {
  late final TextEditingController _memo = TextEditingController(text: widget.item.memo ?? '');
  late final TextEditingController _avgPrice =
      TextEditingController(text: widget.item.avgPrice?.toString() ?? '');
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
          // 서버는 null 을 "변경 없음" 으로 본다. 빈 문자열을 보내야 메모가 지워진다.
          memo: memoText,
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
            const SizedBox(height: AppSpace.sm + 4),
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
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('저장'),
        ),
      ],
    );
  }
}

// ─── 폴더 이동 ───────────────────────────────────────────────────────────────

/// 관심 항목을 다른 폴더로 옮긴다. 옮겼으면 true.
Future<bool> showMoveFavoriteDialog(BuildContext context,
    {required int itemId, required String name, required int currentFolderId}) async {
  return await showDialog<bool>(
          context: context,
          builder: (_) => _MoveDialog(itemId: itemId, name: name, currentFolderId: currentFolderId)) ==
      true;
}

class _MoveDialog extends StatefulWidget {
  final int itemId;
  final String name;
  final int currentFolderId;

  const _MoveDialog({required this.itemId, required this.name, required this.currentFolderId});

  @override
  State<_MoveDialog> createState() => _MoveDialogState();
}

class _MoveDialogState extends State<_MoveDialog> {
  late final Future<FoldersResponse> _foldersFuture = ApiService().getFolders();
  bool _submitting = false;

  Future<void> _select(Folder target) async {
    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ApiService().moveFavorite(widget.itemId, target.id);
      messenger.showSnackBar(SnackBar(content: Text('"${target.name}" 폴더로 옮겼어요')));
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
      title: Text('"${widget.name}" 이동'),
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
            final targets = snapshot.data!.folders.where((f) => f.id != widget.currentFolderId).toList();
            if (targets.isEmpty) {
              return const Center(child: Text('이동할 수 있는 다른 폴더가 없어요'));
            }
            return ListView.separated(
              itemCount: targets.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final f = targets[i];
                return ListTile(
                  leading: Icon(Icons.folder_rounded, color: _hexToColor(f.color)),
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

Color _hexToColor(String hex) =>
    Color(int.tryParse('FF${hex.replaceFirst('#', '')}', radix: 16) ?? 0xFF8B95A1);

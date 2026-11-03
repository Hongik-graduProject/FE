// lib/screens/folder/folder_manage_screen.dart — 내 폴더 관리 (Stitch _10)
import 'package:flutter/material.dart';

import '../../models/folder_model.dart';
import '../../services/api_service.dart';
import '../../utils/design_tokens.dart';
import '../../widgets/ds.dart';

class FolderManageScreen extends StatefulWidget {
  const FolderManageScreen({super.key});

  @override
  State<FolderManageScreen> createState() => _FolderManageScreenState();
}

class _FolderManageScreenState extends State<FolderManageScreen> {
  List<Folder>? _folders;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiService().getFolders();
      if (!mounted) return;
      setState(() {
        _folders = res.folders;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  Future<void> _openEditor([Folder? folder]) async {
    final saved = await showDsSheet<bool>(context, child: _FolderEditSheet(folder: folder));
    if (saved == true) _load();
  }

  Future<void> _confirmDelete(Folder folder) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('"${folder.name}" 삭제'),
        content: Text('폴더와 폴더 내 관심 종목 ${folder.itemCount}개가 모두 삭제됩니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.bull),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ApiService().deleteFolder(folder.id);
      messenger.showSnackBar(const SnackBar(content: Text('폴더가 삭제되었습니다')));
      _load();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    final list = [..._folders!];
    list.insert(newIndex, list.removeAt(oldIndex));
    setState(() => _folders = list);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ApiService().reorderFolders(list.map((f) => f.id).toList());
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
      _load(); // 실패하면 서버 순서로 되돌린다.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('내 폴더 관리'),
        actions: [
          TextButton.icon(
            onPressed: () => _openEditor(),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('새 폴더'),
          ),
          const SizedBox(width: AppSpace.sm),
        ],
      ),
      body: RefreshIndicator(onRefresh: _load, child: _body()),
    );
  }

  Widget _body() {
    const side = EdgeInsets.symmetric(horizontal: AppSpace.lg);
    final folders = _folders;
    if (folders == null) {
      return ListView(padding: const EdgeInsets.all(AppSpace.lg), children: [
        if (_error != null)
          ErrorRetry(message: _error.toString(), onRetry: _load)
        else
          const SkeletonList(count: 3, itemHeight: 80),
      ]);
    }
    final totalUnread = folders.fold<int>(0, (s, f) => s + f.unreadDisclosureCount);

    return CustomScrollView(slivers: [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.xl),
        sliver: SliverToBoxAdapter(
          child: DsCard(
            color: AppColors.subtle,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(color: AppColors.accentTint, shape: BoxShape.circle),
                child: const Icon(Icons.folder_special_outlined, color: AppColors.accent, size: 20),
              ),
              const SizedBox(width: AppSpace.sm + 4),
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('관심종목을 테마나 투자 목적에 맞게 분류해보세요.', style: AppText.bodyMd),
                  SizedBox(height: AppSpace.xs),
                  Text('오른쪽 핸들(≡)을 끌어 순서를 바꿀 수 있어요.', style: AppText.labelSm),
                ]),
              ),
            ]),
          ),
        ),
      ),
      SliverPadding(
        padding: side,
        sliver: SliverToBoxAdapter(
          child: SectionTitle(
            '내 폴더 리스트 ${folders.length}개',
            trailing: totalUnread > 0
                ? Row(mainAxisSize: MainAxisSize.min, children: [
                    const UnreadDot(),
                    const SizedBox(width: 4),
                    Text('미확인 공시 $totalUnread건', style: AppText.labelSm),
                  ])
                : null,
          ),
        ),
      ),
      if (folders.isEmpty)
        const SliverToBoxAdapter(
          child: EmptyState(icon: Icons.folder_open_rounded, title: '폴더가 없어요'),
        )
      else
        SliverPadding(
          padding: side,
          sliver: SliverReorderableList(
            itemCount: folders.length,
            onReorderItem: _reorder,
            itemBuilder: (context, i) => Padding(
              key: ValueKey(folders[i].id),
              padding: const EdgeInsets.only(bottom: AppSpace.sm + 4),
              child: _FolderRow(
                folder: folders[i],
                index: i,
                onEdit: () => _openEditor(folders[i]),
                onDelete: () => _confirmDelete(folders[i]),
              ),
            ),
          ),
        ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.xs, AppSpace.lg, AppSpace.xl),
        sliver: SliverToBoxAdapter(
          child: Column(children: [
            DsCard(
              onTap: () => _openEditor(),
              child: Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(color: AppColors.accentTint, shape: BoxShape.circle),
                  child: const Icon(Icons.create_new_folder_outlined, color: AppColors.accent, size: 20),
                ),
                const SizedBox(width: AppSpace.sm + 4),
                const Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('새 폴더 만들기', style: AppText.labelLg),
                    SizedBox(height: 2),
                    Text('테마나 포트폴리오별로 구성', style: AppText.labelSm),
                  ]),
                ),
                const Icon(Icons.add_circle_outline_rounded, color: AppColors.textTertiary),
              ]),
            ),
            const SizedBox(height: AppSpace.lg),
            const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.info_outline_rounded, size: 14, color: AppColors.textTertiary),
              SizedBox(width: 4),
              Text('기본 폴더는 삭제하거나 이름을 변경할 수 없습니다.', style: AppText.labelSm),
            ]),
          ]),
        ),
      ),
    ]);
  }
}

// ─── Folder Row ───────────────────────────────────────────────────────────────

class _FolderRow extends StatelessWidget {
  final Folder folder;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _FolderRow({required this.folder, required this.index, required this.onEdit, required this.onDelete});

  bool get _isDefault => folder.type.toLowerCase() == 'default';

  @override
  Widget build(BuildContext context) {
    return DsCard(
      padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.md, AppSpace.xs, AppSpace.md),
      onTap: () => Navigator.pushNamed(
        context,
        '/folder',
        arguments: FolderArgs(id: folder.id, name: folder.name, color: folder.color),
      ),
      child: Row(children: [
        _isDefault
            ? const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.textTertiary)
            : Container(
                width: 14,
                height: 14,
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(color: _hexToColor(folder.color), shape: BoxShape.circle),
              ),
        const SizedBox(width: AppSpace.sm + 4),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(folder.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.headlineSm),
              ),
              if (_isDefault) ...[
                const SizedBox(width: 6),
                const DsPill('기본', height: 20, background: AppColors.subtle, foreground: AppColors.textTertiary),
              ],
            ]),
            const SizedBox(height: 4),
            Text.rich(TextSpan(style: AppText.bodySm, children: [
              TextSpan(text: '종목 ${folder.itemCount}개 · '),
              TextSpan(
                text: '미확인 공시 ${folder.unreadDisclosureCount}건',
                style: folder.unreadDisclosureCount > 0
                    ? const TextStyle(color: AppColors.bull, fontWeight: FontWeight.w600)
                    : null,
              ),
            ])),
          ]),
        ),
        if (!_isDefault)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppColors.textTertiary),
            tooltip: '폴더 옵션',
            onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('이름·색상 수정')),
              PopupMenuItem(value: 'delete', child: Text('삭제', style: TextStyle(color: AppColors.bull))),
            ],
          ),
        ReorderableDragStartListener(
          index: index,
          child: const Padding(
            padding: EdgeInsets.all(AppSpace.sm + 4),
            child: Icon(Icons.drag_handle_rounded, color: AppColors.textDisabled),
          ),
        ),
      ]),
    );
  }
}

// ─── Create / Edit Sheet ──────────────────────────────────────────────────────

class _FolderEditSheet extends StatefulWidget {
  final Folder? folder;
  const _FolderEditSheet({this.folder});

  @override
  State<_FolderEditSheet> createState() => _FolderEditSheetState();
}

class _FolderEditSheetState extends State<_FolderEditSheet> {
  static const _palette = [
    '#1A237E', '#3D5AFE', '#4A90D9', '#0EA5E9', '#14B8A6', '#34A853',
    '#FBBC04', '#FF7043', '#EA4335', '#F472B6', '#9333EA', '#64748B',
  ];

  late final TextEditingController _name;
  late String _color;
  bool _submitting = false;

  bool get _isEdit => widget.folder != null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.folder?.name ?? '');
    _color = widget.folder?.color.toUpperCase() ?? _palette.first;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    if (name.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('폴더 이름을 입력해주세요')));
      return;
    }
    setState(() => _submitting = true);
    final navigator = Navigator.of(context);
    try {
      if (_isEdit) {
        await ApiService().updateFolder(widget.folder!.id, FolderUpdateRequest(name: name, color: _color));
      } else {
        await ApiService().createFolder(FolderCreateRequest(name: name, color: _color));
      }
      navigator.pop(true);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(_isEdit ? '폴더 수정' : '새 폴더 만들기', style: AppText.headlineMd),
      const SizedBox(height: AppSpace.md),
      TextField(
        controller: _name,
        maxLength: 30,
        autofocus: !_isEdit,
        decoration: const InputDecoration(labelText: '폴더 이름', hintText: '예: 반도체'),
      ),
      const SizedBox(height: AppSpace.sm),
      const Text('색상', style: AppText.labelMd),
      const SizedBox(height: AppSpace.sm),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final hex in _palette)
            Semantics(
              button: true,
              selected: _color == hex,
              label: '색상 $hex',
              child: GestureDetector(
                onTap: () => setState(() => _color = hex),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _hexToColor(hex),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: _color == hex ? AppColors.textPrimary : Colors.transparent, width: 3),
                  ),
                  child: _color == hex ? const Icon(Icons.check_rounded, size: 18, color: Colors.white) : null,
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: AppSpace.xl),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(_isEdit ? '저장' : '만들기'),
        ),
      ),
    ]);
  }
}

Color _hexToColor(String hex) {
  final h = hex.replaceFirst('#', '');
  return Color(int.parse('FF$h', radix: 16));
}

// lib/screens/home_screen.dart — W-04 폴더 목록 + W-06 폴더 CRUD
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/folder_model.dart';
import '../services/api_service.dart';
import '../services/auth_provider.dart';
import '../utils/constants.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<FoldersResponse> _foldersFuture;
  bool _reorderMode = false;

  @override
  void initState() {
    super.initState();
    _foldersFuture = ApiService().getFolders();
  }

  void _reload() {
    setState(() {
      _foldersFuture = ApiService().getFolders();
    });
  }

  void _toggleReorderMode() {
    setState(() => _reorderMode = !_reorderMode);
  }

  Future<void> _openCreateFolderDialog() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => const _FolderEditDialog(),
    );
    if (created == true) _reload();
  }

  Future<void> _openEditFolderDialog(Folder folder) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => _FolderEditDialog(folder: folder),
    );
    if (updated == true) _reload();
  }

  Future<void> _confirmDeleteFolder(Folder folder) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('"${folder.name}" 삭제'),
        content: Text('폴더와 폴더 내 관심 종목 ${folder.itemCount}개가 모두 삭제됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ApiService().deleteFolder(folder.id);
      messenger.showSnackBar(const SnackBar(content: Text('폴더가 삭제되었습니다')));
      _reload();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _reorderFolders(List<Folder> reordered) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ApiService().reorderFolders(reordered.map((f) => f.id).toList());
      _reload();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      backgroundColor: const Color(AppConstants.backgroundColor),
      appBar: AppBar(
        title: const Text('마이페이지'),
        actions: [
          IconButton(
            tooltip: '종목 검색',
            icon: const Icon(Icons.search_rounded),
            onPressed: () => Navigator.pushNamed(context, '/search'),
          ),
          IconButton(
            tooltip: '알림',
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => Navigator.pushNamed(context, '/notifications'),
          ),
          IconButton(
            tooltip: _reorderMode ? '순서변경 완료' : '폴더 순서 변경',
            icon: Icon(_reorderMode ? Icons.check_rounded : Icons.swap_vert_rounded),
            onPressed: _toggleReorderMode,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => _reload(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _WelcomeCard(nickname: user?.nickname ?? '투자자'),
                const SizedBox(height: 24),
                FutureBuilder<FoldersResponse>(
                  future: _foldersFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.hasError) {
                      return _FolderError(
                        message: snapshot.error.toString(),
                        onRetry: _reload,
                      );
                    }
                    return _FolderSection(
                      response: snapshot.data!,
                      reorderMode: _reorderMode,
                      onCreate: _openCreateFolderDialog,
                      onEdit: _openEditFolderDialog,
                      onDelete: _confirmDeleteFolder,
                      onReorder: _reorderFolders,
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Welcome Card ─────────────────────────────────────────────────────────────

class _WelcomeCard extends StatelessWidget {
  final String nickname;
  const _WelcomeCard({required this.nickname});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(AppConstants.primaryColor),
            Color(AppConstants.primaryDarkColor),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '안녕하세요, $nickname님 👋',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '오늘도 현명한 투자 하세요',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Folder Section ───────────────────────────────────────────────────────────

class _FolderSection extends StatelessWidget {
  final FoldersResponse response;
  final bool reorderMode;
  final VoidCallback onCreate;
  final ValueChanged<Folder> onEdit;
  final ValueChanged<Folder> onDelete;
  final ValueChanged<List<Folder>> onReorder;

  const _FolderSection({
    required this.response,
    required this.reorderMode,
    required this.onCreate,
    required this.onEdit,
    required this.onDelete,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '내 폴더',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(AppConstants.textPrimary),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${response.folders.length}개',
              style: const TextStyle(
                fontSize: 13,
                color: Color(AppConstants.textSecondary),
              ),
            ),
            if (reorderMode) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(AppConstants.primaryColor),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  '순서 변경 모드',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        if (reorderMode)
          _ReorderList(folders: response.folders, onReorder: onReorder)
        else
          ...response.folders.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _FolderCard(
                folder: f,
                onEdit: () => onEdit(f),
                onDelete: () => onDelete(f),
              ),
            ),
          ),
        if (!reorderMode) ...[
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('새 폴더'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(AppConstants.primaryColor),
                side: const BorderSide(color: Color(AppConstants.primaryColor)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Reorder List ─────────────────────────────────────────────────────────────

class _ReorderList extends StatefulWidget {
  final List<Folder> folders;
  final ValueChanged<List<Folder>> onReorder;
  const _ReorderList({required this.folders, required this.onReorder});

  @override
  State<_ReorderList> createState() => _ReorderListState();
}

class _ReorderListState extends State<_ReorderList> {
  late List<Folder> _items;

  @override
  void initState() {
    super.initState();
    _items = [...widget.folders];
  }

  @override
  Widget build(BuildContext context) {
    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      // ignore: deprecated_member_use
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) newIndex -= 1;
          final f = _items.removeAt(oldIndex);
          _items.insert(newIndex, f);
        });
        widget.onReorder(_items);
      },
      children: [
        for (int i = 0; i < _items.length; i++)
          Padding(
            key: ValueKey(_items[i].id),
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(child: _FolderCard.compact(folder: _items[i])),
                ReorderableDragStartListener(
                  index: i,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.drag_handle_rounded,
                        color: Color(0xFF9CA3AF)),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ─── Folder Card ──────────────────────────────────────────────────────────────

class _FolderCard extends StatelessWidget {
  final Folder folder;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool compactMode;

  const _FolderCard({
    required this.folder,
    this.onEdit,
    this.onDelete,
  }) : compactMode = false;

  const _FolderCard.compact({required this.folder})
      : onEdit = null,
        onDelete = null,
        compactMode = true;

  bool get _isDefault => folder.type.toLowerCase() == 'default';

  @override
  Widget build(BuildContext context) {
    final color = _hexToColor(folder.color);
    final hasUnread = folder.unreadDisclosureCount > 0;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: compactMode
            ? null
            : () => Navigator.pushNamed(
                  context,
                  '/folder',
                  arguments: FolderArgs(
                    id: folder.id,
                    name: folder.name,
                    color: folder.color,
                  ),
                ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x06000000),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Text('📁', style: TextStyle(fontSize: 20)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            folder.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(AppConstants.textPrimary),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_isDefault) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8EAF6),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '기본',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A237E),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '종목 ${folder.itemCount}개  ·  미확인 공시 ${folder.unreadDisclosureCount}개',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(AppConstants.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              if (compactMode)
                const SizedBox.shrink()
              else if (!_isDefault)
                _FolderMoreButton(onEdit: onEdit!, onDelete: onDelete!)
              else if (hasUnread)
                _UnreadBadge(count: folder.unreadDisclosureCount)
              else
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: Color(0xFFD1D5DB),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  final int count;
  const _UnreadBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FolderMoreButton extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _FolderMoreButton({required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded,
          size: 20, color: Color(0xFF6B7280)),
      tooltip: '폴더 옵션',
      onSelected: (v) {
        if (v == 'edit') onEdit();
        if (v == 'delete') onDelete();
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'edit', child: Text('이름·색상 수정')),
        PopupMenuItem(
          value: 'delete',
          child: Text('삭제', style: TextStyle(color: Color(0xFFEF4444))),
        ),
      ],
    );
  }
}

// ─── Edit Dialog (Create + Update 공용) ───────────────────────────────────────

class _FolderEditDialog extends StatefulWidget {
  final Folder? folder;
  const _FolderEditDialog({this.folder});

  @override
  State<_FolderEditDialog> createState() => _FolderEditDialogState();
}

class _FolderEditDialogState extends State<_FolderEditDialog> {
  static const _palette = [
    '#4A90D9', '#34A853', '#EA4335', '#FBBC04',
    '#9333EA', '#0EA5E9', '#F472B6', '#64748B',
  ];

  late final TextEditingController _name;
  late String _color;
  bool _submitting = false;

  bool get _isEdit => widget.folder != null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.folder?.name ?? '');
    _color = widget.folder?.color ?? _palette.first;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('폴더 이름을 입력해주세요')),
      );
      return;
    }
    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      if (_isEdit) {
        await ApiService().updateFolder(
          widget.folder!.id,
          FolderUpdateRequest(name: name, color: _color),
        );
      } else {
        await ApiService().createFolder(
          FolderCreateRequest(name: name, color: _color),
        );
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
    return AlertDialog(
      title: Text(_isEdit ? '폴더 수정' : '새 폴더'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              maxLength: 30,
              decoration: const InputDecoration(
                labelText: '폴더 이름',
                hintText: '예: 반도체',
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            const Text('색상',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(AppConstants.textSecondary))),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _palette
                  .map((hex) => GestureDetector(
                        onTap: () => setState(() => _color = hex),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: _hexToColor(hex),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _color == hex
                                  ? const Color(AppConstants.textPrimary)
                                  : Colors.transparent,
                              width: 3,
                            ),
                          ),
                        ),
                      ))
                  .toList(),
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
              : Text(_isEdit ? '저장' : '생성'),
        ),
      ],
    );
  }
}

// ─── Folder Error ─────────────────────────────────────────────────────────────

class _FolderError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _FolderError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 40, color: Color(0xFF9CA3AF)),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('다시 시도')),
          ],
        ),
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

Color _hexToColor(String hex) {
  final h = hex.replaceFirst('#', '');
  return Color(int.parse('FF$h', radix: 16));
}

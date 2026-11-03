import 'package:flutter/material.dart';

import '../models/folder_model.dart';
import '../services/api_service.dart';

/// 관심종목을 넣을 폴더를 고르는 창. 추가에 성공하면 true 로 닫힌다.
/// 검색 결과의 🔖 와 종목 상세의 ♥ 가 같이 쓴다.
class FavoritePickerDialog extends StatefulWidget {
  final String ticker;
  final String name;
  const FavoritePickerDialog(
      {super.key, required this.ticker, required this.name});

  @override
  State<FavoritePickerDialog> createState() => _FavoritePickerDialogState();
}

class _FavoritePickerDialogState extends State<FavoritePickerDialog> {
  late Future<FoldersResponse> _foldersFuture;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _foldersFuture = ApiService().getFolders();
  }

  Future<void> _select(Folder folder) async {
    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ApiService().addFavorite(folder.id, widget.ticker);
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
      title: Text('"${widget.name}" 추가'),
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
            final folders = snapshot.data!.folders;
            if (folders.isEmpty) {
              return const Center(child: Text('폴더가 없습니다. 먼저 폴더를 만들어주세요.'));
            }
            return ListView.separated(
              itemCount: folders.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final f = folders[i];
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
  // 잘못된 색 값이 와도 화면을 그리다 멈추지 않게 회색으로 대신한다.
  return Color(int.tryParse('FF$h', radix: 16) ?? 0xFF8B95A1);
}

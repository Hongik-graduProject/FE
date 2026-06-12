// lib/screens/home_screen.dart — W-04 폴더 목록 홈
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

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      backgroundColor: const Color(AppConstants.backgroundColor),
      appBar: AppBar(
        title: const Text('마이페이지'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
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
                    return _FolderSection(response: snapshot.data!);
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
  const _FolderSection({required this.response});

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
          ],
        ),
        const SizedBox(height: 10),
        ...response.folders.map(
          (f) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _FolderCard(folder: f),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              // TODO: W-06 폴더 생성 모달
            },
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
    );
  }
}

// ─── Folder Card ──────────────────────────────────────────────────────────────

class _FolderCard extends StatelessWidget {
  final Folder folder;
  const _FolderCard({required this.folder});

  @override
  Widget build(BuildContext context) {
    final color = _hexToColor(folder.color);
    final hasUnread = folder.unreadDisclosureCount > 0;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.pushNamed(
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
                    Text(
                      folder.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(AppConstants.textPrimary),
                      ),
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
              if (hasUnread)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${folder.unreadDisclosureCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
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

// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';
import '../widgets/common_widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        children: [
          // 내 정보
          const _SectionHeader(title: '내 정보'),
          _InfoTile(
            icon: Icons.person_outline_rounded,
            label: user?.nickname ?? '닉네임',
            sub: user?.email ?? '',
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),

          // 알림 / 앱 설정 (stub)
          const _SectionHeader(title: '앱'),
          _NavTile(
            icon: Icons.notifications_outlined,
            label: '알림 설정',
            onTap: () {},
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _NavTile(
            icon: Icons.tune_rounded,
            label: '앱 설정',
            onTap: () {},
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),

          const SizedBox(height: 24),
          const Divider(thickness: 8, color: Color(0xFFF3F4F6)),

          // 계정
          const _SectionHeader(title: '계정'),
          _NavTile(
            icon: Icons.logout_rounded,
            label: '로그아웃',
            onTap: () async {
              final confirm = await showConfirmDialog(
                context,
                title: '로그아웃',
                content: '정말 로그아웃 하시겠습니까?',
                confirmText: '로그아웃',
              );
              if (confirm == true && context.mounted) {
                await context.read<AuthProvider>().logout();
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, '/login');
                }
              }
            },
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _NavTile(
            icon: Icons.person_remove_outlined,
            label: '회원 탈퇴',
            textColor: const Color(0xFFDC2626),
            iconColor: const Color(0xFFDC2626),
            onTap: () =>
                Navigator.pushNamed(context, '/delete-account'),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),

          const SizedBox(height: 40),
          const Center(
            child: Text(
              '공시레이더 v1.0.0',
              style: TextStyle(
                  fontSize: 12, color: Color(0xFF9CA3AF)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─── Widgets ──────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF6B7280),
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;

  const _InfoTile(
      {required this.icon, required this.label, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 22, color: const Color(0xFF6B7280)),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827))),
              if (sub.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(sub,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF9CA3AF))),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? textColor;
  final Color? iconColor;

  const _NavTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.textColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final fg = textColor ?? const Color(0xFF111827);
    final ig = iconColor ?? const Color(0xFF6B7280);

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 22, color: ig),
              const SizedBox(width: 14),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: fg)),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: Color(0xFFD1D5DB)),
            ],
          ),
        ),
      ),
    );
  }
}

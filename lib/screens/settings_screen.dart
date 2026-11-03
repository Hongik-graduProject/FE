// lib/screens/settings_screen.dart — MY 탭 (Stitch my)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/folder_model.dart';
import '../services/api_service.dart';
import '../services/auth_provider.dart';
import '../utils/design_tokens.dart';
import '../widgets/common_widgets.dart';
import '../widgets/ds.dart';
import 'main_shell.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _tabIndex = 3; // MainShell 의 MY 탭 위치

  List<Folder>? _folders;
  int? _unreadReports;
  int? _lastTab;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // IndexedStack 이라 화면이 살아 있으므로, MY 탭으로 돌아올 때마다 통계를 새로 불러온다.
    final tab = MainShellScope.maybeOf(context)?.currentIndex;
    if (tab == _tabIndex && _lastTab != null && _lastTab != _tabIndex) _load();
    _lastTab = tab;
  }

  // 통계는 부가 정보라 실패하면 "—" 로 둔다.
  Future<void> _load() async {
    final api = ApiService();
    await Future.wait([
      api.getFolders().then((r) {
        if (mounted) setState(() => _folders = r.folders);
      }).catchError((_) {}),
      api.getNotifications(size: 1).then((r) {
        if (mounted) setState(() => _unreadReports = r.unreadCount);
      }).catchError((_) {}),
    ]);
  }

  Future<void> _logout() async {
    final confirm = await showConfirmDialog(
      context,
      title: '로그아웃',
      content: '정말 로그아웃 하시겠습니까?',
      confirmText: '로그아웃',
    );
    if (confirm == true && mounted) {
      await context.read<AuthProvider>().logout();
      if (mounted) {
        // 홈이 아래에 남아 있으면 뒤로 가기로 로그인 없이 돌아갈 수 있다.
        Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final folders = _folders;
    final stockCount = folders?.fold<int>(0, (sum, f) => sum + f.itemCount);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(automaticallyImplyLeading: false, title: const Text('MY')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, 0),
          children: [
            DsCard(
              child: Column(children: [
                Row(children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(color: AppColors.accentTint, shape: BoxShape.circle),
                    child: const Icon(Icons.radar_rounded, color: AppColors.accent, size: 28),
                  ),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(user?.nickname ?? '닉네임', style: AppText.headlineMd),
                      if ((user?.email ?? '').isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(user!.email, style: AppText.bodySm.copyWith(color: AppColors.textTertiary)),
                      ],
                    ]),
                  ),
                ]),
                const SizedBox(height: AppSpace.md),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
                  decoration: BoxDecoration(
                      color: AppColors.subtle, borderRadius: BorderRadius.circular(AppRadius.md)),
                  child: Row(children: [
                    _Stat(label: '관심종목', value: stockCount, unit: '개'),
                    const _StatDivider(),
                    _Stat(label: '보유 폴더', value: folders?.length, unit: '개'),
                    const _StatDivider(),
                    _Stat(label: '미확인 보고서', value: _unreadReports, unit: '건'),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: AppSpace.xl),
            const _GroupLabel('관심 및 분석 관리'),
            _MenuCard(children: [
              _MenuTile(
                icon: Icons.folder_outlined,
                label: '내 폴더 관리',
                trailing: folders == null
                    ? null
                    : DsPill('${folders.length}개',
                        height: 22, background: AppColors.subtle, foreground: AppColors.textSecondary),
                onTap: () async {
                  await Navigator.pushNamed(context, '/folders');
                  _load();
                },
              ),
            ]),
            const SizedBox(height: AppSpace.xl),
            const _GroupLabel('앱 정보'),
            _MenuCard(children: [
              _MenuTile(
                icon: Icons.info_outline_rounded,
                label: '앱 버전',
                trailing: Text('v1.0.0', style: AppText.bodySm.copyWith(color: AppColors.textTertiary)),
              ),
            ]),
            const SizedBox(height: AppSpace.xl),
            _MenuCard(children: [
              _MenuTile(icon: Icons.logout_rounded, label: '로그아웃', onTap: _logout, showChevron: false),
              _MenuTile(
                icon: Icons.person_remove_outlined,
                label: '회원 탈퇴',
                color: AppColors.bull,
                onTap: () => Navigator.pushNamed(context, '/delete-account'),
              ),
            ]),
            const Disclaimer(),
          ],
        ),
      ),
    );
  }
}

// ─── Widgets ──────────────────────────────────────────────────────────────────

class _Stat extends StatelessWidget {
  final String label;
  final int? value;
  final String unit;
  const _Stat({required this.label, required this.value, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(children: [
        Text(label, style: AppText.labelSm),
        const SizedBox(height: AppSpace.xs),
        Text.rich(
          TextSpan(children: [
            TextSpan(text: value?.toString() ?? '—', style: AppText.headlineMd.merge(AppText.numeric)),
            if (value != null) TextSpan(text: unit, style: AppText.bodySm),
          ]),
        ),
      ]),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();
  @override
  Widget build(BuildContext context) => Container(width: 1, height: 28, color: AppColors.borderStrong);
}

class _GroupLabel extends StatelessWidget {
  final String text;
  const _GroupLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: AppSpace.xs, bottom: AppSpace.sm),
        child: Text(text, style: AppText.labelMd.copyWith(color: AppColors.textTertiary)),
      );
}

class _MenuCard extends StatelessWidget {
  final List<Widget> children;
  const _MenuCard({required this.children});

  @override
  Widget build(BuildContext context) => DsCard(
        padding: EdgeInsets.zero,
        child: Column(children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: AppSpace.lg, endIndent: AppSpace.lg),
            children[i],
          ],
        ]),
      );
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? color;
  final bool showChevron;

  const _MenuTile({
    required this.icon,
    required this.label,
    this.trailing,
    this.onTap,
    this.color,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.md),
        child: Row(children: [
          Icon(icon, size: 22, color: color ?? AppColors.textSecondary),
          const SizedBox(width: AppSpace.sm + 4),
          Expanded(child: Text(label, style: AppText.bodyMd.copyWith(color: color))),
          if (trailing != null) trailing!,
          if (onTap != null && showChevron) ...[
            const SizedBox(width: AppSpace.xs),
            Icon(Icons.chevron_right_rounded, size: 20, color: color ?? AppColors.textDisabled),
          ],
        ]),
      ),
    );
  }
}

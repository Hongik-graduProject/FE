// lib/screens/auth/delete_account_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../utils/design_tokens.dart';
import '../../widgets/common_widgets.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _agreedToDelete = false;

  static const _deletedItems = [
    (Icons.person_remove_outlined, '탈퇴 즉시 모든 계정 정보와 프로필이 삭제됩니다'),
    (Icons.folder_delete_outlined, '관심 기업 폴더, 등록한 종목과 메모가 모두 삭제됩니다'),
    (Icons.notifications_off_outlined, '분석 설정 및 알림 기록이 삭제됩니다'),
    (Icons.history_toggle_off, '삭제된 데이터는 복구할 수 없습니다'),
  ];

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _deleteAccount() async {
    if (_passwordController.text.isEmpty) {
      showErrorSnackBar(context, '비밀번호를 입력해 주세요');
      return;
    }
    if (!_agreedToDelete) {
      showErrorSnackBar(context, '탈퇴 안내 사항에 동의해 주세요');
      return;
    }

    // 최종 확인 다이얼로그
    final confirm = await showConfirmDialog(
      context,
      title: '정말 탈퇴하시겠습니까?',
      content: '탈퇴 시 모든 데이터가 삭제되며\n복구할 수 없습니다.',
      confirmText: '탈퇴하기',
      cancelText: '취소',
      confirmColor: AppColors.error,
    );

    if (confirm != true || !mounted) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.deleteAccount(_passwordController.text);

    if (!mounted) return;

    if (success) {
      Navigator.pushNamedAndRemoveUntil(
          context, '/login', (route) => false);
      showSuccessSnackBar(context, '회원 탈퇴가 완료되었습니다');
    } else {
      showErrorSnackBar(
          context, authProvider.errorMessage ?? '탈퇴 처리 중 오류가 발생했습니다');
      authProvider.clearError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final canDelete = !authProvider.isLoading &&
        _agreedToDelete &&
        _passwordController.text.isNotEmpty;

    return LoadingOverlay(
      isLoading: authProvider.isLoading,
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        appBar: AppBar(
          title: const Text('회원 탈퇴'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── 경고 카드 ─────────────────────────
                Container(
                  padding: const EdgeInsets.all(AppSpace.lg),
                  decoration: BoxDecoration(
                    color: AppColors.errorTint.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.warning_rounded,
                              color: AppColors.error, size: 22),
                          const SizedBox(width: AppSpace.sm),
                          Text('탈퇴 전 꼭 확인해 주세요',
                              style: AppText.headlineSm
                                  .copyWith(color: AppColors.error)),
                        ],
                      ),
                      const SizedBox(height: AppSpace.md),
                      for (final (icon, text) in _deletedItems)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(icon, size: 18, color: AppColors.error),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(text,
                                    style: AppText.bodyMd.copyWith(
                                        color: AppColors.textSecondary)),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpace.xl),

                // ── 본인 확인 ─────────────────────────
                Container(
                  padding: const EdgeInsets.all(AppSpace.lg),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    boxShadow: AppShadow.card,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('본인 확인', style: AppText.headlineSm),
                      const SizedBox(height: AppSpace.xs),
                      const Text('안전한 탈퇴를 위해 현재 비밀번호를 입력해 주세요.',
                          style: AppText.bodySm),
                      const SizedBox(height: AppSpace.md),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        autofillHints: const [AutofillHints.password],
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: '현재 비밀번호 입력',
                          prefixIcon: const Icon(Icons.lock_outline, size: 20),
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword ? '비밀번호 보기' : '비밀번호 숨기기',
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 20,
                              color: AppColors.textTertiary,
                            ),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpace.md),

                // ── 동의 체크박스 ─────────────────────
                InkWell(
                  onTap: () =>
                      setState(() => _agreedToDelete = !_agreedToDelete),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: Checkbox(
                            value: _agreedToDelete,
                            onChanged: (v) =>
                                setState(() => _agreedToDelete = v ?? false),
                            activeColor: AppColors.error,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text.rich(
                                TextSpan(
                                  style: AppText.bodyMd,
                                  children: [
                                    TextSpan(
                                      text: '[필수] ',
                                      style: AppText.labelLg
                                          .copyWith(color: AppColors.error),
                                    ),
                                    const TextSpan(
                                        text: '위 유의사항을 모두 확인하였으며, 회원 탈퇴에 동의합니다.'),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text('동의 후 탈퇴하면 계정을 복구할 수 없어요.',
                                  style: AppText.labelSm),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.xl),

                // ── 탈퇴 버튼 ─────────────────────────
                ElevatedButton.icon(
                  onPressed: canDelete ? _deleteAccount : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    disabledBackgroundColor: AppColors.textDisabled,
                  ),
                  icon: const Icon(Icons.person_remove_outlined, size: 20),
                  label: const Text('회원 탈퇴'),
                ),
                const SizedBox(height: 12),

                // ── 취소 버튼 ─────────────────────────
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

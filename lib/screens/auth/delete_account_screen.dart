// lib/screens/auth/delete_account_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../utils/constants.dart';
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
      confirmColor: const Color(AppConstants.errorColor),
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

    return LoadingOverlay(
      isLoading: authProvider.isLoading,
      child: Scaffold(
        backgroundColor: const Color(AppConstants.backgroundColor),
        appBar: AppBar(
          title: const Text('회원 탈퇴'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 경고 배너 ─────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(AppConstants.errorColor).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(AppConstants.errorColor).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(AppConstants.errorColor),
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '탈퇴 전 꼭 확인해 주세요',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: Color(AppConstants.errorColor),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '• 탈퇴 즉시 모든 계정 정보가 삭제됩니다\n'
                              '• 관심 기업 폴더와 메모가 모두 삭제됩니다\n'
                              '• 분석 설정 및 알림 기록이 삭제됩니다\n'
                              '• 삭제된 데이터는 복구할 수 없습니다',
                              style: TextStyle(
                                fontSize: 13,
                                color: const Color(AppConstants.errorColor)
                                    .withValues(alpha: 0.85),
                                height: 1.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // ── 비밀번호 확인 ─────────────────────
                const Text(
                  '본인 확인',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(AppConstants.textPrimary),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '탈퇴를 위해 현재 비밀번호를 입력해 주세요',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(AppConstants.textSecondary),
                  ),
                ),
                const SizedBox(height: 16),

                AppTextField(
                  controller: _passwordController,
                  label: '현재 비밀번호',
                  hint: '비밀번호를 입력해 주세요',
                  obscureText: _obscurePassword,
                  prefixIcon: const Icon(Icons.lock_outline, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                      color: const Color(AppConstants.textSecondary),
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),

                const SizedBox(height: 32),

                // ── 동의 체크박스 ─────────────────────
                InkWell(
                  onTap: () =>
                      setState(() => _agreedToDelete = !_agreedToDelete),
                  borderRadius: BorderRadius.circular(8),
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
                            activeColor: const Color(AppConstants.errorColor),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            '위 내용을 모두 확인하였으며, 회원 탈퇴에 동의합니다',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(AppConstants.textPrimary),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // ── 탈퇴 버튼 ─────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed:
                        (authProvider.isLoading || !_agreedToDelete)
                            ? null
                            : _deleteAccount,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(AppConstants.errorColor),
                      disabledBackgroundColor:
                          const Color(AppConstants.errorColor).withValues(alpha: 0.4),
                    ),
                    child: const Text('회원 탈퇴'),
                  ),
                ),

                const SizedBox(height: 12),

                // ── 취소 버튼 ─────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('취소'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

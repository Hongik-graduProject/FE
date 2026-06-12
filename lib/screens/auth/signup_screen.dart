// lib/screens/auth/signup_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../utils/constants.dart';
import '../../widgets/common_widgets.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nicknameController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  // 이메일 중복 확인 상태
  bool _isCheckingEmail = false;
  bool? _isEmailAvailable; // null=미확인, true=사용가능, false=중복
  String _lastCheckedEmail = '';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  // 이메일 중복 확인
  Future<void> _checkEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      showErrorSnackBar(context, '이메일을 입력해 주세요');
      return;
    }
    final emailRegex = RegExp(r'^[\w.-]+@[\w.-]+\.\w+$');
    if (!emailRegex.hasMatch(email)) {
      showErrorSnackBar(context, '올바른 이메일 형식을 입력해 주세요');
      return;
    }

    setState(() {
      _isCheckingEmail = true;
      _isEmailAvailable = null;
    });

    final authProvider = context.read<AuthProvider>();
    final available = await authProvider.checkEmail(email);

    if (!mounted) return;
    setState(() {
      _isCheckingEmail = false;
      _isEmailAvailable = available;
      _lastCheckedEmail = email;
    });

    if (available == true) {
      showSuccessSnackBar(context, '사용 가능한 이메일입니다');
    } else if (available == false) {
      showErrorSnackBar(context, '이미 가입된 이메일입니다');
    } else {
      showErrorSnackBar(context, '확인 중 오류가 발생했습니다');
    }
  }

  // 회원가입 제출
  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;

    // 이메일 중복확인 필수
    if (_isEmailAvailable != true ||
        _lastCheckedEmail != _emailController.text.trim()) {
      showErrorSnackBar(context, '이메일 중복 확인을 먼저 진행해 주세요');
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.signup(
      _emailController.text.trim(),
      _passwordController.text,
      nickname: _nicknameController.text.trim().isEmpty
          ? null
          : _nicknameController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      showSuccessSnackBar(context, '회원가입이 완료되었습니다! 로그인해 주세요');
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    } else {
      showErrorSnackBar(
          context, authProvider.errorMessage ?? '회원가입에 실패했습니다');
      authProvider.clearError();
    }
  }

  // 이메일 변경 시 중복 확인 상태 초기화
  void _onEmailChanged(String _) {
    if (_isEmailAvailable != null) {
      setState(() => _isEmailAvailable = null);
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
          title: const Text('회원가입'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 안내 텍스트 ───────────────────────
                  const Text(
                    '반갑습니다!\n정보를 입력해 주세요',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Color(AppConstants.textPrimary),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── 이메일 + 중복확인 ─────────────────
                  const _FieldLabel(text: '이메일', required: true),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          onChanged: _onEmailChanged,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(AppConstants.textPrimary),
                          ),
                          decoration: InputDecoration(
                            hintText: 'example@email.com',
                            suffixIcon: _isEmailAvailable == null
                                ? null
                                : Icon(
                                    _isEmailAvailable!
                                        ? Icons.check_circle
                                        : Icons.cancel,
                                    color: _isEmailAvailable!
                                        ? const Color(AppConstants.accentColor)
                                        : const Color(AppConstants.errorColor),
                                    size: 20,
                                  ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return '이메일을 입력해 주세요';
                            }
                            final emailRegex =
                                RegExp(r'^[\w.-]+@[\w.-]+\.\w+$');
                            if (!emailRegex.hasMatch(value.trim())) {
                              return '올바른 이메일 형식을 입력해 주세요';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 90,
                        height: 52,
                        child: ElevatedButton(
                          onPressed:
                              _isCheckingEmail ? null : _checkEmail,
                          style: ElevatedButton.styleFrom(
                            minimumSize: Size.zero,
                            padding: EdgeInsets.zero,
                          ),
                          child: _isCheckingEmail
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('중복확인',
                                  style: TextStyle(fontSize: 13)),
                        ),
                      ),
                    ],
                  ),

                  // 이메일 중복 확인 결과 메시지
                  if (_isEmailAvailable != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 4),
                      child: Text(
                        _isEmailAvailable!
                            ? '✓ 사용 가능한 이메일입니다'
                            : '✗ 이미 사용 중인 이메일입니다',
                        style: TextStyle(
                          fontSize: 12,
                          color: _isEmailAvailable!
                              ? const Color(AppConstants.accentColor)
                              : const Color(AppConstants.errorColor),
                        ),
                      ),
                    ),

                  const SizedBox(height: 20),

                  // ── 비밀번호 ──────────────────────────
                  const _FieldLabel(text: '비밀번호', required: true),
                  const SizedBox(height: 8),
                  AppTextField(
                    controller: _passwordController,
                    label: '비밀번호',
                    hint: '영문+숫자 포함 8자 이상',
                    obscureText: _obscurePassword,
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
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '비밀번호를 입력해 주세요';
                      }
                      if (value.length < 8) {
                        return '비밀번호는 최소 8자 이상이어야 합니다';
                      }
                      if (!RegExp(r'[a-zA-Z]').hasMatch(value) ||
                          !RegExp(r'[0-9]').hasMatch(value)) {
                        return '영문과 숫자를 모두 포함해야 합니다';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 6),

                  // 비밀번호 규칙 안내
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Text(
                      '영문, 숫자 포함 8자 이상',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(AppConstants.textSecondary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── 비밀번호 확인 ─────────────────────
                  const _FieldLabel(text: '비밀번호 확인', required: true),
                  const SizedBox(height: 8),
                  AppTextField(
                    controller: _confirmPasswordController,
                    label: '비밀번호 확인',
                    hint: '비밀번호를 다시 입력해 주세요',
                    obscureText: _obscureConfirm,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20,
                        color: const Color(AppConstants.textSecondary),
                      ),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '비밀번호 확인을 입력해 주세요';
                      }
                      if (value != _passwordController.text) {
                        return '비밀번호가 일치하지 않습니다';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // ── 닉네임 (선택) ─────────────────────
                  const _FieldLabel(text: '닉네임', required: false),
                  const SizedBox(height: 8),
                  AppTextField(
                    controller: _nicknameController,
                    label: '닉네임 (선택)',
                    hint: '미입력 시 자동 생성됩니다',
                  ),
                  const SizedBox(height: 6),
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Text(
                      '미입력 시 랜덤 닉네임이 자동으로 생성됩니다',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(AppConstants.textSecondary),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // ── 가입 버튼 ─────────────────────────
                  ElevatedButton(
                    onPressed: authProvider.isLoading ? null : _signup,
                    child: const Text('가입하기'),
                  ),

                  const SizedBox(height: 16),

                  // ── 로그인으로 이동 ───────────────────
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text.rich(
                        TextSpan(
                          text: '이미 계정이 있으신가요? ',
                          style: TextStyle(
                            color: Color(AppConstants.textSecondary),
                            fontSize: 14,
                          ),
                          children: [
                            TextSpan(
                              text: '로그인',
                              style: TextStyle(
                                color: Color(AppConstants.primaryColor),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// 필드 레이블 위젯
class _FieldLabel extends StatelessWidget {
  final String text;
  final bool required;

  const _FieldLabel({required this.text, required this.required});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(AppConstants.textPrimary),
          ),
        ),
        if (required)
          const Text(
            ' *',
            style: TextStyle(
              color: Color(AppConstants.errorColor),
              fontSize: 14,
            ),
          ),
      ],
    );
  }
}

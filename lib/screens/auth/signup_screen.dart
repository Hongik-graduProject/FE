// lib/screens/auth/signup_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../utils/design_tokens.dart';
import '../../widgets/common_widgets.dart';

final _emailRegex = RegExp(r'^[\w.-]+@[\w.-]+\.\w+$');

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
  final _emailFocus = FocusNode();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _agreedToTerms = false;

  // 이메일 자동 중복 확인 상태
  Timer? _emailDebounce;
  bool _isCheckingEmail = false;
  bool? _isEmailAvailable; // null=미확인, true=사용가능, false=중복
  String _lastCheckedEmail = '';
  String? _emailError; // 형식 오류·확인 실패 안내

  @override
  void initState() {
    super.initState();
    // 이메일 칸을 벗어나면 바로 확인한다.
    _emailFocus.addListener(() {
      if (!_emailFocus.hasFocus) {
        _emailDebounce?.cancel();
        _checkEmail(showFormatError: true);
      }
    });
  }

  @override
  void dispose() {
    _emailDebounce?.cancel();
    _emailFocus.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  // 입력이 500ms 멈추면 확인. 이전 결과는 바로 무효화한다.
  void _onEmailChanged(String _) {
    _emailDebounce?.cancel();
    setState(() {
      _isEmailAvailable = null;
      _isCheckingEmail = false;
      _emailError = null;
    });
    _emailDebounce =
        Timer(const Duration(milliseconds: 500), () => _checkEmail());
  }

  // 사용 가능 여부를 돌려준다. 형식 오류·실패·응답이 낡은 경우 null.
  Future<bool?> _checkEmail({bool showFormatError = false}) async {
    final email = _emailController.text.trim();
    // 화면이 닫히며 포커스가 풀릴 때도 호출되므로 mounted 를 먼저 본다.
    if (!mounted || email.isEmpty) return null;
    if (!_emailRegex.hasMatch(email)) {
      if (showFormatError) {
        setState(() => _emailError = '올바른 이메일 형식을 입력해 주세요');
      }
      return null;
    }
    if (email == _lastCheckedEmail && _isEmailAvailable != null) {
      return _isEmailAvailable;
    }

    setState(() => _isCheckingEmail = true);
    final available = await context.read<AuthProvider>().checkEmail(email);

    // 확인 중에 이메일이 바뀌었으면 이 응답은 버린다.
    if (!mounted || email != _emailController.text.trim()) return null;
    setState(() {
      _isCheckingEmail = false;
      _lastCheckedEmail = email;
      _isEmailAvailable = available;
      _emailError = available == null ? '이메일 확인에 실패했어요. 잠시 후 다시 시도해 주세요' : null;
    });
    return available;
  }

  // 회원가입 제출 → 같은 계정으로 자동 로그인
  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    if (await _checkEmail(showFormatError: true) != true || !mounted) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.signup(
      email,
      password,
      nickname: _nicknameController.text.trim().isEmpty
          ? null
          : _nicknameController.text.trim(),
    );

    if (!mounted) return;

    if (!success) {
      showErrorSnackBar(
          context, authProvider.errorMessage ?? '회원가입에 실패했습니다');
      authProvider.clearError();
      return;
    }

    final loggedIn = await authProvider.login(email, password);
    if (!mounted) return;
    if (loggedIn) {
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    } else {
      authProvider.clearError();
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      showSuccessSnackBar(context, '가입이 완료되었어요. 로그인해 주세요');
    }
  }

  // 0=미입력, 1=약함, 2=보통(가입 조건 충족), 3=안전함
  int get _passwordStrength {
    final p = _passwordController.text;
    if (p.isEmpty) return 0;
    final meetsRule = p.length >= 8 &&
        RegExp(r'[a-zA-Z]').hasMatch(p) &&
        RegExp(r'[0-9]').hasMatch(p);
    if (!meetsRule) return 1;
    return p.length >= 12 || RegExp(r'[^a-zA-Z0-9]').hasMatch(p) ? 3 : 2;
  }

  Widget? _emailSuffix() {
    if (_isCheckingEmail) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_isEmailAvailable == null) return null;
    return Icon(
      _isEmailAvailable! ? Icons.check_circle : Icons.cancel,
      color: _isEmailAvailable! ? AppColors.accent : AppColors.error,
      size: 20,
    );
  }

  Widget _visibilityToggle(bool obscured, VoidCallback onPressed) {
    return IconButton(
      tooltip: obscured ? '비밀번호 보기' : '비밀번호 숨기기',
      icon: Icon(
        obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        size: 20,
        color: AppColors.textTertiary,
      ),
      onPressed: onPressed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final strength = _passwordStrength;
    final strengthColor =
        [AppColors.border, AppColors.error, AppColors.accent, AppColors.brand][strength];
    final confirm = _confirmPasswordController.text;

    return LoadingOverlay(
      isLoading: authProvider.isLoading,
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        appBar: AppBar(
          title: const Text('회원가입'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.xl),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── 안내 텍스트 ───────────────────────
                  const Text('반갑습니다!\n정보를 입력해 주세요',
                      style: AppText.headlineLg),
                  const SizedBox(height: AppSpace.sm),
                  Text('가입 후 관심종목을 등록하고 맞춤 공시 분석을 받아보세요.',
                      style: AppText.bodyMd
                          .copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: AppSpace.xl),

                  // ── 입력 카드 ─────────────────────────
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
                        // ── 이메일 ────────────────────────────
                        const _FieldLabel(
                            text: '이메일',
                            required: true,
                            trailing: '로그인 아이디로 사용돼요'),
                        const SizedBox(height: AppSpace.sm),
                        TextFormField(
                          controller: _emailController,
                          focusNode: _emailFocus,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          onChanged: _onEmailChanged,
                          decoration: InputDecoration(
                            hintText: 'email@example.com',
                            suffixIcon: _emailSuffix(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return '이메일을 입력해 주세요';
                            }
                            if (!_emailRegex.hasMatch(value.trim())) {
                              return '올바른 이메일 형식을 입력해 주세요';
                            }
                            return null;
                          },
                        ),
                        if (_emailError != null)
                          _InlineStatus(text: _emailError!, ok: false)
                        else if (_isEmailAvailable != null)
                          _InlineStatus(
                            text: _isEmailAvailable!
                                ? '사용 가능한 이메일이에요'
                                : '이미 가입된 이메일이에요',
                            ok: _isEmailAvailable!,
                          ),
                        const SizedBox(height: AppSpace.lg),

                        // ── 비밀번호 ──────────────────────────
                        const _FieldLabel(text: '비밀번호', required: true),
                        const SizedBox(height: AppSpace.sm),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          autofillHints: const [AutofillHints.newPassword],
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: '영문+숫자 8자 이상',
                            suffixIcon: _visibilityToggle(
                                _obscurePassword,
                                () => setState(
                                    () => _obscurePassword = !_obscurePassword)),
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
                        const SizedBox(height: AppSpace.sm),

                        // 비밀번호 강도
                        Row(
                          children: [
                            for (var i = 1; i <= 3; i++) ...[
                              if (i > 1) const SizedBox(width: AppSpace.xs),
                              Expanded(
                                child: Container(
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: i <= strength
                                        ? strengthColor
                                        : AppColors.border,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (strength > 0) ...[
                              Icon(Icons.shield_outlined,
                                  size: 14, color: strengthColor),
                              const SizedBox(width: AppSpace.xs),
                              Text(['', '약함', '보통', '안전함'][strength],
                                  style: AppText.labelMd
                                      .copyWith(color: strengthColor)),
                            ],
                            const Spacer(),
                            const Text('영문+숫자 8자 이상',
                                style: AppText.labelSm),
                          ],
                        ),
                        const SizedBox(height: AppSpace.lg),

                        // ── 비밀번호 확인 ─────────────────────
                        const _FieldLabel(text: '비밀번호 확인', required: true),
                        const SizedBox(height: AppSpace.sm),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirm,
                          autofillHints: const [AutofillHints.newPassword],
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: '비밀번호를 한 번 더 입력하세요',
                            suffixIcon: _visibilityToggle(
                                _obscureConfirm,
                                () => setState(
                                    () => _obscureConfirm = !_obscureConfirm)),
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
                        if (confirm.isNotEmpty &&
                            confirm == _passwordController.text)
                          const _InlineStatus(text: '비밀번호가 일치해요', ok: true),
                        const SizedBox(height: AppSpace.lg),

                        // ── 닉네임 (선택) ─────────────────────
                        const _FieldLabel(text: '닉네임', required: false),
                        const SizedBox(height: AppSpace.sm),
                        TextFormField(
                          controller: _nicknameController,
                          decoration: const InputDecoration(
                            hintText: '비우면 자동으로 만들어 드려요',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpace.md),

                  // ── 약관 동의 (필수) ──────────────────
                  InkWell(
                    onTap: () =>
                        setState(() => _agreedToTerms = !_agreedToTerms),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 22,
                            height: 22,
                            child: Checkbox(
                              value: _agreedToTerms,
                              onChanged: (v) =>
                                  setState(() => _agreedToTerms = v ?? false),
                              activeColor: AppColors.brand,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                style: AppText.bodyMd,
                                children: [
                                  TextSpan(
                                    text: '[필수] ',
                                    style: AppText.labelLg
                                        .copyWith(color: AppColors.accent),
                                  ),
                                  const TextSpan(text: '이용약관 및 개인정보처리방침 동의'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpace.md),

                  // ── 가입 버튼 ─────────────────────────
                  ElevatedButton(
                    onPressed: (authProvider.isLoading || !_agreedToTerms)
                        ? null
                        : _signup,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('가입하고 시작하기'),
                        SizedBox(width: 6),
                        Icon(Icons.arrow_forward, size: 18),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpace.sm),

                  // ── 로그인으로 이동 ───────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('이미 계정이 있으신가요?',
                          style: AppText.bodyMd
                              .copyWith(color: AppColors.textSecondary)),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('로그인',
                            style: AppText.labelLg
                                .copyWith(color: AppColors.accent)),
                      ),
                    ],
                  ),
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
  final String? trailing;

  const _FieldLabel({required this.text, required this.required, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(text, style: AppText.labelLg),
        if (required)
          const Text(' *', style: TextStyle(color: AppColors.error, fontSize: 14))
        else
          const Text(' (선택)', style: AppText.labelSm),
        const Spacer(),
        if (trailing != null) Text(trailing!, style: AppText.labelSm),
      ],
    );
  }
}

// 입력칸 아래 ✓/✗ 안내. 성공은 초록 대신 accent 파랑을 쓴다.
class _InlineStatus extends StatelessWidget {
  final String text;
  final bool ok;

  const _InlineStatus({required this.text, required this.ok});

  @override
  Widget build(BuildContext context) {
    final color = ok ? AppColors.accent : AppColors.error;
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 4),
      child: Row(
        children: [
          Icon(ok ? Icons.check : Icons.error_outline, size: 14, color: color),
          const SizedBox(width: AppSpace.xs),
          Expanded(
            child: Text(text, style: AppText.labelMd.copyWith(color: color)),
          ),
        ],
      ),
    );
  }
}

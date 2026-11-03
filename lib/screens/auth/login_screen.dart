// lib/screens/auth/login_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_provider.dart';
import '../../utils/design_tokens.dart';
import '../../widgets/common_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberEmail = false;
  String? _error;

  static const _rememberedEmailKey = 'remembered_email';

  @override
  void initState() {
    super.initState();
    _loadRememberedEmail();
  }

  Future<void> _loadRememberedEmail() async {
    final email = (await SharedPreferences.getInstance()).getString(_rememberedEmailKey);
    if (email != null && mounted) {
      setState(() {
        _emailController.text = email;
        _rememberEmail = true;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _clearError(String _) {
    if (_error != null) setState(() => _error = null);
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      final prefs = await SharedPreferences.getInstance();
      if (_rememberEmail) {
        await prefs.setString(_rememberedEmailKey, _emailController.text.trim());
      } else {
        await prefs.remove(_rememberedEmailKey);
      }
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      final msg = authProvider.errorMessage;
      // AUTH_INVALID 문구(api_service)만 디자인 톤으로 바꾸고, 그 외(네트워크 등)는 그대로 보여 준다.
      setState(() => _error = msg == null || msg == '이메일 또는 비밀번호가 올바르지 않습니다'
          ? '이메일 또는 비밀번호가 맞지 않아요'
          : msg);
      authProvider.clearError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return LoadingOverlay(
      isLoading: authProvider.isLoading,
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 48),

                  // ── 헤더 ──────────────────────────────
                  Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.brand,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        boxShadow: AppShadow.raised,
                      ),
                      child: const Icon(Icons.radar_rounded,
                          size: 32, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: AppSpace.md),
                  const Text('반가워요!\n다시 오신 것을 환영합니다',
                      textAlign: TextAlign.center, style: AppText.headlineLg),
                  const SizedBox(height: AppSpace.sm),
                  Text('등록하신 이메일과 비밀번호로 로그인해 주세요.',
                      textAlign: TextAlign.center,
                      style: AppText.bodyMd
                          .copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: AppSpace.xxl),

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
                        const Text('이메일', style: AppText.labelLg),
                        const SizedBox(height: AppSpace.sm),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          onChanged: _clearError,
                          decoration: InputDecoration(
                            hintText: 'example@email.com',
                            prefixIcon: const Icon(Icons.mail_outline, size: 20),
                            suffixIcon: ValueListenableBuilder(
                              valueListenable: _emailController,
                              builder: (context, value, _) => value.text.isEmpty
                                  ? const SizedBox.shrink()
                                  : IconButton(
                                      tooltip: '이메일 지우기',
                                      icon: const Icon(Icons.cancel_outlined,
                                          size: 20,
                                          color: AppColors.textTertiary),
                                      onPressed: () {
                                        _emailController.clear();
                                        _clearError('');
                                      },
                                    ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return '이메일을 입력해 주세요';
                            }
                            final emailRegex = RegExp(r'^[\w.-]+@[\w.-]+\.\w+$');
                            if (!emailRegex.hasMatch(value.trim())) {
                              return '올바른 이메일 형식을 입력해 주세요';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpace.md),

                        const Text('비밀번호', style: AppText.labelLg),
                        const SizedBox(height: AppSpace.sm),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          autofillHints: const [AutofillHints.password],
                          onChanged: _clearError,
                          onFieldSubmitted: (_) => _login(),
                          decoration: InputDecoration(
                            hintText: '비밀번호 입력',
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
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '비밀번호를 입력해 주세요';
                            }
                            return null;
                          },
                        ),

                        // ── 인라인 오류 ───────────────────────
                        if (_error != null) ...[
                          const SizedBox(height: AppSpace.md),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.errorTint.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline,
                                    size: 18, color: AppColors.error),
                                const SizedBox(width: AppSpace.sm),
                                Expanded(
                                  child: Text(_error!,
                                      style: AppText.bodyMd
                                          .copyWith(color: AppColors.error)),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpace.sm),

                        // ── 이메일 저장 ───────────────────────
                        InkWell(
                          onTap: () =>
                              setState(() => _rememberEmail = !_rememberEmail),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: Checkbox(
                                    value: _rememberEmail,
                                    onChanged: (v) =>
                                        setState(() => _rememberEmail = v ?? false),
                                    activeColor: AppColors.brand,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4)),
                                  ),
                                ),
                                const SizedBox(width: AppSpace.sm),
                                Text('이메일 저장',
                                    style: AppText.bodyMd.copyWith(
                                        color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpace.md),

                        // ── 로그인 버튼 ───────────────────────
                        ElevatedButton(
                          onPressed: authProvider.isLoading ? null : _login,
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('로그인'),
                              SizedBox(width: 6),
                              Icon(Icons.arrow_forward, size: 18),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpace.xl),

                  // ── 회원가입 링크 ─────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('아직 공시레이더 회원이 아니신가요?',
                          style: AppText.bodyMd
                              .copyWith(color: AppColors.textSecondary)),
                      TextButton(
                        onPressed: () => Navigator.pushNamed(context, '/signup'),
                        child: Text('회원가입',
                            style: AppText.labelLg
                                .copyWith(color: AppColors.accent)),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.md),

                  // ── 하단 안내 ─────────────────────────
                  const Text(
                    '로그인 시 이용약관 및 개인정보처리방침에 동의하게 됩니다.\n'
                    '투자 참고용 정보이며 투자 권유가 아닙니다. 수익을 보장하지 않습니다.',
                    style: AppText.labelSm,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpace.xl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

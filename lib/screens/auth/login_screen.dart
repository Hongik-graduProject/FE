// lib/screens/auth/login_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../utils/constants.dart';
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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      showErrorSnackBar(context, authProvider.errorMessage ?? '로그인에 실패했습니다');
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
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 60),

                  // ── 헤더 ──────────────────────────────
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: const Color(AppConstants.primaryColor),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.bar_chart_rounded,
                            size: 40,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          '공시레이더',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: Color(AppConstants.textPrimary),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          '투자 인사이트를 한눈에',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(AppConstants.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 48),

                  // ── 이메일 ────────────────────────────
                  AppTextField(
                    controller: _emailController,
                    label: '이메일',
                    hint: 'example@email.com',
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: const Icon(Icons.email_outlined, size: 20),
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
                  const SizedBox(height: 14),

                  // ── 비밀번호 ──────────────────────────
                  AppTextField(
                    controller: _passwordController,
                    label: '비밀번호',
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
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '비밀번호를 입력해 주세요';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),

                  // ── 이메일 기억하기 ───────────────────
                  Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: Checkbox(
                          value: _rememberEmail,
                          onChanged: (v) =>
                              setState(() => _rememberEmail = v ?? false),
                          activeColor: const Color(AppConstants.primaryColor),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '이메일 기억하기',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(AppConstants.textSecondary),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // ── 로그인 버튼 ───────────────────────
                  ElevatedButton(
                    onPressed: authProvider.isLoading ? null : _login,
                    child: const Text('로그인'),
                  ),

                  const SizedBox(height: 20),

                  // ── 회원가입 링크 ─────────────────────
                  const SectionDivider(text: '또는'),
                  const SizedBox(height: 20),

                  OutlinedButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/signup'),
                    child: const Text('회원가입'),
                  ),

                  const SizedBox(height: 32),

                  // ── 하단 안내 ─────────────────────────
                  Center(
                    child: Text(
                      '로그인 시 이용약관 및 개인정보처리방침에 동의합니다',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                      textAlign: TextAlign.center,
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

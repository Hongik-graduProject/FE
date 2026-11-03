// lib/screens/auth/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../utils/design_tokens.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _scaleAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _animController.forward();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    // 최소 스플래시 노출 시간 확보
    await Future.delayed(const Duration(milliseconds: 1800));

    if (!mounted) return;

    final authProvider = context.read<AuthProvider>();
    await authProvider.checkAuthStatus();

    if (!mounted) return;

    if (authProvider.status == AuthStatus.authenticated) {
      // 로그인 상태 → 홈으로
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      // 미로그인 → 로그인 화면으로
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dim = Colors.white.withValues(alpha: 0.7);
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.brand, AppColors.brandPressed],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: ScaleTransition(
                      scale: _scaleAnim,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 앱 마크
                          Container(
                            width: 104,
                            height: 104,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.2)),
                              boxShadow: AppShadow.raised,
                            ),
                            child: const Icon(Icons.radar_rounded,
                                size: 56, color: Colors.white),
                          ),
                          const SizedBox(height: AppSpace.xl),
                          Text('공시레이더',
                              style: AppText.headlineXl
                                  .copyWith(color: Colors.white, fontSize: 32)),
                          const SizedBox(height: AppSpace.sm),
                          Text('내 종목의 공시를 10초 만에',
                              style: AppText.bodyLg.copyWith(color: dim)),
                          const SizedBox(height: AppSpace.lg),
                          Wrap(
                            spacing: AppSpace.sm,
                            children: [
                              for (final t in ['DART 전자공시', 'CAR 모형', '이상수익률'])
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(t,
                                      style: AppText.labelMd
                                          .copyWith(color: dim)),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: dim),
              ),
              const SizedBox(height: AppSpace.xl),
              Text(
                '금융감독원 전자공시시스템(DART) Open API 연계',
                style: AppText.labelSm
                    .copyWith(color: Colors.white.withValues(alpha: 0.5)),
              ),
              const SizedBox(height: AppSpace.xl),
            ],
          ),
        ),
      ),
    );
  }
}

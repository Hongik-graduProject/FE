// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/api_service.dart';
import 'services/auth_provider.dart';
import 'utils/app_theme.dart';

// 화면 imports
import 'screens/auth/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/delete_account_screen.dart';
import 'screens/home_screen.dart';
import 'screens/company/company_detail_screen.dart';
import 'screens/company/report_detail_screen.dart';
import 'screens/folder/folder_detail_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // API 서비스 초기화 (Dio 인터셉터 등록)
  ApiService().init();

  runApp(const DisclosureApp());
}

class DisclosureApp extends StatelessWidget {
  const DisclosureApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        title: '공시레이더',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,

        // 초기 화면: 스플래시
        initialRoute: '/',

        // 라우트 정의
        routes: {
          '/': (context) => const SplashScreen(),
          '/login': (context) => const LoginScreen(),
          '/signup': (context) => const SignupScreen(),
          '/home': (context) => const HomeScreen(),
          '/delete-account': (context) => const DeleteAccountScreen(),
          '/company': (context) => const CompanyDetailScreen(),
          '/report': (context) => const ReportDetailScreen(),
          '/folder': (context) => const FolderDetailScreen(),
          '/settings': (context) => const SettingsScreen(),
        },
      ),
    );
  }
}

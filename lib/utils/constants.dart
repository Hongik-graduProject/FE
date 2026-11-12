// lib/utils/constants.dart

class AppConstants {
  // Base URL — 로컬 백엔드(Spring Boot, context-path 없음, 포트 8080)를 가리킨다.
  // BE는 `/v1` 같은 prefix를 쓰지 않으므로 붙이지 않는다.
  //
  // 실행 환경에 따라 아래 값으로 교체하세요:
  //   - macOS/웹/iOS 시뮬레이터:  http://localhost:8080   ← 기본값
  //   - Android 에뮬레이터:        http://10.0.2.2:8080   (호스트 머신의 localhost)
  //   - 실기기(같은 LAN):          http://<Mac의 LAN IP>:8080   (예: http://192.168.0.10:8080)
  //   - 배포 서버:                 flutter run --dart-define=API_BASE_URL=https://<서버 주소>
  static const String baseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8080');

  // Token 관련
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';

  // 앱 색상. 새 코드는 utils/design_tokens.dart 의 AppColors 를 쓴다.
  // 아직 바꾸지 않은 화면도 같은 색으로 보이도록 값만 새 토큰에 맞췄다.
  static const int primaryColor = 0xFF3B66FF;       // AppColors.brand
  static const int primaryDarkColor = 0xFF2F52CC;   // AppColors.brandPressed
  static const int accentColor = 0xFF4F75FF;        // AppColors.accent (초록 금지)
  static const int errorColor = 0xFFFF6B5E;         // AppColors.error
  static const int warningColor = 0xFFFBBC04;
  static const int backgroundColor = 0xFF0A1128;   // AppColors.canvas
  static const int surfaceColor = 0xFF101B3B;       // AppColors.card
  static const int textPrimary = 0xFFEEF1FF;        // AppColors.textPrimary
  static const int textSecondary = 0xFFC4C5D8;      // AppColors.textSecondary
  static const int dividerColor = 0xFF222D4A;       // AppColors.border
}

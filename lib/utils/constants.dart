// lib/utils/constants.dart

class AppConstants {
  // Base URL — 로컬 백엔드(Spring Boot, context-path 없음, 포트 8080)를 가리킨다.
  // BE는 `/v1` 같은 prefix를 쓰지 않으므로 붙이지 않는다.
  //
  // 실행 환경에 따라 아래 값으로 교체하세요:
  //   - macOS/웹/iOS 시뮬레이터:  http://localhost:8080   ← 기본값
  //   - Android 에뮬레이터:        http://10.0.2.2:8080   (호스트 머신의 localhost)
  //   - 실기기(같은 LAN):          http://<Mac의 LAN IP>:8080   (예: http://192.168.0.10:8080)
  static const String baseUrl = 'http://localhost:8080';

  // Token 관련
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';

  // 앱 색상 (메인 컬러 시스템)
  static const int primaryColor = 0xFF1A73E8;       // 메인 블루
  static const int primaryDarkColor = 0xFF1557B0;   // 진한 블루
  static const int accentColor = 0xFF34A853;        // 성공/긍정 그린
  static const int errorColor = 0xFFEA4335;         // 에러 레드
  static const int warningColor = 0xFFFBBC04;       // 경고 옐로우
  static const int backgroundColor = 0xFFF8F9FA;   // 배경
  static const int surfaceColor = 0xFFFFFFFF;       // 카드/서피스
  static const int textPrimary = 0xFF202124;        // 주요 텍스트
  static const int textSecondary = 0xFF5F6368;      // 보조 텍스트
  static const int dividerColor = 0xFFE8EAED;       // 구분선
}

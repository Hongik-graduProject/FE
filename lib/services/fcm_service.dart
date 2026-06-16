// lib/services/fcm_service.dart — FCM 푸시 알림 통합 (W-17 보조)
//
// Firebase 콘솔 셋업(google-services.json / GoogleService-Info.plist)이 배치되지
// 않은 환경에서는 initialize()가 조용히 skip되고, 앱은 정상 동작한다.
// 콘솔 셋업이 들어온 다음부터는 자동으로 토큰을 획득하고 BE /notifications/fcm-token으로
// UPSERT한다.
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

/// Background isolate가 메시지 수신 시 호출된다. 본 v1.0은 처리하지 않고
/// 시스템 알림 트레이에 그대로 표시되도록 둔다 (Notification payload + data).
@pragma('vm:entry-point')
Future<void> _backgroundMessageHandler(RemoteMessage message) async {
  // 로깅만 — UI 갱신은 foreground 핸들러에서.
  debugPrint('[FCM] background: ${message.notification?.title}');
}

class FcmService {
  static final FcmService _instance = FcmService._();
  factory FcmService() => _instance;
  FcmService._();

  static const _kTokenKey = 'fcm_device_token';
  bool _firebaseReady = false;

  bool get isReady => _firebaseReady;

  /// 앱 시작 시 main()에서 한 번 호출.
  Future<void> initialize() async {
    if (kIsWeb) return; // web 미지원 (v1.0)
    if (!Platform.isAndroid && !Platform.isIOS) return;
    try {
      await Firebase.initializeApp();
      _firebaseReady = true;
      FirebaseMessaging.onBackgroundMessage(_backgroundMessageHandler);
      _wireForegroundHandlers();
    } catch (e) {
      // google-services.json / GoogleService-Info.plist 미배치 시 정상 경로.
      debugPrint('[FCM] init skipped (Firebase 콘솔 설정 필요): $e');
      _firebaseReady = false;
    }
  }

  void _wireForegroundHandlers() {
    // 토큰 자동 갱신 — 갱신될 때마다 BE에 재등록.
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      try {
        await _persistAndRegister(newToken);
      } catch (e) {
        debugPrint('[FCM] token refresh re-register failed: $e');
      }
    });
    // foreground 메시지 — 본 v1.0은 로그만. UI banner는 후속 PR.
    FirebaseMessaging.onMessage.listen((msg) {
      debugPrint(
          '[FCM] foreground msg: title=${msg.notification?.title} data=${msg.data}');
    });
  }

  /// 로그인 직후 호출. 권한 요청 + 토큰 획득 + BE 등록.
  Future<void> registerForCurrentUser() async {
    if (!_firebaseReady) return;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('[FCM] user denied notification permission');
        return;
      }
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      await _persistAndRegister(token);
    } catch (e) {
      debugPrint('[FCM] registerForCurrentUser failed: $e');
    }
  }

  Future<void> _persistAndRegister(String token) async {
    final platform = Platform.isIOS ? 'ios' : 'android';
    await ApiService().registerFcmToken(token, platform);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTokenKey, token);
  }

  /// 로그아웃·탈퇴 직전 호출. 마지막에 등록한 토큰을 BE에서 해제.
  Future<void> unregisterCurrent() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_kTokenKey);
    if (token == null || token.isEmpty) return;
    try {
      await ApiService().unregisterFcmToken(token);
    } catch (e) {
      debugPrint('[FCM] unregister failed (계속 진행): $e');
    } finally {
      await prefs.remove(_kTokenKey);
    }
  }
}

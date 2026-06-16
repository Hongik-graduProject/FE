// lib/services/auth_provider.dart
import 'package:flutter/foundation.dart';
import '../models/auth_model.dart';
import 'api_service.dart';
import 'fcm_service.dart';
import 'token_service.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  AuthStatus _status = AuthStatus.initial;
  User? _currentUser;
  String? _errorMessage;

  AuthStatus get status => _status;
  User? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == AuthStatus.loading;

  // 앱 시작 시 로그인 상태 확인
  Future<void> checkAuthStatus() async {
    final loggedIn = await TokenService.isLoggedIn();
    _status = loggedIn ? AuthStatus.authenticated : AuthStatus.unauthenticated;
    notifyListeners();
  }

  // 로그인
  Future<bool> login(String email, String password) async {
    _setLoading();
    try {
      final response = await _api.login(email: email, password: password);
      await TokenService.saveTokens(
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
      );
      _currentUser = response.user;
      // 우리 DB에 프로필 + 기본 폴더 생성(멱등). 실패해도 로그인은 막지 않는다.
      try {
        await _api.onboard(nickname: _safeNickname(response.user));
      } catch (_) {}
      // FCM 토큰 등록(권한 요청 포함). Firebase 미설정 환경에서는 skip된다.
      // 실패해도 로그인은 막지 않는다.
      FcmService().registerForCurrentUser();
      _status = AuthStatus.authenticated;
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  // 온보딩 nickname 규칙(2~20, 한글/영문/숫자)에 맞게 정제.
  String _safeNickname(User user) {
    var n = user.nickname.replaceAll(RegExp(r'[^가-힣a-zA-Z0-9]'), '');
    if (n.isEmpty) {
      n = user.email.split('@').first.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    }
    if (n.length < 2) n = 'user';
    if (n.length > 20) n = n.substring(0, 20);
    return n;
  }

  // 회원가입
  Future<bool> signup(String email, String password, {String? nickname}) async {
    _setLoading();
    try {
      await _api.signup(email: email, password: password, nickname: nickname);
      _status = AuthStatus.unauthenticated;
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  // 이메일 중복 확인
  Future<bool?> checkEmail(String email) async {
    try {
      return await _api.checkEmailAvailable(email);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  // 로그아웃
  Future<void> logout() async {
    // 1) FCM 토큰 해제 (네트워크 가능할 때만). 토큰이 BE에 남아있으면 다른 사람이
    //    같은 기기로 로그인했을 때 잘못된 사용자에게 푸시가 갈 수 있다.
    await FcmService().unregisterCurrent();
    // 2) BE 로그아웃 + 로컬 토큰 정리
    await _api.logout();
    _currentUser = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  // 회원 탈퇴
  Future<bool> deleteAccount(String password) async {
    _setLoading();
    try {
      await FcmService().unregisterCurrent();
      await _api.deleteAccount(password);
      _currentUser = null;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _setLoading() {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();
  }

  void _setError(String message) {
    _status = AuthStatus.error;
    _errorMessage = message;
    notifyListeners();
  }
}

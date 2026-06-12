// lib/services/auth_provider.dart
import 'package:flutter/foundation.dart';
import '../models/auth_model.dart';
import 'api_service.dart';
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
      _status = AuthStatus.authenticated;
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
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
    await _api.logout();
    _currentUser = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  // 회원 탈퇴
  Future<bool> deleteAccount(String password) async {
    _setLoading();
    try {
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

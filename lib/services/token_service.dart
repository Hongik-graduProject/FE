// lib/services/token_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

/// Token storage backed by SharedPreferences (works on web/macOS/mobile without
/// keychain entitlements or Web Crypto). Tokens are short-lived Supabase JWTs.
class TokenService {
  static Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  static Future<void> saveAccessToken(String token) async {
    final p = await _prefs;
    await p.setString(AppConstants.accessTokenKey, token);
  }

  static Future<void> saveRefreshToken(String token) async {
    final p = await _prefs;
    await p.setString(AppConstants.refreshTokenKey, token);
  }

  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    final p = await _prefs;
    await p.setString(AppConstants.accessTokenKey, accessToken);
    await p.setString(AppConstants.refreshTokenKey, refreshToken);
  }

  static Future<String?> getAccessToken() async {
    final p = await _prefs;
    return p.getString(AppConstants.accessTokenKey);
  }

  static Future<String?> getRefreshToken() async {
    final p = await _prefs;
    return p.getString(AppConstants.refreshTokenKey);
  }

  static Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  static Future<void> clearTokens() async {
    final p = await _prefs;
    await p.remove(AppConstants.accessTokenKey);
    await p.remove(AppConstants.refreshTokenKey);
  }
}

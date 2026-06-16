// lib/models/auth_model.dart

class User {
  // BE는 Supabase auth.users.id (UUID)를 문자열로 반환한다.
  final String id;
  final String email;
  final String nickname;

  User({required this.id, required this.email, required this.nickname});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: (json['email'] as String?) ?? '',
      // BE AuthUserDto.nickname은 user_metadata에 없으면 null일 수 있다.
      nickname: (json['nickname'] as String?) ?? '',
    );
  }
}

class LoginResponse {
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresIn;
  final User user;

  LoginResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresIn,
    required this.user,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'];
    return LoginResponse(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      tokenType: (json['token_type'] as String?) ?? 'bearer',
      expiresIn: (json['expires_in'] as num?)?.toInt() ?? 0,
      user: userJson != null
          ? User.fromJson(userJson as Map<String, dynamic>)
          : User(id: '', email: '', nickname: ''),
    );
  }
}

class SignupResponse {
  // BE는 Supabase user id (UUID)를 문자열로 반환한다.
  final String userId;
  final String email;
  final String? nickname;
  final String? createdAt;

  SignupResponse({
    required this.userId,
    required this.email,
    this.nickname,
    this.createdAt,
  });

  factory SignupResponse.fromJson(Map<String, dynamic> json) {
    return SignupResponse(
      userId: json['user_id'] as String,
      email: json['email'] as String,
      // nickname/created_at은 BE에서 null일 수 있다(NON_NULL로 누락 가능).
      nickname: json['nickname'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }
}

/// BE 표준 에러 응답: { "status": "error", "message": "...", "error": "<CODE>" }
/// 코드는 `error` 필드(문자열, ErrorCode.name), 메시지는 `message` 필드다.
class ApiError {
  final String code;
  final String message;

  ApiError({required this.code, required this.message});

  factory ApiError.fromJson(Map<String, dynamic> json) {
    return ApiError(
      code: (json['error'] as String?) ?? 'UNKNOWN',
      message: (json['message'] as String?) ?? '알 수 없는 오류가 발생했습니다',
    );
  }
}

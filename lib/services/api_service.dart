// lib/services/api_service.dart
import 'package:dio/dio.dart';
import '../utils/constants.dart';
import '../models/auth_model.dart';
import '../models/analysis_model.dart';
import '../models/folder_model.dart';
import 'token_service.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  late final Dio _dio;

  void init() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));

    // 요청 인터셉터: Access Token 자동 주입 + 401 시 자동 갱신
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Public API가 아니면 토큰 주입
        if (!_isPublicEndpoint(options.path)) {
          final token = await TokenService.getAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        // 401 AUTH_EXPIRED → 자동 토큰 갱신 후 재요청
        if (error.response?.statusCode == 401) {
          final errorCode = error.response?.data?['error']?['code'];
          if (errorCode == 'AUTH_EXPIRED') {
            final refreshed = await _refreshToken();
            if (refreshed) {
              // 새 토큰으로 원래 요청 재시도
              final token = await TokenService.getAccessToken();
              final opts = error.requestOptions;
              opts.headers['Authorization'] = 'Bearer $token';
              try {
                final response = await _dio.fetch(opts);
                return handler.resolve(response);
              } catch (e) {
                return handler.next(error);
              }
            }
          }
        }
        handler.next(error);
      },
    ));
  }

  bool _isPublicEndpoint(String path) {
    const publicPaths = [
      '/auth/signup',
      '/auth/login',
      '/auth/refresh',
      '/auth/check-email',
    ];
    return publicPaths.any((p) => path.contains(p));
  }

  Future<bool> _refreshToken() async {
    try {
      final refreshToken = await TokenService.getRefreshToken();
      if (refreshToken == null) return false;

      final response = await _dio.post('/auth/refresh', data: {
        'refresh_token': refreshToken,
      });

      if (response.statusCode == 200) {
        final newAccessToken = response.data['data']['access_token'];
        await TokenService.saveAccessToken(newAccessToken);
        return true;
      }
      return false;
    } catch (e) {
      await TokenService.clearTokens();
      return false;
    }
  }

  // ──────────────────────────────────────────
  // 인증 API
  // ──────────────────────────────────────────

  /// 2-1. 회원가입
  Future<SignupResponse> signup({
    required String email,
    required String password,
    String? nickname,
  }) async {
    try {
      final body = {
        'email': email,
        'password': password,
        if (nickname != null && nickname.isNotEmpty) 'nickname': nickname,
      };
      final response = await _dio.post('/auth/signup', data: body);
      return SignupResponse.fromJson(response.data['data']);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// 2-2. 로그인
  Future<LoginResponse> login({
    required String email,
    required String password,
  }) async {
    // 테스트 계정 (백엔드 없이 화면 확인용)
    if (email == 'test@test.com' && password == 'Test1234') {
      return LoginResponse(
        accessToken: 'mock_access_token',
        refreshToken: 'mock_refresh_token',
        tokenType: 'Bearer',
        expiresIn: 3600,
        user: User(id: 1, email: email, nickname: '테스트유저'),
      );
    }
    try {
      final response = await _dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });
      return LoginResponse.fromJson(response.data['data']);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// 2-4. 로그아웃
  Future<void> logout() async {
    try {
      final refreshToken = await TokenService.getRefreshToken();
      await _dio.post('/auth/logout', data: {'refresh_token': refreshToken});
    } catch (_) {
      // 서버 오류여도 로컬 토큰은 반드시 삭제
    } finally {
      await TokenService.clearTokens();
    }
  }

  /// 2-5. 이메일 중복 확인
  Future<bool> checkEmailAvailable(String email) async {
    try {
      final response = await _dio.get('/auth/check-email',
          queryParameters: {'email': email});
      return response.data['data']['available'] as bool;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// 2-6. 회원 탈퇴
  Future<void> deleteAccount(String password) async {
    try {
      await _dio.delete('/auth/account', data: {'password': password});
      await TokenService.clearTokens();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ──────────────────────────────────────────
  // 폴더 API (W-04)
  // ──────────────────────────────────────────

  /// W-04: 폴더 목록 조회
  Future<FoldersResponse> getFolders() async {
    return FoldersResponse.fromJson({
      'data': {
        'folders': [
          {'id': 0, 'name': '기본 폴더', 'color': '#9CA3AF', 'type': 'default', 'item_count': 5, 'unread_disclosure_count': 1, 'order': 0},
          {'id': 1, 'name': '반도체 관련주', 'color': '#4A90D9', 'type': 'custom', 'item_count': 8, 'unread_disclosure_count': 3, 'order': 1},
          {'id': 2, 'name': '바이오', 'color': '#16A34A', 'type': 'custom', 'item_count': 4, 'unread_disclosure_count': 0, 'order': 2},
          {'id': 3, 'name': '방산주', 'color': '#EF4444', 'type': 'custom', 'item_count': 3, 'unread_disclosure_count': 1, 'order': 3},
          {'id': 4, 'name': '2차전지', 'color': '#8B5CF6', 'type': 'custom', 'item_count': 6, 'unread_disclosure_count': 0, 'order': 4},
        ],
        'total_unread_count': 5,
      }
    });
    // 백엔드 연동 시 목 데이터 제거 후 아래 사용:
    // try {
    //   final response = await _dio.get('/folders');
    //   return FoldersResponse.fromJson(response.data);
    // } on DioException catch (e) {
    //   throw _handleError(e);
    // }
  }

  /// W-05: 폴더 내 종목 목록 조회
  Future<FolderItemsResponse> getFolderItems(int folderId) async {
    const mock = {
      0: [
        {'id': 101, 'ticker': '005930', 'name': '삼성전자',       'current_price': 72000,  'change_rate': 1.52,  'change_amount': 1100,  'unread_disclosure_count': 1},
        {'id': 102, 'ticker': '000660', 'name': 'SK하이닉스',     'current_price': 185000, 'change_rate': -0.81, 'change_amount': -1500, 'unread_disclosure_count': 0},
        {'id': 103, 'ticker': '035420', 'name': 'NAVER',          'current_price': 195000, 'change_rate': 0.52,  'change_amount': 1000,  'unread_disclosure_count': 0},
        {'id': 104, 'ticker': '035720', 'name': '카카오',          'current_price': 47500,  'change_rate': -1.04, 'change_amount': -500,  'unread_disclosure_count': 0},
        {'id': 105, 'ticker': '373220', 'name': 'LG에너지솔루션', 'current_price': 380000, 'change_rate': 2.16,  'change_amount': 8000,  'unread_disclosure_count': 0},
      ],
      1: [
        {'id': 201, 'ticker': '005930', 'name': '삼성전자',   'current_price': 72000,  'change_rate': 1.52,  'change_amount': 1100,  'unread_disclosure_count': 2},
        {'id': 202, 'ticker': '000660', 'name': 'SK하이닉스', 'current_price': 185000, 'change_rate': -0.81, 'change_amount': -1500, 'unread_disclosure_count': 1},
        {'id': 203, 'ticker': '042700', 'name': '한미반도체', 'current_price': 92500,  'change_rate': 3.11,  'change_amount': 2800,  'unread_disclosure_count': 0},
        {'id': 204, 'ticker': '058470', 'name': '리노공업',   'current_price': 187500, 'change_rate': 1.08,  'change_amount': 2000,  'unread_disclosure_count': 0},
        {'id': 205, 'ticker': '000990', 'name': 'DB하이텍',   'current_price': 63200,  'change_rate': 2.43,  'change_amount': 1500,  'unread_disclosure_count': 0},
        {'id': 206, 'ticker': '403870', 'name': 'HPSP',       'current_price': 31500,  'change_rate': -0.63, 'change_amount': -200,  'unread_disclosure_count': 0},
        {'id': 207, 'ticker': '357780', 'name': '솔브레인',   'current_price': 248000, 'change_rate': 0.81,  'change_amount': 2000,  'unread_disclosure_count': 0},
        {'id': 208, 'ticker': '030530', 'name': '원익IPS',    'current_price': 29800,  'change_rate': -1.65, 'change_amount': -500,  'unread_disclosure_count': 0},
      ],
      2: [
        {'id': 301, 'ticker': '207940', 'name': '삼성바이오로직스', 'current_price': 870000, 'change_rate': 1.40, 'change_amount': 12000, 'unread_disclosure_count': 0},
        {'id': 302, 'ticker': '068270', 'name': '셀트리온',         'current_price': 195000, 'change_rate': 4.50, 'change_amount': 8500,  'unread_disclosure_count': 0},
        {'id': 303, 'ticker': '000100', 'name': '유한양행',         'current_price': 71400,  'change_rate': -0.42,'change_amount': -300,  'unread_disclosure_count': 0},
        {'id': 304, 'ticker': '128940', 'name': '한미약품',         'current_price': 325000, 'change_rate': 2.22, 'change_amount': 7000,  'unread_disclosure_count': 0},
      ],
      3: [
        {'id': 401, 'ticker': '012450', 'name': '한화에어로스페이스', 'current_price': 725000, 'change_rate': 5.47, 'change_amount': 37500, 'unread_disclosure_count': 1},
        {'id': 402, 'ticker': '079550', 'name': 'LIG넥스원',          'current_price': 215000, 'change_rate': 3.37, 'change_amount': 7000,  'unread_disclosure_count': 0},
        {'id': 403, 'ticker': '064350', 'name': '현대로템',            'current_price': 68500,  'change_rate': 2.39, 'change_amount': 1600,  'unread_disclosure_count': 0},
      ],
      4: [
        {'id': 501, 'ticker': '373220', 'name': 'LG에너지솔루션', 'current_price': 380000, 'change_rate': 2.16,  'change_amount': 8000,  'unread_disclosure_count': 0},
        {'id': 502, 'ticker': '006400', 'name': '삼성SDI',        'current_price': 295000, 'change_rate': -1.34, 'change_amount': -4000, 'unread_disclosure_count': 0},
        {'id': 503, 'ticker': '096770', 'name': 'SK이노베이션',   'current_price': 115000, 'change_rate': -0.86, 'change_amount': -1000, 'unread_disclosure_count': 0},
        {'id': 504, 'ticker': '003670', 'name': '포스코퓨처엠',   'current_price': 183500, 'change_rate': 1.38,  'change_amount': 2500,  'unread_disclosure_count': 0},
        {'id': 505, 'ticker': '086520', 'name': '에코프로',        'current_price': 92000,  'change_rate': -2.86, 'change_amount': -2700, 'unread_disclosure_count': 0},
        {'id': 506, 'ticker': '247540', 'name': '에코프로비엠',    'current_price': 125000, 'change_rate': 1.22,  'change_amount': 1500,  'unread_disclosure_count': 0},
      ],
    };
    return FolderItemsResponse.fromJson({
      'data': {'items': mock[folderId] ?? []},
    });
    // 백엔드 연동 시:
    // try {
    //   final response = await _dio.get('/folders/$folderId/items');
    //   return FolderItemsResponse.fromJson(response.data);
    // } on DioException catch (e) {
    //   throw _handleError(e);
    // }
  }

  // ──────────────────────────────────────────
  // 분석 API (W-15, W-16)
  // ──────────────────────────────────────────

  /// W-15: 종목 ThemeSense 테마 분류 조회
  Future<ThemesResponse> getStockThemes(String ticker) async {
    // 목 데이터 (백엔드 연동 전)
    if (ticker == '005930') {
      return ThemesResponse.fromJson({
        'data': {
          'ticker': '005930',
          'name': '삼성전자',
          'themes': [
            {
              'id': 1,
              'name': 'HBM/메모리',
              'probability': 0.9234,
              'rank': 1,
              'is_primary': true,
              'top_sensitive_metrics': [
                {'code': 'op_margin', 'display_name': '영업이익률', 'beta': 0.84, 'rank': 1},
                {'code': 'sales_growth', 'display_name': '매출증가율', 'beta': 0.71, 'rank': 2},
                {'code': 'foreign_ratio', 'display_name': '외국인비중', 'beta': 0.42, 'rank': 3},
                {'code': 'per', 'display_name': 'PER', 'beta': -0.38, 'rank': 4},
                {'code': 'volatility', 'display_name': '변동성', 'beta': -0.29, 'rank': 5},
              ],
            },
            {'id': 3, 'name': 'AI인프라', 'probability': 0.7821, 'rank': 2, 'is_primary': false},
            {'id': 7, 'name': '파운드리', 'probability': 0.4112, 'rank': 3, 'is_primary': false},
          ],
          'model_version': 'themesense-stage1-v1.0',
          'predicted_at': '2026-05-10T03:00:00Z',
        }
      });
    }
    // 테마 미분류 예시 (other ticker)
    try {
      final response = await _dio.get('/analysis/$ticker/themes');
      return ThemesResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// W-15: 종목 분석 보고서 목록 조회
  Future<ReportsResponse> getStockReports(
    String ticker, {
    int page = 1,
    int size = 20,
  }) async {
    // 목 데이터 (백엔드 연동 전)
    if (ticker == '005930') {
      return ReportsResponse.fromJson({
        'data': {
          'ticker': '005930',
          'reports': [
            {
              'id': 501,
              'title': '2025Q4 실적 분석',
              'summary': '컨센서스 상회. HBM 수주 호조.',
              'applied_theme': {'id': 1, 'name': 'HBM/메모리'},
              'expected_car': 6.8,
              'is_read': false,
              'generated_at': '2026-04-30T18:00:00Z',
            },
            {
              'id': 500,
              'title': '2025Q3 실적 분석',
              'summary': '컨센서스 하회. 모바일 부진.',
              'applied_theme': {'id': 3, 'name': 'AI인프라'},
              'expected_car': -3.2,
              'is_read': true,
              'generated_at': '2026-01-28T18:00:00Z',
            },
            {
              'id': 499,
              'title': '2025Q2 실적 분석',
              'summary': '전년 대비 매출 성장.',
              'applied_theme': {'id': 1, 'name': 'HBM/메모리'},
              'expected_car': 2.1,
              'is_read': true,
              'generated_at': '2025-07-28T18:00:00Z',
            },
          ],
          'pagination': {
            'page': 1,
            'size': 20,
            'total_count': 3,
            'total_pages': 1,
            'has_next': false,
          },
        }
      });
    }
    try {
      final response = await _dio.get(
        '/analysis/$ticker/reports',
        queryParameters: {'sort': 'latest', 'page': page, 'size': size},
      );
      return ReportsResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// W-16: 분석 보고서 상세 조회 (진입 시 자동 read 처리)
  Future<ReportDetail> getReportDetail(int reportId) async {
    if (reportId == 501) {
      return ReportDetail.fromJson({
        'data': {
          'id': 501,
          'ticker': '005930',
          'name': '삼성전자',
          'title': '2025Q4 실적 분석',
          'applied_theme': {'id': 1, 'name': 'HBM/메모리', 'routing_score': 0.88},
          'source_disclosure': {
            'id': 'DART_20260130_001',
            'title': '2025년 사업보고서',
            'filed_at': '2026-01-30T18:00:00Z',
            'dart_url': 'https://dart.fss.or.kr/dsaf001/main.do?rcpNo=20260130000001',
          },
          'summary':
              'HBM/메모리 테마에서 영업이익률 개선이 가장 큰 양의 기여 (+2.83%p). 2025Q4 매출 78조원 (YoY +8.3%), 영업이익 9.2조원으로 컨센서스 상회. 종합 예상 CAR +6.8%.',
          'expected_car': 6.8,
          'car_lower': 3.2,
          'car_upper': 10.4,
          'metric_contributions': [
            {'metric_code': 'op_margin', 'display_name': '영업이익률', 'beta': 0.84, 'raw_value': '11.79% (YoY +1.2%p)', 'delta': 1.2, 'contribution': 2.83},
            {'metric_code': 'sales_growth', 'display_name': '매출증가율', 'beta': 0.71, 'raw_value': '+8.3%', 'delta': 8.3, 'contribution': 1.97},
            {'metric_code': 'foreign_ratio', 'display_name': '외국인비중', 'beta': 0.42, 'raw_value': '52.4%', 'delta': 2.9, 'contribution': 1.21},
            {'metric_code': 'per', 'display_name': 'PER', 'beta': -0.38, 'raw_value': '12.5', 'delta': 0.8, 'contribution': -0.42},
            {'metric_code': 'volatility', 'display_name': '변동성', 'beta': -0.29, 'raw_value': '22.4%', 'delta': -1.8, 'contribution': 0.21},
          ],
          'key_findings': [
            '반도체 부문 영업이익 전분기 대비 32% 증가',
            'HBM3E 양산 본격화로 고부가가치 매출 확대',
            '외국인 매수세 유입 (테마 민감도 β=+0.42 구간)',
          ],
          'metrics': {'revenue': 78000000000000, 'operating_profit': 9200000000000, 'net_income': 6800000000000, 'yoy_revenue_growth': 8.3, 'yoy_op_growth': 12.1},
          'is_read': true,
          'generated_at': '2026-01-30T18:00:00Z',
        }
      });
    }
    if (reportId == 500) {
      return ReportDetail.fromJson({
        'data': {
          'id': 500,
          'ticker': '005930',
          'name': '삼성전자',
          'title': '2025Q3 실적 분석',
          'applied_theme': {'id': 3, 'name': 'AI인프라', 'routing_score': 0.71},
          'source_disclosure': {
            'id': 'DART_20251028_001',
            'title': '2025년 3분기 보고서',
            'filed_at': '2025-10-28T18:00:00Z',
            'dart_url': 'https://dart.fss.or.kr/dsaf001/main.do?rcpNo=20251028000001',
          },
          'summary':
              'AI인프라 테마에서 PER 부담이 가장 큰 음의 기여 (-1.14%p). 2025Q3 매출 70조원으로 컨센서스 하회. 모바일 부문 부진이 주요 원인. 종합 예상 CAR -3.2%.',
          'expected_car': -3.2,
          'car_lower': -6.1,
          'car_upper': -0.3,
          'metric_contributions': [
            {'metric_code': 'per', 'display_name': 'PER', 'beta': -0.38, 'raw_value': '18.2', 'delta': 3.2, 'contribution': -1.14},
            {'metric_code': 'op_margin', 'display_name': '영업이익률', 'beta': 0.84, 'raw_value': '8.2% (YoY -2.1%p)', 'delta': -2.1, 'contribution': -1.00},
            {'metric_code': 'volatility', 'display_name': '변동성', 'beta': -0.29, 'raw_value': '28.1%', 'delta': 3.4, 'contribution': -0.98},
            {'metric_code': 'foreign_ratio', 'display_name': '외국인비중', 'beta': 0.42, 'raw_value': '49.8%', 'delta': -1.1, 'contribution': -0.36},
            {'metric_code': 'sales_growth', 'display_name': '매출증가율', 'beta': 0.71, 'raw_value': '+1.2%', 'delta': 1.2, 'contribution': 0.28},
          ],
          'key_findings': [
            '모바일 부문 영업이익 전분기 대비 18% 감소',
            'PER 고평가 구간 진입으로 테마 민감도 역방향 기여',
            '변동성 확대로 리스크 지표 악화',
          ],
          'metrics': {'revenue': 70000000000000, 'operating_profit': 5700000000000, 'net_income': 4200000000000, 'yoy_revenue_growth': 1.2, 'yoy_op_growth': -18.3},
          'is_read': true,
          'generated_at': '2025-10-28T18:00:00Z',
        }
      });
    }
    try {
      final response = await _dio.get('/analysis/reports/$reportId');
      return ReportDetail.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // 에러 핸들링
  String _handleError(DioException e) {
    if (e.response != null) {
      final errorData = e.response?.data?['error'];
      if (errorData != null) {
        final code = errorData['code'] ?? '';
        final msg = errorData['message'] ?? '';

        switch (code) {
          case 'DUPLICATE':
            return '이미 가입된 이메일입니다';
          case 'AUTH_INVALID':
            return '이메일 또는 비밀번호가 올바르지 않습니다';
          case 'AUTH_EXPIRED':
            return '세션이 만료되었습니다. 다시 로그인해 주세요';
          case 'INVALID_PARAM':
            return msg.isNotEmpty ? msg : '입력 정보를 확인해 주세요';
          case 'RATE_LIMIT':
            return '잠시 후 다시 시도해 주세요';
          default:
            return msg.isNotEmpty ? msg : '오류가 발생했습니다';
        }
      }
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return '서버 연결이 지연되고 있습니다. 네트워크를 확인해 주세요';
    }
    return '네트워크 오류가 발생했습니다';
  }
}

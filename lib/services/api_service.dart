// lib/services/api_service.dart
import 'package:dio/dio.dart';
import '../utils/constants.dart';
import '../models/auth_model.dart';
import '../models/analysis_model.dart';
import '../models/folder_model.dart';
import '../models/notification_model.dart';
import '../models/stock_model.dart';
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
        // 401 AUTH_EXPIRED → 자동 토큰 갱신 후 재요청.
        // BE 에러 JSON은 코드를 `error` 필드(문자열)에 담는다.
        if (error.response?.statusCode == 401) {
          final errorCode = error.response?.data is Map
              ? error.response?.data['error']
              : null;
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

  /// 온보딩: 로그인 후 우리 DB에 프로필 + 기본 폴더 생성 (멱등).
  Future<void> onboard({required String nickname}) async {
    try {
      await _dio.post('/users', data: {'nickname': nickname});
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
    try {
      final response = await _dio.get('/folders');
      return FoldersResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// W-05: 폴더 내 종목 목록 조회
  Future<FolderItemsResponse> getFolderItems(int folderId) async {
    try {
      final response = await _dio.get('/folders/$folderId/items');
      return FolderItemsResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ──────────────────────────────────────────
  // 폴더 관리 API (W-06)
  // ──────────────────────────────────────────

  /// §3-2 POST /folders — 새 폴더 생성. default folder 외 추가.
  Future<void> createFolder(FolderCreateRequest req) async {
    try {
      await _dio.post('/folders', data: req.toJson());
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// §3-3 PATCH /folders/{folder_id} — name·color 수정. default 폴더는 403.
  Future<void> updateFolder(int folderId, FolderUpdateRequest req) async {
    try {
      await _dio.patch('/folders/$folderId', data: req.toJson());
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// §3-4 DELETE /folders/{folder_id} — default 폴더는 403.
  Future<void> deleteFolder(int folderId) async {
    try {
      await _dio.delete('/folders/$folderId');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// §3-5 PUT /folders/order — folder_ids 배열의 인덱스를 displayOrder로 일괄 적용.
  Future<void> reorderFolders(List<int> folderIds) async {
    try {
      await _dio.put(
        '/folders/order',
        data: ReorderFoldersRequest(folderIds).toJson(),
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// §3-8 PATCH /folders/items/{item_id} — memo / avg_price 갱신.
  Future<void> updateFavorite(int itemId, FavoriteUpdateRequest req) async {
    try {
      await _dio.patch('/folders/items/$itemId', data: req.toJson());
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// §3-10 DELETE /folders/items/{item_id} — 즐겨찾기 hard delete.
  Future<void> deleteFavorite(int itemId) async {
    try {
      await _dio.delete('/folders/items/$itemId');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// §3-9 PUT /folders/items/move — 다른 폴더로 이동. 대상에 동일 ticker 있으면 409.
  Future<void> moveFavorite(int itemId, int toFolderId) async {
    try {
      await _dio.put(
        '/folders/items/move',
        data: FavoriteMoveRequest(itemId: itemId, toFolderId: toFolderId)
            .toJson(),
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// §3-7 POST /folders/items — 종목을 폴더에 즐겨찾기 등록.
  Future<void> addFavorite(int folderId, String ticker) async {
    try {
      await _dio.post(
        '/folders/items',
        data: {'folder_id': folderId, 'ticker': ticker},
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ──────────────────────────────────────────
  // 종목 검색 / 상세 API (W-08·09·10·11·12·13·14)
  // ──────────────────────────────────────────

  /// §4-1 GET /stocks/search?q= — 통합 검색.
  Future<StockSearchResponse> searchStocks(String q,
      {int page = 1, int size = 20}) async {
    try {
      final r = await _dio.get('/stocks/search',
          queryParameters: {'q': q, 'page': page, 'size': size});
      return StockSearchResponse.fromJson(r.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// §4-2 GET /stocks/autocomplete?q=
  Future<StockAutocompleteResponse> autocompleteStocks(String q) async {
    try {
      final r = await _dio
          .get('/stocks/autocomplete', queryParameters: {'q': q});
      return StockAutocompleteResponse.fromJson(r.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// §4-3 GET /stocks/recent — 최근 검색어 목록.
  Future<RecentSearchResponse> getRecentSearches() async {
    try {
      final r = await _dio.get('/stocks/recent');
      return RecentSearchResponse.fromJson(r.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// §4-4 POST /stocks/recent — 검색어 저장 (UPSERT).
  Future<void> addRecentSearch(String keyword) async {
    try {
      await _dio.post('/stocks/recent', data: {'keyword': keyword});
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// §4-5 DELETE /stocks/recent?keyword= — 단건 또는 전체 삭제.
  Future<void> deleteRecentSearch({String? keyword}) async {
    try {
      await _dio.delete('/stocks/recent',
          queryParameters: keyword == null ? null : {'keyword': keyword});
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// §4-6 GET /stocks/ranking — 인기 순위.
  Future<StockRankingResponse> getStockRanking() async {
    try {
      final r = await _dio.get('/stocks/ranking');
      return StockRankingResponse.fromJson(r.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// §4-7 GET /stocks/{ticker} — 종목 상세.
  Future<StockDetailResponse> getStockDetail(String ticker) async {
    try {
      final r = await _dio.get('/stocks/$ticker');
      return StockDetailResponse.fromJson(r.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// §4-8 GET /stocks/{ticker}/news.
  Future<StockNewsResponse> getStockNews(String ticker) async {
    try {
      final r = await _dio.get('/stocks/$ticker/news');
      return StockNewsResponse.fromJson(r.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// §4-9 GET /stocks/{ticker}/finance.
  Future<StockFinanceResponse> getStockFinance(String ticker) async {
    try {
      final r = await _dio.get('/stocks/$ticker/finance');
      return StockFinanceResponse.fromJson(r.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// §4-10 GET /stocks/{ticker}/disclosures.
  Future<StockDisclosuresResponse> getStockDisclosures(String ticker,
      {int page = 1, int size = 20}) async {
    try {
      final r = await _dio.get('/stocks/$ticker/disclosures',
          queryParameters: {'page': page, 'size': size});
      return StockDisclosuresResponse.fromJson(r.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ──────────────────────────────────────────
  // 분석 API (W-15, W-16)
  // ──────────────────────────────────────────

  /// W-15: 종목 ThemeSense 테마 분류 조회
  Future<ThemesResponse> getStockThemes(String ticker) async {
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
    try {
      final response = await _dio.get('/analysis/reports/$reportId');
      return ReportDetail.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ──────────────────────────────────────────
  // 알림 API (W-17)
  // ──────────────────────────────────────────

  /// §6-1 GET /notifications — 페이지네이션 + unread_count 동봉.
  Future<NotificationsResponse> getNotifications({
    int page = 1,
    int size = 20,
    bool? isRead,
    String? type,
  }) async {
    try {
      final query = <String, dynamic>{'page': page, 'size': size};
      if (isRead != null) query['is_read'] = isRead;
      if (type != null && type.isNotEmpty) query['type'] = type;
      final response =
          await _dio.get('/notifications', queryParameters: query);
      return NotificationsResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// §6-2 PATCH /notifications/{id}/read — 멱등.
  Future<void> markNotificationRead(int notificationId) async {
    try {
      await _dio.patch('/notifications/$notificationId/read');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// §6-3 PATCH /notifications/read-all — ticker 지정 시 해당 종목만, null이면 전체.
  Future<int> markAllNotificationsRead({String? ticker}) async {
    try {
      final body = <String, dynamic>{};
      if (ticker != null && ticker.isNotEmpty) body['ticker'] = ticker;
      final response = await _dio.patch(
        '/notifications/read-all',
        data: body.isEmpty ? null : body,
      );
      final data = response.data['data'] as Map<String, dynamic>?;
      return (data?['read_count'] as num?)?.toInt() ?? 0;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// §6-4 POST /notifications/fcm-token — UPSERT 멱등.
  /// platform ∈ {"ios","android"}. firebase_messaging의 token이 갱신될 때마다 호출.
  Future<void> registerFcmToken(String deviceToken, String platform) async {
    try {
      await _dio.post(
        '/notifications/fcm-token',
        data: FcmTokenRegisterRequest(
                deviceToken: deviceToken, platform: platform)
            .toJson(),
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// §6-5 DELETE /notifications/fcm-token — body로 device_token 전달. 로그아웃 시 호출.
  Future<void> unregisterFcmToken(String deviceToken) async {
    try {
      await _dio.delete(
        '/notifications/fcm-token',
        data: {'device_token': deviceToken},
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // 에러 핸들링
  // BE 표준 에러 응답: { "status":"error", "message":"...", "error":"<CODE>" }
  // 코드는 `error` 필드(문자열), 메시지는 `message` 필드.
  String _handleError(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final code = (data['error'] as String?) ?? '';
      final msg = (data['message'] as String?) ?? '';
      if (code.isNotEmpty || msg.isNotEmpty) {
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

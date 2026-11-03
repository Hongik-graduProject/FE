// lib/models/notification_model.dart
//
// BE §6 알림 도메인 — application.yml의 SNAKE_CASE 전략을 따른다.

/// BE §6-1: GET /notifications 응답 항목.
/// type ∈ { "disclosure_report", "new_disclosure" }.
class NotificationItem {
  final int id;
  final String type;
  final String title;
  final String? body;
  final String? ticker;
  final String? stockName;
  final int? reportId;
  final int? disclosureId;
  final bool isRead;
  final String createdAt;
  // report_id 가 있을 때만 BE가 채운다 (보고서의 예상 CAR %, 적용 테마명).
  final double? expectedCar;
  final String? appliedThemeName;

  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    this.body,
    this.ticker,
    this.stockName,
    this.reportId,
    this.disclosureId,
    required this.isRead,
    required this.createdAt,
    this.expectedCar,
    this.appliedThemeName,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) =>
      NotificationItem(
        id: json['id'] as int,
        type: json['type'] as String,
        title: json['title'] as String? ?? '',
        body: json['body'] as String?,
        ticker: json['ticker'] as String?,
        stockName: json['stock_name'] as String?,
        reportId: (json['report_id'] as num?)?.toInt(),
        disclosureId: (json['disclosure_id'] as num?)?.toInt(),
        isRead: json['is_read'] as bool? ?? false,
        createdAt: json['created_at'] as String? ?? '',
        expectedCar: (json['expected_car'] as num?)?.toDouble(),
        appliedThemeName: json['applied_theme_name'] as String?,
      );

  NotificationItem copyWith({bool? isRead}) => NotificationItem(
        id: id,
        type: type,
        title: title,
        body: body,
        ticker: ticker,
        stockName: stockName,
        reportId: reportId,
        disclosureId: disclosureId,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
        expectedCar: expectedCar,
        appliedThemeName: appliedThemeName,
      );
}

class NotificationPagination {
  final int page;
  final int size;
  final int totalCount;
  final int totalPages;
  final bool hasNext;

  const NotificationPagination({
    required this.page,
    required this.size,
    required this.totalCount,
    required this.totalPages,
    required this.hasNext,
  });

  factory NotificationPagination.fromJson(Map<String, dynamic> json) =>
      NotificationPagination(
        page: json['page'] as int,
        size: json['size'] as int,
        totalCount: json['total_count'] as int,
        totalPages: json['total_pages'] as int,
        hasNext: json['has_next'] as bool,
      );
}

/// BE §6-1: GET /notifications 응답.
class NotificationsResponse {
  final List<NotificationItem> notifications;
  final int unreadCount;
  final NotificationPagination pagination;

  const NotificationsResponse({
    required this.notifications,
    required this.unreadCount,
    required this.pagination,
  });

  factory NotificationsResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return NotificationsResponse(
      notifications: (data['notifications'] as List? ?? [])
          .map((n) => NotificationItem.fromJson(n as Map<String, dynamic>))
          .toList(),
      unreadCount: (data['unread_count'] as num?)?.toInt() ?? 0,
      pagination: NotificationPagination.fromJson(
          data['pagination'] as Map<String, dynamic>),
    );
  }
}

/// BE §6-4: POST /notifications/fcm-token 본문. platform은 "ios" 또는 "android".
class FcmTokenRegisterRequest {
  final String deviceToken;
  final String platform;

  const FcmTokenRegisterRequest(
      {required this.deviceToken, required this.platform});

  Map<String, dynamic> toJson() =>
      {'device_token': deviceToken, 'platform': platform};
}

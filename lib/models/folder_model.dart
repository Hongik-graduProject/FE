// lib/models/folder_model.dart
//
// BE는 application.yml에서 Jackson SNAKE_CASE 전역 적용.
// 요청·응답 키는 모두 snake_case로 맞춘다.

class FolderArgs {
  final int id;
  final String name;
  final String color;

  const FolderArgs({required this.id, required this.name, required this.color});
}

class FolderItem {
  final int id;
  final String ticker;
  final String name;
  // BE FavoriteItemResponse: KRX 시세는 키가 없으면 null이 올 수 있다.
  final int? currentPrice;
  final double? changeRate;
  final int? changeAmount;
  final int unreadDisclosureCount;
  final String? memo;
  final int? avgPrice;
  final AnalysisSummary? analysisSummary;

  const FolderItem({
    required this.id,
    required this.ticker,
    required this.name,
    this.currentPrice,
    this.changeRate,
    this.changeAmount,
    required this.unreadDisclosureCount,
    this.memo,
    this.avgPrice,
    this.analysisSummary,
  });

  factory FolderItem.fromJson(Map<String, dynamic> json) => FolderItem(
        id: json['id'] as int,
        ticker: json['ticker'] as String,
        name: json['name'] as String,
        currentPrice: (json['current_price'] as num?)?.toInt(),
        changeRate: (json['change_rate'] as num?)?.toDouble(),
        changeAmount: (json['change_amount'] as num?)?.toInt(),
        unreadDisclosureCount: json['unread_disclosure_count'] as int? ?? 0,
        memo: json['memo'] as String?,
        avgPrice: (json['avg_price'] as num?)?.toInt(),
        analysisSummary: json['analysis_summary'] == null
            ? null
            : AnalysisSummary.fromJson(json['analysis_summary'] as Map<String, dynamic>),
      );
}

/// 관심종목별 최신 ThemeSense 분석 요약. 분석이 없으면 has_theme=false 이고 나머지는 null.
class AnalysisSummary {
  final bool hasTheme;
  final String? themeName;
  final int? latestReportId;
  final double? expectedCar;
  final String? summary;
  final DateTime? generatedAt;

  const AnalysisSummary({
    required this.hasTheme,
    this.themeName,
    this.latestReportId,
    this.expectedCar,
    this.summary,
    this.generatedAt,
  });

  factory AnalysisSummary.fromJson(Map<String, dynamic> json) => AnalysisSummary(
        hasTheme: json['has_theme'] as bool? ?? false,
        themeName: (json['applied_theme'] as Map<String, dynamic>?)?['name'] as String?,
        latestReportId: (json['latest_report_id'] as num?)?.toInt(),
        expectedCar: (json['expected_car'] as num?)?.toDouble(),
        summary: json['summary'] as String?,
        generatedAt: DateTime.tryParse(json['generated_at'] as String? ?? ''),
      );
}

/// BE §3-6: GET /folders/{id}/items 응답은 { data: { folder: {...}, items: [...] } }.
/// folder 헤더(brief)는 화면에서 아직 쓰지 않으므로 items만 파싱한다.
class FolderItemsResponse {
  final List<FolderItem> items;

  const FolderItemsResponse({required this.items});

  factory FolderItemsResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return FolderItemsResponse(
      items: (data['items'] as List? ?? [])
          .map((i) => FolderItem.fromJson(i as Map<String, dynamic>))
          .toList(),
    );
  }
}

class Folder {
  final int id;
  final String name;
  final String color;
  final String type;
  final int itemCount;
  final int unreadDisclosureCount;
  final int order;

  const Folder({
    required this.id,
    required this.name,
    required this.color,
    required this.type,
    required this.itemCount,
    required this.unreadDisclosureCount,
    required this.order,
  });

  factory Folder.fromJson(Map<String, dynamic> json) => Folder(
        id: json['id'] as int,
        name: json['name'] as String,
        color: json['color'] as String,
        type: json['type'] as String,
        itemCount: json['item_count'] as int,
        unreadDisclosureCount: json['unread_disclosure_count'] as int,
        order: json['order'] as int,
      );
}

/// BE §3-1: GET /folders 응답은 { data: { folders: [...] } }.
/// BE에는 total_unread_count 필드가 없으므로 folders의 unread 합으로 계산한다.
class FoldersResponse {
  final List<Folder> folders;

  const FoldersResponse({required this.folders});

  int get totalUnreadCount =>
      folders.fold(0, (sum, f) => sum + f.unreadDisclosureCount);

  factory FoldersResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    final list = (data['folders'] as List? ?? [])
        .map((f) => Folder.fromJson(f as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return FoldersResponse(folders: list);
  }
}

// ─── Request DTOs (W-06 폴더 관리) ────────────────────────────────────────────

/// BE §3-2: POST /folders 본문. color는 `^#[0-9A-Fa-f]{6}$` 검증을 통과해야 한다.
class FolderCreateRequest {
  final String name;
  final String color;

  const FolderCreateRequest({required this.name, required this.color});

  Map<String, dynamic> toJson() => {'name': name, 'color': color};
}

/// BE §3-3: PATCH /folders/{folder_id} 본문. name·color 모두 필수.
class FolderUpdateRequest {
  final String name;
  final String color;

  const FolderUpdateRequest({required this.name, required this.color});

  Map<String, dynamic> toJson() => {'name': name, 'color': color};
}

/// BE §3-5: PUT /folders/order 본문. SNAKE_CASE 전략으로 folderIds → folder_ids.
class ReorderFoldersRequest {
  final List<int> folderIds;

  const ReorderFoldersRequest(this.folderIds);

  Map<String, dynamic> toJson() => {'folder_ids': folderIds};
}

/// BE §3-8: PATCH /folders/items/{item_id} 본문. 둘 다 nullable.
class FavoriteUpdateRequest {
  final String? memo;
  final int? avgPrice;

  const FavoriteUpdateRequest({this.memo, this.avgPrice});

  Map<String, dynamic> toJson() {
    final body = <String, dynamic>{};
    if (memo != null) body['memo'] = memo;
    if (avgPrice != null) body['avg_price'] = avgPrice;
    return body;
  }
}

/// BE §3-9: PUT /folders/items/move 본문.
class FavoriteMoveRequest {
  final int itemId;
  final int toFolderId;

  const FavoriteMoveRequest({required this.itemId, required this.toFolderId});

  Map<String, dynamic> toJson() =>
      {'item_id': itemId, 'to_folder_id': toFolderId};
}

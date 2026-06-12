// lib/models/folder_model.dart

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
  final int currentPrice;
  final double changeRate;
  final int changeAmount;
  final int unreadDisclosureCount;

  const FolderItem({
    required this.id,
    required this.ticker,
    required this.name,
    required this.currentPrice,
    required this.changeRate,
    required this.changeAmount,
    required this.unreadDisclosureCount,
  });

  factory FolderItem.fromJson(Map<String, dynamic> json) => FolderItem(
        id: json['id'] as int,
        ticker: json['ticker'] as String,
        name: json['name'] as String,
        currentPrice: json['current_price'] as int,
        changeRate: (json['change_rate'] as num).toDouble(),
        changeAmount: json['change_amount'] as int,
        unreadDisclosureCount: json['unread_disclosure_count'] as int,
      );
}

class FolderItemsResponse {
  final List<FolderItem> items;

  const FolderItemsResponse({required this.items});

  factory FolderItemsResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return FolderItemsResponse(
      items: (data['items'] as List)
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

class FoldersResponse {
  final List<Folder> folders;
  final int totalUnreadCount;

  const FoldersResponse({
    required this.folders,
    required this.totalUnreadCount,
  });

  factory FoldersResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    final list = (data['folders'] as List)
        .map((f) => Folder.fromJson(f as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return FoldersResponse(
      folders: list,
      totalUnreadCount: data['total_unread_count'] as int,
    );
  }
}

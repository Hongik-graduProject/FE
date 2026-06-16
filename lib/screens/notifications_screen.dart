// lib/screens/notifications_screen.dart — W-17 알림 화면
import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<NotificationsResponse> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiService().getNotifications();
  }

  void _reload() {
    setState(() {
      _future = ApiService().getNotifications();
    });
  }

  Future<void> _markRead(NotificationItem item) async {
    if (item.isRead) {
      _navigateFor(item);
      return;
    }
    try {
      await ApiService().markNotificationRead(item.id);
    } catch (_) {
      // 읽음 처리 실패해도 상세 이동은 계속한다.
    }
    if (!mounted) return;
    _navigateFor(item);
    // 목록 색상 갱신을 위해 백그라운드 reload (await X — UX 부드럽게).
    _reload();
  }

  void _navigateFor(NotificationItem item) {
    // 분석 보고서 알림이면 보고서 상세로, 새 공시 알림이면 (지금은 없는 disclosure 상세)
    // 대신 보고서가 있으면 보고서 상세로 이동, 그게 없으면 무동작.
    if (item.reportId != null) {
      Navigator.pushNamed(context, '/report', arguments: item.reportId);
    }
  }

  Future<void> _markAllRead() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final count = await ApiService().markAllNotificationsRead();
      messenger.showSnackBar(SnackBar(content: Text('알림 $count건을 읽음 처리했습니다')));
      _reload();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppConstants.backgroundColor),
      appBar: AppBar(
        title: const Text('알림'),
        actions: [
          TextButton(
            onPressed: _markAllRead,
            child: const Text('전체 읽음'),
          ),
        ],
      ),
      body: FutureBuilder<NotificationsResponse>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorBody(
              message: snapshot.error.toString(),
              onRetry: _reload,
            );
          }
          final items = snapshot.data!.notifications;
          if (items.isEmpty) {
            return const _EmptyBody();
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: Color(0xFFE5E7EB)),
              itemBuilder: (context, index) => _NotificationTile(
                item: items[index],
                onTap: () => _markRead(items[index]),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Tile ─────────────────────────────────────────────────────────────────────

class _NotificationTile extends StatelessWidget {
  final NotificationItem item;
  final VoidCallback onTap;

  const _NotificationTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isUnread = !item.isRead;
    final icon = _iconForType(item.type);

    return InkWell(
      onTap: onTap,
      child: Container(
        color: isUnread ? const Color(0xFFF1F7FF) : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: const Color(AppConstants.primaryColor)
                  .withValues(alpha: 0.12),
              radius: 18,
              child: Icon(icon,
                  size: 18, color: const Color(AppConstants.primaryColor)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                isUnread ? FontWeight.w700 : FontWeight.w600,
                            color: const Color(AppConstants.textPrimary),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isUnread)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 8, top: 4),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                    ],
                  ),
                  if (item.body != null && item.body!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.body!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(AppConstants.textSecondary),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    _formatRelative(item.createdAt),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'new_disclosure':
        return Icons.article_outlined;
      case 'disclosure_report':
      default:
        return Icons.assessment_outlined;
    }
  }

  String _formatRelative(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return '방금 전';
      if (diff.inHours < 1) return '${diff.inMinutes}분 전';
      if (diff.inDays < 1) return '${diff.inHours}시간 전';
      if (diff.inDays < 7) return '${diff.inDays}일 전';
      return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}

// ─── Empty / Error ────────────────────────────────────────────────────────────

class _EmptyBody extends StatelessWidget {
  const _EmptyBody();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_off_outlined,
              size: 48, color: Color(0xFFCBD5E1)),
          SizedBox(height: 12),
          Text('받은 알림이 없습니다',
              style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF))),
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBody({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 40, color: Color(0xFF9CA3AF)),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF6B7280))),
            const SizedBox(height: 16),
            TextButton(onPressed: onRetry, child: const Text('다시 시도')),
          ],
        ),
      ),
    );
  }
}

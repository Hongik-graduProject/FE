// lib/screens/notifications_screen.dart — 알림 탭 (Stitch _9)
import 'package:flutter/material.dart';

import '../models/notification_model.dart';
import '../services/api_service.dart';
import '../utils/design_tokens.dart';
import '../utils/format.dart';
import '../widgets/ds.dart';
import 'company/company_detail_screen.dart';
import 'main_shell.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const _tabIndex = 2; // MainShell 의 알림 탭 위치

  NotificationsResponse? _data;
  List<NotificationItem> _items = [];
  Object? _error;
  bool _loading = true;
  int? _lastTab;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // IndexedStack 이라 화면이 살아 있으므로, 알림 탭으로 돌아올 때마다 새로 불러온다.
    final tab = MainShellScope.maybeOf(context)?.currentIndex;
    if (tab == _tabIndex && _lastTab != null && _lastTab != _tabIndex) _load();
    _lastTab = tab;
  }

  Future<void> _load() async {
    setState(() {
      _loading = _data == null;
      _error = null;
    });
    try {
      final res = await ApiService().getNotifications();
      if (!mounted) return;
      setState(() {
        _data = res;
        _items = res.notifications;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  int get _unread => _items.where((n) => !n.isRead).length;

  Future<void> _open(NotificationItem item) async {
    if (!item.isRead) {
      setState(() => _items = [
            for (final n in _items)
              n.id == item.id ? n.copyWith(isRead: true) : n
          ]);
      try {
        await ApiService().markNotificationRead(item.id);
      } catch (_) {
        // 읽음 처리 실패해도 상세 이동은 계속한다.
      }
      if (!mounted) return;
    }
    if (item.reportId != null) {
      Navigator.pushNamed(context, '/report', arguments: item.reportId);
    } else if (item.ticker != null) {
      Navigator.pushNamed(context, '/company',
          // 보고서 없는 알림은 새 공시 알림이라 공시 탭(1)으로 연다.
          arguments: CompanyArgs(
              ticker: item.ticker!,
              name: item.stockName ?? item.ticker!,
              initialTab: 1));
    }
  }

  Future<void> _markAllRead() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final count = await ApiService().markAllNotificationsRead();
      messenger.showSnackBar(SnackBar(content: Text('알림 $count건을 읽음 처리했어요')));
      _load();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(children: [
          const Text('알림'),
          if (_unread > 0) ...[
            const SizedBox(width: AppSpace.sm),
            _CountBadge(_unread),
          ],
        ]),
        actions: [
          TextButton(
            onPressed: _unread > 0 ? _markAllRead : null,
            child: const Text('모두 읽음'),
          ),
          const SizedBox(width: AppSpace.sm),
        ],
      ),
      body: RefreshIndicator(onRefresh: _load, child: _body()),
    );
  }

  Widget _body() {
    const pad = EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, 0);
    if (_loading) {
      return ListView(
          padding: pad,
          children: const [SkeletonList(count: 4, itemHeight: 104)]);
    }
    if (_error != null) {
      return ListView(
          padding: pad,
          children: [ErrorRetry(message: _error.toString(), onRetry: _load)]);
    }
    if (_items.isEmpty) {
      return ListView(padding: pad, children: const [
        EmptyState(
          icon: Icons.notifications_none_rounded,
          title: '새 알림이 없어요',
          message: '관심종목에 새 공시나 분석 보고서가 나오면 알려드려요.',
        ),
      ]);
    }

    // 최신순으로 오므로 연속된 같은 날짜끼리 묶는다.
    final groups = <String, List<NotificationItem>>{};
    for (final n in _items) {
      final t = DateTime.tryParse(n.createdAt);
      groups.putIfAbsent(t == null ? '이전' : dayGroupLabel(t), () => []).add(n);
    }

    return ListView(
      padding: pad,
      children: [
        for (final e in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.only(
                top: AppSpace.sm, bottom: AppSpace.sm + 4),
            child: Row(children: [
              Text(e.key, style: AppText.headlineSm),
              const Spacer(),
              Text('${e.value.length}건', style: AppText.labelSm),
            ]),
          ),
          for (final n in e.value) ...[
            _NotificationCard(item: n, onTap: () => _open(n)),
            const SizedBox(height: AppSpace.sm + 4),
          ],
          const SizedBox(height: AppSpace.md),
        ],
        if (_data!.pagination.hasNext)
          Text('최근 알림 ${_items.length}건만 보여요',
              textAlign: TextAlign.center, style: AppText.labelSm),
        const Disclaimer(),
      ],
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  const _CountBadge(this.count);

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minWidth: 20),
        height: 20,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: AppColors.accent, borderRadius: BorderRadius.circular(999)),
        child: Text(count > 99 ? '99+' : '$count',
            style: AppText.labelSm
                .copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
      );
}

class _NotificationCard extends StatelessWidget {
  final NotificationItem item;
  final VoidCallback onTap;
  const _NotificationCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isReport = item.type == 'disclosure_report';
    // 보고서 알림은 title 이 공시 제목, 새 공시 알림은 body 가 공시 제목이다.
    final disclosureTitle = isReport ? item.title : (item.body ?? item.title);
    final created = DateTime.tryParse(item.createdAt);
    final unread = !item.isRead;

    return DsCard(
      onTap: onTap,
      color: unread ? AppColors.accentTint.withValues(alpha: 0.6) : null,
      padding: const EdgeInsets.fromLTRB(
          AppSpace.md, AppSpace.md, AppSpace.sm + 4, AppSpace.md),
      child: Row(children: [
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if (item.stockName != null || item.ticker != null)
                // Spacer 와 1:1 로 나누면 종목명이 너무 일찍 잘린다.
                Flexible(
                  flex: 5,
                  child: DsPill(
                    [item.stockName, item.ticker].whereType<String>().join(' '),
                    background:
                        unread ? AppColors.accentTint : AppColors.subtle,
                    foreground:
                        unread ? AppColors.accent : AppColors.textTertiary,
                  ),
                ),
              const SizedBox(width: AppSpace.sm),
              Text(isReport ? '새 분석 보고서' : '새 공시', style: AppText.labelSm),
              const Spacer(),
              if (created != null)
                Text(relativeTime(created), style: AppText.labelSm),
              if (unread) ...[const SizedBox(width: 6), const UnreadDot()],
            ]),
            const SizedBox(height: AppSpace.sm),
            Text(disclosureTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.labelLg.copyWith(
                    fontWeight: unread ? FontWeight.w700 : FontWeight.w600)),
            if (item.expectedCar != null) ...[
              const SizedBox(height: AppSpace.sm),
              CarBadge(item.expectedCar),
            ],
          ]),
        ),
        const SizedBox(width: AppSpace.xs),
        const Icon(Icons.chevron_right_rounded,
            size: 20, color: AppColors.textDisabled),
      ]),
    );
  }
}

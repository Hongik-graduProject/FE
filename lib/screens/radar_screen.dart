// lib/screens/radar_screen.dart — 레이더 스코프 (하단 두 번째 탭). Stitch "Disclosure Radar" 시안.
// 각도 = 1순위 테마, 반지름 = 나와의 거리(BE 계산 3단), 크기·색 = 예상 CAR.
// 실시간: 오늘 공시 + SSE. 리플레이: 고른 날의 장중(09:00~15:30)을 1x = 1초에 1분으로 재생.
// BE 에 없는 값(지연시간, 신뢰도, AI 코멘트, 기관 수급, 장중 시각)은 lib/demo/demo_data.dart 가 채운다.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../demo/demo_data.dart';
import '../models/radar_model.dart';
import '../services/api_service.dart';
import '../utils/design_tokens.dart';
import '../utils/format.dart';
import '../widgets/ds.dart';
import 'company/company_detail_screen.dart';

const _sweep = Duration(seconds: 60);
const _speeds = [1, 2, 5, 10];

enum _Filter { all, mine, largeCap, strong }

class RadarScreen extends StatefulWidget {
  const RadarScreen({super.key});

  @override
  State<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends State<RadarScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim =
      AnimationController(vsync: this, duration: _sweep)..repeat();
  final Map<int, RadarPoint> _points = {};
  final Map<int, DateTime> _arrivedAt = {}; // SSE 로 들어온 공시의 실제 도착 시각
  StreamSubscription<RadarPoint>? _sub;
  Timer? _reconnect;
  bool _loading = true;
  String? _error;
  bool _streaming = false;
  RadarPoint? _picked; // 사용자가 탭한 점. null 이면 최신 점을 따라간다.
  _Filter _filter = _Filter.all;

  // 리플레이
  DateTime? _replayDay; // null = 실시간
  DateTime _vt = DateTime.now(); // 가상 시각
  bool _playing = false;
  int _speed = 5;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _loadLive();
  }

  @override
  void dispose() {
    _stopStream();
    _clock?.cancel();
    _anim.dispose();
    super.dispose();
  }

  final Map<int, DateTime> _timeCache = {}; // demoFiledAt 은 공시마다 한 번만 계산한다

  DateTime _timeOf(RadarPoint p) =>
      _arrivedAt[p.disclosureId] ??
      _timeCache.putIfAbsent(p.disclosureId, () => demoFiledAt(p));

  void _fail(Object e) {
    if (mounted) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  // ─── 실시간 ────────────────────────────────────────────────────────────────

  Future<void> _loadLive() async {
    _stopStream();
    _clock?.cancel();
    setState(() {
      _replayDay = null;
      _loading = true;
      _error = null;
      _picked = null;
      _playing = false;
    });
    try {
      final now = DateTime.now();
      final pts = await ApiService().getRadarPoints(
          from: DateTime(now.year, now.month, now.day), to: now);
      if (!mounted) return;
      setState(() {
        _timeCache.clear();
        _points
          ..clear()
          ..addEntries(pts.map((p) => MapEntry(p.disclosureId, p)));
        _loading = false;
      });
      _startStream();
    } catch (e) {
      _fail(e);
    }
  }

  void _startStream() {
    _sub = ApiService().radarStream().listen(
      (p) {
        if (!mounted) return;
        setState(() {
          _streaming = true;
          if (p.event == 'disclosure') _arrivedAt.putIfAbsent(p.disclosureId, DateTime.now);
          _points[p.disclosureId] = p; // report 이벤트는 같은 점을 덮어 CAR 을 채운다
        });
      },
      onError: (_) => _scheduleReconnect(),
      onDone: _scheduleReconnect, // 서버가 30분마다 스트림을 닫는다
      cancelOnError: true,
    );
    setState(() => _streaming = true);
  }

  void _scheduleReconnect() {
    if (!mounted || _replayDay != null) return;
    setState(() => _streaming = false);
    _reconnect?.cancel();
    _reconnect = Timer(const Duration(seconds: 5), () async {
      if (!mounted || _replayDay != null) return;
      // 일반 API 를 한 번 거쳐 만료된 토큰을 갱신하고(Dio 인터셉터), 끊긴 동안 놓친 공시도 채운다.
      try {
        final pts = await ApiService().getRadarPoints();
        if (!mounted || _replayDay != null) return;
        setState(() {
          for (final p in pts) {
            _points[p.disclosureId] = p;
          }
        });
      } catch (_) {
        // 서버가 아직 없으면 스트림 연결도 실패하고 다시 이 경로로 온다.
      }
      if (mounted && _replayDay == null) _startStream();
    });
  }

  void _stopStream() {
    _reconnect?.cancel();
    _sub?.cancel();
    _sub = null;
    _streaming = false;
  }

  // ─── 리플레이 ──────────────────────────────────────────────────────────────

  DateTime get _open => DateTime(_replayDay!.year, _replayDay!.month,
      _replayDay!.day, demoMarketOpen.$1, demoMarketOpen.$2);
  DateTime get _close => DateTime(_replayDay!.year, _replayDay!.month,
      _replayDay!.day, demoMarketClose.$1, demoMarketClose.$2);

  static DateTime _lastWeekday() {
    var d = DateTime.now().subtract(const Duration(days: 1));
    while (d.weekday > DateTime.friday) {
      d = d.subtract(const Duration(days: 1));
    }
    return d;
  }

  Future<void> _pickReplayDay() async {
    final now = DateTime.now();
    final day = await showDatePicker(
      context: context,
      initialDate: _replayDay ?? now.subtract(const Duration(days: 1)),
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      helpText: '재생할 날짜',
    );
    if (day != null) await _loadReplay(day);
  }

  Future<void> _loadReplay(DateTime day) async {
    _stopStream();
    _clock?.cancel();
    setState(() {
      _replayDay = day;
      _loading = true;
      _error = null;
      _picked = null;
    });
    try {
      final from = DateTime(day.year, day.month, day.day);
      final pts = await ApiService()
          .getRadarPoints(from: from, to: from.add(const Duration(days: 1)));
      if (!mounted) return;
      setState(() {
        _timeCache.clear();
        _points
          ..clear()
          ..addEntries(pts.map((p) => MapEntry(p.disclosureId, p)));
        _arrivedAt.clear();
        _vt = _open;
        _loading = false;
      });
      _setPlaying(true);
    } catch (e) {
      _fail(e);
    }
  }

  void _setPlaying(bool on) {
    _clock?.cancel();
    setState(() => _playing = on);
    if (!on) return;
    // 1x = 1초에 장중 1분. 0.1초마다 갱신.
    _clock = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      final next = _vt.add(Duration(milliseconds: 6000 * _speed));
      setState(() => _vt = next.isAfter(_close) ? _close : next);
      if (!_vt.isBefore(_close)) _setPlaying(false);
    });
  }

  void _seek(DateTime t) => setState(() {
        _vt = t.isBefore(_open) ? _open : (t.isAfter(_close) ? _close : t);
      });

  void _nextDisclosure() {
    final later = _points.values
        .map(_timeOf)
        .where((t) => t.isAfter(_vt))
        .fold<DateTime?>(null, (m, t) => m == null || t.isBefore(m) ? t : m);
    if (later != null) {
      _seek(later);
      setState(() => _picked = null);
    }
  }

  // ─── 보이는 점 ─────────────────────────────────────────────────────────────

  bool _passes(RadarPoint p) => switch (_filter) {
        _Filter.all => true,
        _Filter.mine => p.isMine,
        _Filter.largeCap => demoLargeCap(p.ticker),
        _Filter.strong => (p.expectedCar?.abs() ?? 0) >= 2,
      };

  List<RadarPoint> _visible() {
    final all = _points.values.where(_passes);
    if (_replayDay == null) return all.toList();
    return all.where((p) => !_timeOf(p).isAfter(_vt)).toList();
  }

  RadarPoint? _focus(List<RadarPoint> pts) {
    if (_picked != null) return _points[_picked!.disclosureId] ?? _picked;
    if (pts.isEmpty) return null;
    // 사용자가 고르지 않았으면 가장 최근 공시를 따라간다. 내 종목이 있으면 그쪽 우선.
    int byTime(RadarPoint a, RadarPoint b) => _timeOf(b).compareTo(_timeOf(a));
    final mine = pts.where((p) => p.isMine).toList()..sort(byTime);
    if (mine.isNotEmpty) return mine.first;
    return ([...pts]..sort(byTime)).first;
  }

  @override
  Widget build(BuildContext context) {
    final replay = _replayDay != null;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          _TopBar(
            replay: replay,
            live: _streaming,
            onLive: _loadLive,
            onReplay: () => replay
                ? _pickReplayDay()
                : _loadReplay(_lastWeekday()),
            onRefresh: replay ? _pickReplayDay : _loadLive,
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: ErrorRetry(
                            message: _error!,
                            onRetry: replay ? _pickReplayDay : _loadLive))
                    : _body(replay),
          ),
        ]),
      ),
    );
  }

  Widget _body(bool replay) {
    final pts = _visible();
    final focus = _focus(pts);
    final now = replay ? _vt : DateTime.now();
    final mineCount = _points.values.where((p) => p.isMine).length;

    final scope = _Scope(
      points: pts,
      timeOf: _timeOf,
      now: now,
      sweep: _anim,
      focus: focus,
      onTap: (p) => setState(() => _picked = p),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.sm, AppSpace.md, AppSpace.xl),
      children: [
        if (!replay) ...[
          _LiveStatus(
              streaming: _streaming, total: _points.length, mine: mineCount),
          const SizedBox(height: AppSpace.md),
          _FilterChips(
            value: _filter,
            mineCount: mineCount,
            onChanged: (f) => setState(() {
              _filter = f;
              _picked = null;
            }),
          ),
          const SizedBox(height: AppSpace.sm),
        ] else ...[
          _ReplayHeader(
            day: _replayDay!,
            now: _vt,
            playing: _playing,
            count: pts.length,
            onLive: _loadLive,
            onPickDay: _pickReplayDay,
          ),
          const SizedBox(height: AppSpace.md),
        ],
        _ScopeFrame(child: scope),
        if (pts.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.sm),
            child: Text(
                _points.isNotEmpty && _filter != _Filter.all
                    ? '선택한 필터에 맞는 공시가 없어요'
                    : replay
                        ? '아직 재생 시각 이전 공시가 없어요'
                        : '오늘 들어온 공시가 없어요. 위에서 리플레이를 눌러 과거 하루를 재생해 보세요.',
                textAlign: TextAlign.center,
                style: AppText.bodySm),
          ),
        if (replay) ...[
          const SizedBox(height: AppSpace.md),
          _Timeline(
            open: _open,
            close: _close,
            now: _vt,
            playing: _playing,
            speed: _speed,
            times: _points.values.map(_timeOf).toList(),
            mineTimes: _points.values.where((p) => p.isMine).map(_timeOf).toList(),
            onSeek: _seek,
            onToggle: () => _setPlaying(!_playing),
            onSpeed: (s) => setState(() => _speed = s),
            onBack: () => _seek(_vt.subtract(const Duration(minutes: 5))),
            onForward: () => _seek(_vt.add(const Duration(minutes: 5))),
            onNext: _nextDisclosure,
          ),
        ],
        if (focus != null) ...[
          const SizedBox(height: AppSpace.md),
          replay
              ? _ReplayCard(p: focus, at: _timeOf(focus))
              : _FocusCard(p: focus, at: _timeOf(focus)),
        ],
        const SizedBox(height: AppSpace.lg),
        Text('본 인텔리전스는 AI 모델의 계량 분석 결과이며 투자 권유가 아닙니다.',
            textAlign: TextAlign.center,
            style: AppText.labelSm.copyWith(fontFamily: AppText.mono)),
      ],
    );
  }
}

// ─── 상단 바 ──────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final bool replay;
  final bool live;
  final VoidCallback onLive, onReplay, onRefresh;
  const _TopBar(
      {required this.replay,
      required this.live,
      required this.onLive,
      required this.onReplay,
      required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.sm, AppSpace.sm, AppSpace.sm),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border))),
      child: Row(children: [
        const Icon(Icons.track_changes_rounded, color: AppColors.accent, size: 24),
        const SizedBox(width: 6),
        const Flexible(
          child: Text('공시레이더', maxLines: 2, style: AppText.headlineMd),
        ),
        const SizedBox(width: 6),
        _LiveDart(on: !replay && live),
        const Spacer(),
        _Segmented(
          labels: const ['실시간', '리플레이'],
          index: replay ? 1 : 0,
          onTap: (i) => i == 0 ? onLive() : onReplay(),
        ),
        IconButton(
          tooltip: replay ? '날짜 고르기' : '새로고침',
          onPressed: onRefresh,
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.sync_rounded, color: AppColors.textSecondary),
        ),
      ]),
    );
  }
}

class _LiveDart extends StatelessWidget {
  final bool on;
  const _LiveDart({required this.on});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: on ? AppColors.bullTint : AppColors.subtle,
            borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                  color: on ? AppColors.bull : AppColors.flat,
                  shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text('LIVE DART',
              style: AppText.monoBadge
                  .copyWith(color: on ? AppColors.bull : AppColors.textTertiary)),
        ]),
      );
}

/// 터미널 스타일 2~4칸 토글.
class _Segmented extends StatelessWidget {
  final List<String> labels;
  final int index;
  final ValueChanged<int> onTap;
  const _Segmented({required this.labels, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
            color: AppColors.canvas,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadius.sm)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < labels.length; i++)
            GestureDetector(
              onTap: () => onTap(i),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                    color: i == index ? AppColors.brand : Colors.transparent,
                    borderRadius: BorderRadius.circular(6)),
                child: Text(labels[i],
                    style: AppText.labelMd.copyWith(
                        color: i == index ? Colors.white : AppColors.textTertiary)),
              ),
            ),
        ]),
      );
}

// ─── 실시간 상태·필터 ─────────────────────────────────────────────────────────

class _LiveStatus extends StatelessWidget {
  final bool streaming;
  final int total;
  final int mine;
  const _LiveStatus({required this.streaming, required this.total, required this.mine});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(children: [
        Row(children: [
          Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                  color: streaming ? AppColors.bull : AppColors.flat,
                  shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(streaming ? 'DART 피드 정상 수신 중' : 'DART 피드 재연결 중',
              style: AppText.labelLg.copyWith(fontFamily: AppText.mono, fontSize: 13)),
          const Spacer(),
          _MonoChip('LATENCY ${demoLatency()}'),
        ]),
        const SizedBox(height: AppSpace.md),
        Row(children: [
          Expanded(
              child: _StatTile(
                  label: '오늘 장중 공시',
                  value: '$total',
                  unit: '건',
                  icon: Icons.receipt_long_rounded,
                  iconColor: AppColors.textSecondary,
                  iconBg: AppColors.raised)),
          const SizedBox(width: AppSpace.sm),
          Expanded(
              child: _StatTile(
                  label: 'MY 포트 감지',
                  value: '$mine',
                  unit: '건 타깃',
                  valueColor: AppColors.bull,
                  icon: Icons.gps_fixed_rounded,
                  iconColor: AppColors.bull,
                  iconBg: AppColors.bullTint)),
        ]),
      ]),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label, value, unit;
  final IconData icon;
  final Color iconColor, iconBg;
  final Color? valueColor;
  const _StatTile(
      {required this.label,
      required this.value,
      required this.unit,
      required this.icon,
      required this.iconColor,
      required this.iconBg,
      this.valueColor});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: AppColors.canvas,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadius.sm)),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: AppText.monoLabel),
              const SizedBox(height: 4),
              Text.rich(TextSpan(children: [
                TextSpan(
                    text: value,
                    style: AppText.numericMetric
                        .copyWith(fontSize: 22, color: valueColor ?? AppColors.textPrimary)),
                TextSpan(text: ' $unit', style: AppText.labelMd),
              ])),
            ]),
          ),
          CircleAvatar(
              radius: 18,
              backgroundColor: iconBg,
              child: Icon(icon, size: 18, color: iconColor)),
        ]),
      );
}

class _FilterChips extends StatelessWidget {
  final _Filter value;
  final int mineCount;
  final ValueChanged<_Filter> onChanged;
  const _FilterChips(
      {required this.value, required this.mineCount, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final items = [
      (_Filter.all, Icons.grid_view_rounded, '전체 공시'),
      (_Filter.mine, Icons.stars_rounded, '내 종목만 ($mineCount)'),
      (_Filter.largeCap, Icons.account_balance_rounded, '시총 1조↑'),
      (_Filter.strong, Icons.bolt_rounded, '강한 신호'),
    ];
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpace.sm),
        itemBuilder: (context, i) {
          final (f, icon, label) = items[i];
          final on = f == value;
          return GestureDetector(
            onTap: () => onChanged(f),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                  color: on ? AppColors.brand : AppColors.card,
                  border: Border.all(color: on ? AppColors.brand : AppColors.border),
                  borderRadius: BorderRadius.circular(999)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 16, color: on ? Colors.white : AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(label,
                    style: AppText.labelMd
                        .copyWith(color: on ? Colors.white : AppColors.textSecondary)),
              ]),
            ),
          );
        },
      ),
    );
  }
}

// ─── 리플레이 머리·타임라인 ───────────────────────────────────────────────────

const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

String _hms(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
String _hm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

class _ReplayHeader extends StatelessWidget {
  final DateTime day, now;
  final bool playing;
  final int count;
  final VoidCallback onLive, onPickDay;
  const _ReplayHeader(
      {required this.day,
      required this.now,
      required this.playing,
      required this.count,
      required this.onLive,
      required this.onPickDay});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(children: [
        Row(children: [
          const Icon(Icons.history_rounded, size: 18, color: AppColors.accent),
          const SizedBox(width: 6),
          const Text('장중 리플레이', style: AppText.labelLg),
          const Spacer(),
          GestureDetector(
            onTap: onPickDay,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                  color: AppColors.raised, borderRadius: BorderRadius.circular(AppRadius.sm)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.calendar_month_rounded, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text('${ymd(day, sep: '.')} (${_weekdays[day.weekday - 1]})',
                    style: AppText.labelLg.copyWith(fontFamily: AppText.mono)),
                const Icon(Icons.expand_more_rounded, size: 18, color: AppColors.textTertiary),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: AppSpace.md),
        Row(children: [
          Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                  color: playing ? AppColors.bull : AppColors.flat, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(playing ? '장중 리플레이 재생 중 · ' : '일시정지 · ', style: AppText.labelMd),
          Text(_hms(now),
              style: AppText.numericMetric.copyWith(fontSize: 15, color: AppColors.bull)),
          const Spacer(),
          const Text('누적 포착 ', style: AppText.labelMd),
          _MonoChip('$count건', big: true),
        ]),
      ]),
    );
  }
}

class _Timeline extends StatelessWidget {
  final DateTime open, close, now;
  final bool playing;
  final int speed;
  final List<DateTime> times, mineTimes;
  final ValueChanged<DateTime> onSeek;
  final VoidCallback onToggle, onBack, onForward, onNext;
  final ValueChanged<int> onSpeed;
  const _Timeline(
      {required this.open,
      required this.close,
      required this.now,
      required this.playing,
      required this.speed,
      required this.times,
      required this.mineTimes,
      required this.onSeek,
      required this.onToggle,
      required this.onSpeed,
      required this.onBack,
      required this.onForward,
      required this.onNext});

  static const _bucket = Duration(minutes: 30);

  @override
  Widget build(BuildContext context) {
    final total = close.difference(open);
    final n = (total.inMinutes / _bucket.inMinutes).ceil();
    final counts = List.filled(n, 0), mine = List.filled(n, 0);
    int idx(DateTime t) => (t.difference(open).inMinutes ~/ _bucket.inMinutes).clamp(0, n - 1);
    for (final t in times) {
      if (!t.isBefore(open) && !t.isAfter(close)) counts[idx(t)]++;
    }
    for (final t in mineTimes) {
      if (!t.isBefore(open) && !t.isAfter(close)) mine[idx(t)]++;
    }
    final maxC = counts.fold<int>(1, math.max);
    final cur = idx(now);
    final frac = (now.difference(open).inSeconds / total.inSeconds).clamp(0.0, 1.0);
    final left = close.difference(now).inMinutes;

    return _Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          const Icon(Icons.schedule_rounded, color: AppColors.accent),
          const SizedBox(width: 8),
          Text(_hms(now), style: AppText.numericHero.copyWith(fontSize: 26)),
          Text(' / ${_hms(close)}',
              style: AppText.numericMetric.copyWith(fontSize: 15, color: AppColors.textTertiary)),
          const Spacer(),
          _Badge(
              left <= 0
                  ? '장 마감'
                  : left <= 60
                      ? '장마감 $left분 전'
                      : '장중',
              fg: AppColors.bull,
              bg: AppColors.bullTint),
        ]),
        const SizedBox(height: AppSpace.md),
        LayoutBuilder(builder: (context, c) {
          void seekAt(double x) => onSeek(open.add(Duration(
              seconds: (total.inSeconds * (x / c.maxWidth).clamp(0.0, 1.0)).round())));
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => seekAt(d.localPosition.dx),
            onHorizontalDragUpdate: (d) => seekAt(d.localPosition.dx),
            child: Column(children: [
              SizedBox(
                height: 56,
                child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  for (var i = 0; i < n; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Container(
                          height: 6 + 50 * counts[i] / maxC,
                          decoration: BoxDecoration(
                            color: i == cur
                                ? AppColors.bull
                                : mine[i] > 0
                                    ? AppColors.brand
                                    : AppColors.raised,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                          ),
                        ),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: frac,
                  minHeight: 6,
                  backgroundColor: AppColors.raised,
                  valueColor: const AlwaysStoppedAnimation(AppColors.brand),
                ),
              ),
            ]),
          );
        }),
        const SizedBox(height: 6),
        Row(children: [
          Text('${_hm(open)} 개장', style: AppText.monoLabel),
          const Spacer(),
          Text('${_hm(now)} [현재]', style: AppText.monoLabel.copyWith(color: AppColors.bull)),
          const Spacer(),
          Text('${_hm(close)} 마감', style: AppText.monoLabel),
        ]),
        const SizedBox(height: AppSpace.md),
        Row(children: [
          _Segmented(
            labels: [for (final s in _speeds) '${s}x'],
            index: _speeds.indexOf(speed),
            onTap: (i) => onSpeed(_speeds[i]),
          ),
          const Spacer(),
          IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.replay_5_rounded, color: AppColors.textSecondary)),
          GestureDetector(
            onTap: onToggle,
            child: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                  color: AppColors.brand, shape: BoxShape.circle, boxShadow: AppShadow.raised),
              child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white, size: 28),
            ),
          ),
          IconButton(
              onPressed: onForward,
              icon: const Icon(Icons.forward_5_rounded, color: AppColors.textSecondary)),
        ]),
        const SizedBox(height: AppSpace.sm),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(40)),
            onPressed: onNext,
            icon: const Icon(Icons.skip_next_rounded, size: 18),
            label: const Text('다음 공시'),
          ),
        ),
      ]),
    );
  }
}

// ─── 스코프 ───────────────────────────────────────────────────────────────────

class _ScopeFrame extends StatelessWidget {
  final Widget child;
  const _ScopeFrame({required this.child});

  @override
  Widget build(BuildContext context) => AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
            gradient: const RadialGradient(
                colors: [Color(0xFF13214A), AppColors.canvas], radius: 0.75),
          ),
          child: Stack(children: [
            Positioned.fill(child: child),
            const Positioned(left: 0, right: 0, bottom: 10, child: Center(child: _Legend())),
          ]),
        ),
      );
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget dot(Color c, String t, {bool ring = false}) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                  color: ring ? null : c,
                  border: ring ? Border.all(color: c, width: 1.5) : null,
                  shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(t, style: AppText.labelSm.copyWith(color: AppColors.textSecondary)),
        ]);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: const Color(0xEE0A1128),
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(999)),
      child: Wrap(spacing: 10, children: [
        dot(AppColors.bull, '상승 예상'),
        dot(AppColors.bear, '하락 예상'),
        dot(AppColors.flat, '분석 중'),
        dot(AppColors.textPrimary, 'MY', ring: true),
      ]),
    );
  }
}

class _Scope extends StatelessWidget {
  final List<RadarPoint> points;
  final DateTime Function(RadarPoint) timeOf;
  final DateTime now;
  final Animation<double> sweep;
  final RadarPoint? focus;
  final ValueChanged<RadarPoint?> onTap;
  const _Scope(
      {required this.points,
      required this.timeOf,
      required this.now,
      required this.sweep,
      required this.focus,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final size = math.min(c.maxWidth, c.maxHeight);
      final geo = _Geo(Offset(c.maxWidth / 2, c.maxHeight / 2 - 8), size / 2 - 40,
          _Geo.sectorOf(points));
      // 점 위치·색·크기는 여기서 한 번만 계산해 두 층이 같이 쓴다.
      final ordered = [...points]
        ..sort((x, y) => (x.isMine ? 1 : 0).compareTo(y.isMine ? 1 : 0));
      final dots = [
        for (final p in ordered)
          _Dot(
            p,
            geo.at(p),
            _ScopePainter.colorOf(p.expectedCar),
            p.expectedCar == null ? 3.0 : 3.5 + math.min(p.expectedCar!.abs(), 5.0) * 1.1,
            focus?.disclosureId == p.disclosureId,
            now.difference(timeOf(p)).inMinutes.abs() < 3,
          ),
      ];
      final canvasSize = Size(c.maxWidth, c.maxHeight);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) {
          _Dot? best;
          var bestDist = 22.0;
          for (final dot in dots) {
            final dist = (dot.at - d.localPosition).distance;
            if (dist < bestDist) {
              best = dot;
              bestDist = dist;
            }
          }
          if (best != null) onTap(best.p);
        },
        child: Stack(children: [
          RepaintBoundary(
            child: CustomPaint(size: canvasSize, painter: _ScopePainter(points, dots, geo)),
          ),
          RepaintBoundary(
            child: CustomPaint(
              size: canvasSize,
              painter: _SweepPainter(sweep, geo, [for (final d in dots) if (d.highlight) d]),
            ),
          ),
        ]),
      );
    });
  }
}

class _Dot {
  final RadarPoint p;
  final Offset at;
  final Color color;
  final double rad;
  final bool focus;
  final bool fresh;
  const _Dot(this.p, this.at, this.color, this.rad, this.focus, this.fresh);
  bool get highlight => fresh || focus || p.isMine;
}

/// 매 프레임 그리는 층: 스윕 부채꼴과 강조 점의 파동. repaint 로 애니메이션을 직접 구독해 위젯을 다시 만들지 않는다.
class _SweepPainter extends CustomPainter {
  final Animation<double> sweep;
  final _Geo g;
  final List<_Dot> pulsing;
  _SweepPainter(this.sweep, this.g, this.pulsing) : super(repaint: sweep);

  @override
  void paint(Canvas canvas, Size size) {
    final a = sweep.value * 2 * math.pi - math.pi / 2;
    final rect = Rect.fromCircle(center: g.center, radius: g.r);
    canvas.drawArc(
        rect,
        a - 0.7,
        0.7,
        true,
        Paint()
          ..shader = SweepGradient(
            startAngle: a - 0.7,
            endAngle: a,
            colors: [AppColors.brand.withValues(alpha: 0), AppColors.brand.withValues(alpha: 0.28)],
          ).createShader(rect));
    canvas.drawLine(g.center, g.center + Offset(math.cos(a), math.sin(a)) * g.r,
        Paint()
          ..color = const Color(0xFF8FA5FF)
          ..strokeWidth = 1.5);
    canvas.drawCircle(g.center, 3, Paint()..color = const Color(0xFF8FA5FF));

    final pulse = (math.sin(sweep.value * 40 * math.pi) + 1) / 2;
    for (final d in pulsing) {
      canvas.drawCircle(
          d.at,
          d.rad + 4 + 8 * pulse,
          Paint()
            ..color = d.color.withValues(alpha: 0.35 * (1 - pulse))
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(covariant _SweepPainter old) => old.pulsing != pulsing || old.g.r != g.r;
}

class _Geo {
  final Offset center;
  final double r;
  final double sector; // 테마 한 칸의 각도
  const _Geo(this.center, this.r, this.sector);

  /// BE 는 theta = 테마번호 × 360 / 테마 수 로 준다. 칸 너비 = 서로 다른 theta 사이 최소 간격.
  static double sectorOf(List<RadarPoint> points) {
    final ts = points.map((p) => p.theta).toSet().toList()..sort();
    var gap = 360 / 17;
    for (var i = 1; i < ts.length; i++) {
      final d = ts[i] - ts[i - 1];
      if (d > 0.5 && d < gap) gap = d;
    }
    return gap;
  }

  /// theta 0° = 12시, 시계 방향.
  Offset polar(double thetaDeg, double radius) {
    final a = (thetaDeg - 90) * math.pi / 180;
    return center + Offset(math.cos(a), math.sin(a)) * (radius * r);
  }

  /// 같은 테마·같은 고리의 점이 한 좌표에 겹치지 않게 테마 칸과 고리 안에서 펼친다.
  /// 같은 테마 띠(0.35~0.65)의 반지름은 BE 가 테마 확률로 계산한 값이라 그대로 쓴다.
  Offset at(RadarPoint p) {
    final ha = demoRand(p.ticker, 1), hr = demoRand(p.ticker, 2);
    final r = p.radius >= 0.8
        ? 0.76 + hr * 0.2
        : p.radius <= 0.2
            ? 0.06 + hr * 0.14
            : p.radius;
    return polar(p.theta + (ha - 0.5) * sector * 0.8, r);
  }
}

class _ScopePainter extends CustomPainter {
  final List<RadarPoint> points;
  final List<_Dot> dots;
  final _Geo g;
  _ScopePainter(this.points, this.dots, this.g);

  static Color colorOf(double? car) => car == null ? AppColors.flat : AppColors.market(car);

  void _text(Canvas canvas, String s, Offset at, TextStyle style,
      {Color? bg, double maxWidth = 90}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
    final o = at - Offset(tp.width / 2, tp.height / 2);
    if (bg != null) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(o.dx - 5, o.dy - 2, tp.width + 10, tp.height + 4),
              const Radius.circular(4)),
          Paint()..color = bg);
    }
    tp.paint(canvas, o);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..color = const Color(0x40667085)
      ..strokeWidth = 1;
    final hair = Paint()
      ..color = const Color(0x26667085)
      ..strokeWidth = 1;

    // 같은 테마 띠
    canvas.drawCircle(
        g.center,
        g.r * 0.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = g.r * 0.30
          ..color = const Color(0x143B66FF));
    for (final f in [0.22, 0.70, 1.0]) {
      canvas.drawCircle(g.center, g.r * f, ring);
    }
    // 십자선 + 눈금
    for (var k = 0; k < 4; k++) {
      final a = k * math.pi / 2;
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(g.center, g.center + d * g.r, hair);
      for (var t = 1; t < 10; t++) {
        final p = g.center + d * (g.r * t / 10);
        final n = Offset(-d.dy, d.dx) * 3;
        canvas.drawLine(p - n, p + n, hair);
      }
    }

    // 테마 이름
    final themes = <String, double>{
      for (final p in points)
        if (p.theme != null) p.theme!: p.theta
    };
    for (final MapEntry(key: name, value: theta) in themes.entries) {
      _text(canvas, name.replaceAll('/', '·'), g.polar(theta, 1.17),
          AppText.labelSm.copyWith(color: AppColors.textTertiary, fontSize: 10),
          maxWidth: 64);
    }
    // 고리 이름
    final ringStyle = AppText.monoBadge.copyWith(color: const Color(0xFF667085), fontSize: 9);
    _text(canvas, 'CORE', g.center + Offset(0, -g.r * 0.14), ringStyle);
    _text(canvas, 'THEME AFFINITY', g.center + Offset(0, -g.r * 0.62), ringStyle);
    _text(canvas, 'BROAD MARKET', g.center + Offset(0, -g.r * 0.92), ringStyle);

    // 점. 내 종목·포커스는 위에 그린다 (dots 가 이미 그 순서다). 파동은 _SweepPainter 가 그린다.
    final labelled = <_Dot>[];
    for (final d in dots) {
      if (d.highlight) canvas.drawCircle(d.at, d.rad + 4, Paint()..color = d.color.withValues(alpha: 0.22));
      canvas.drawCircle(d.at, d.rad, Paint()..color = d.color);
      if (d.p.isMine || d.focus) {
        canvas.drawCircle(
            d.at,
            d.rad + 3,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5
              ..color = AppColors.textPrimary);
        labelled.add(d);
      }
    }
    for (final d in labelled.take(6)) {
      final car = d.p.expectedCar;
      final label = car == null ? d.p.name : '${d.p.name} ${signedPct(car, digits: 1)}';
      _text(canvas, label, d.at + const Offset(0, 18),
          AppText.monoBadge.copyWith(color: car == null ? AppColors.textSecondary : colorOf(car)),
          bg: const Color(0xE60A1128), maxWidth: 110);
    }
  }

  @override
  bool shouldRepaint(covariant _ScopePainter old) => old.dots != dots || old.g.r != g.r;
}

// ─── 포커스 카드 ──────────────────────────────────────────────────────────────

void _openCompany(BuildContext context, RadarPoint p, int tab) =>
    Navigator.pushNamed(context, '/company',
        arguments: CompanyArgs(ticker: p.ticker, name: p.name, initialTab: tab));

class _FocusCard extends StatelessWidget {
  final RadarPoint p;
  final DateTime at;
  const _FocusCard({required this.p, required this.at});

  @override
  Widget build(BuildContext context) {
    final car = p.expectedCar;
    final share = demoContributionShare('${p.disclosureId}');
    return _Panel(
      elevated: true,
      accentTop: car == null ? null : AppColors.market(car),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (p.isMine)
            const _Badge('MY 포커스 1순위', fg: Colors.white, bg: AppColors.bull)
          else if (p.theme != null)
            Flexible(child: _Badge(p.theme!, fg: AppColors.accent, bg: AppColors.accentTint)),
          const SizedBox(width: 8),
          Text('DART ${_hm(at)} 수신', style: AppText.monoLabel),
          const Spacer(),
          const Icon(Icons.verified_outlined, size: 16, color: AppColors.accent),
          const SizedBox(width: 4),
          Text('신뢰도 ${demoConfidence('${p.disclosureId}')}%',
              style: AppText.labelMd.copyWith(color: AppColors.accent)),
        ]),
        const SizedBox(height: AppSpace.md),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Text.rich(TextSpan(children: [
              TextSpan(text: p.name, style: AppText.headlineLg),
              TextSpan(
                  text: '  ${p.ticker}',
                  style: AppText.numericMetric.copyWith(fontSize: 15, color: AppColors.textTertiary)),
            ])),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Text('예상 누적초과수익률(CAR)', style: AppText.monoLabel),
            Text(car == null ? '분석 중' : '${arrow(car)} ${signedPct(car, digits: 1)}',
                style: AppText.numericHero.copyWith(color: AppColors.market(car))),
          ]),
        ]),
        const SizedBox(height: AppSpace.sm),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
              color: AppColors.canvas, borderRadius: BorderRadius.circular(4)),
          child: Text(p.title.trim(),
              maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.labelLg),
        ),
        const SizedBox(height: AppSpace.md),
        _InsetBox(
          icon: Icons.smart_toy_outlined,
          title: 'AI 스마트 매니저 코멘트',
          body: demoAiComment(
              title: p.title, car: car, topMetric: p.topMetric, theme: p.theme),
        ),
        const SizedBox(height: AppSpace.sm),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: AppColors.canvas,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppRadius.sm)),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('핵심 영향 요인 (1위)', style: AppText.monoLabel),
                const SizedBox(height: 4),
                Text(p.topMetric ?? '분석 대기', style: AppText.headlineSm),
              ]),
            ),
            if (car != null)
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${signedPct(car * share / 100, digits: 1)}p',
                    style: AppText.numericMetric.copyWith(color: AppColors.market(car))),
                Text('CAR 기여도 비중 ${share.round()}%', style: AppText.monoLabel),
              ]),
          ]),
        ),
        const SizedBox(height: AppSpace.md),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
              onPressed: () => _openCompany(context, p, 1),
              icon: const Icon(Icons.description_outlined, size: 18),
              label: const Text('공시 목록 보기'),
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
              onPressed: () => _openCompany(context, p, 0),
              icon: const Icon(Icons.analytics_outlined, size: 18),
              label: const Text('AI 시나리오'),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _ReplayCard extends StatelessWidget {
  final RadarPoint p;
  final DateTime at;
  const _ReplayCard({required this.p, required this.at});

  @override
  Widget build(BuildContext context) {
    final car = p.expectedCar;
    final seed = '${p.disclosureId}';
    final flow = demoFlow(seed);
    return _Panel(
      elevated: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, children: [
                Text(p.name, style: AppText.headlineLg),
                Text(p.ticker,
                    style: AppText.numericMetric.copyWith(fontSize: 15, color: AppColors.textTertiary)),
                if (p.isMine) const _Badge('내 보유', fg: AppColors.textSecondary, bg: AppColors.canvas),
              ]),
              const SizedBox(height: 4),
              Text(p.title.trim(), maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.bodyMd),
            ]),
          ),
          const SizedBox(width: AppSpace.sm),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('예상 CAR 충격', style: AppText.labelMd.copyWith(color: AppColors.market(car))),
            Text(car == null ? '분석 중' : '${arrow(car)} ${signedPct(car, digits: 1)}',
                style: AppText.numericMetric.copyWith(fontSize: 24, color: AppColors.market(car))),
          ]),
        ]),
        const SizedBox(height: AppSpace.md),
        _InsetBox(
          icon: Icons.auto_awesome_rounded,
          title: 'AI 레이더 속보 분석 (${_hm(at)} 포착)',
          body: demoAiComment(title: p.title, car: car, topMetric: p.topMetric, theme: p.theme)
              .replaceAll('“', '')
              .replaceAll('”', ''),
        ),
        const SizedBox(height: AppSpace.md),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('기여도 1위', style: AppText.labelSm),
              Text(p.topMetric ?? '분석 대기',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.labelLg),
            ]),
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('기관 수급 반응', style: AppText.labelSm),
              Text('$flow ${demoFlowLabel(seed)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.labelLg.copyWith(
                      color: flow.startsWith('+') ? AppColors.bull : AppColors.bear)),
            ]),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 38),
                padding: const EdgeInsets.symmetric(horizontal: 12)),
            onPressed: () => _openCompany(context, p, 0),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Text('상세 보고서'),
              Icon(Icons.chevron_right_rounded, size: 18),
            ]),
          ),
        ]),
      ]),
    );
  }
}

// ─── 작은 공용 조각 ───────────────────────────────────────────────────────────

/// Level 1/2 유리 패널. elevated 는 푸른 빛 그림자, accentTop 은 위쪽 가장자리 색 띠.
class _Panel extends StatelessWidget {
  final Widget child;
  final bool elevated;
  final Color? accentTop;
  const _Panel({required this.child, this.elevated = false, this.accentTop});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: elevated ? AppColors.raised : AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
          boxShadow: elevated ? AppShadow.raised : null,
          gradient: accentTop == null
              ? null
              : LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [accentTop!.withValues(alpha: 0.22), AppColors.raised],
                  stops: const [0, 0.1]),
        ),
        padding: const EdgeInsets.all(AppSpace.md),
        child: child,
      );
}

class _InsetBox extends StatelessWidget {
  final IconData icon;
  final String title, body;
  const _InsetBox({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: AppColors.canvas.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(AppRadius.sm)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.accentTint,
              child: Icon(icon, size: 16, color: AppColors.accent)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: AppText.monoBadge.copyWith(color: AppColors.accent, fontSize: 11)),
              const SizedBox(height: 4),
              Text(body, style: AppText.bodyMd),
            ]),
          ),
        ]),
      );
}

class _Badge extends StatelessWidget {
  final String text;
  final Color fg, bg;
  const _Badge(this.text, {required this.fg, required this.bg});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
        child: Text(text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.monoBadge.copyWith(color: fg, fontSize: 11)),
      );
}

class _MonoChip extends StatelessWidget {
  final String text;
  final bool big;
  const _MonoChip(this.text, {this.big = false});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: AppColors.canvas,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(999)),
        child: Text(text,
            style: big
                ? AppText.numericMetric.copyWith(fontSize: 15)
                : AppText.monoLabel.copyWith(color: AppColors.textSecondary)),
      );
}

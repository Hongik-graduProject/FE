// lib/demo/demo_data.dart — 데모용 가짜 데이터. BE 에 없는 값을 "서버에서 온 것처럼" 채운다.
// 실서비스 전에 이 파일을 참조하는 곳을 모두 실제 API 로 바꾸거나 지운다.
// 모든 값은 종목코드·공시 id 로 결정되므로 같은 화면은 늘 같은 숫자를 보여준다.
import 'dart:math' as math;

import '../models/analysis_model.dart';
import '../models/radar_model.dart';

/// 문자열로 정하는 0~1 난수 (같은 입력 → 같은 값).
double demoRand(String seed, [int salt = 0]) {
  var h = 0x811C9DC5 ^ salt;
  for (final c in seed.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0x7fffffff;
  }
  return (h % 10007) / 10007;
}

int _pick(String seed, int salt, int lo, int hi) =>
    lo + (demoRand(seed, salt) * (hi - lo + 1)).floor().clamp(0, hi - lo);

// ─── 시각 ───────────────────────────────────────────────────────────────────

const demoMarketOpen = (9, 0);
const demoMarketClose = (15, 30);

/// DART 목록 API 는 접수 날짜만 줘서 filed_at 이 모두 00:00 이다.
/// 데모에서는 공시마다 장중 시각(09:00~15:30)을 정해 준다. 오늘이면 지금 이후로는 놓지 않는다.
DateTime demoFiledAt(RadarPoint p, {DateTime? now}) {
  final t = p.filedAt;
  if (t.hour != 0 || t.minute != 0) return t;
  final open = DateTime(t.year, t.month, t.day, demoMarketOpen.$1, demoMarketOpen.$2);
  var close = DateTime(t.year, t.month, t.day, demoMarketClose.$1, demoMarketClose.$2);
  final n = now ?? DateTime.now();
  if (n.isBefore(close) && n.isAfter(open)) close = n;
  final span = close.difference(open).inSeconds;
  if (span <= 0) return open;
  // 장 초반·막판에 몰리는 모양: 양 끝이 두꺼운 분포
  final u = demoRand('${p.disclosureId}', 11);
  final skew = u < 0.5 ? 0.5 * math.pow(2 * u, 1.6) : 1 - 0.5 * math.pow(2 * (1 - u), 1.6);
  return open.add(Duration(seconds: (span * skew).round()));
}

// ─── 레이더 ──────────────────────────────────────────────────────────────────

String demoLatency() => '${(0.8 + demoRand(DateTime.now().minute.toString()) * 0.9).toStringAsFixed(1)}s';

int demoConfidence(String seed) => _pick(seed, 3, 71, 94);

/// 시총 1조 이상 여부 (데모 필터용).
bool demoLargeCap(String ticker) =>
    const {'005930', '000660', '005380', '035420', '051910', '006400', '000270', '105560', '055550', '003550', '028260', '012330', '068270', '207940', '035720'}
        .contains(ticker) ||
    demoRand(ticker, 5) < 0.28;

double demoContributionShare(String seed) => _pick(seed, 7, 42, 78).toDouble();

String demoFlow(String seed) {
  final v = _pick(seed, 9, -900, 3200);
  final s = v >= 0 ? '+' : '-';
  final a = v.abs();
  final txt = a >= 1000 ? '${a ~/ 1000},${(a % 1000).toString().padLeft(3, '0')}' : '$a';
  return '$s$txt억';
}

String demoFlowLabel(String seed) => demoFlow(seed).startsWith('+') ? '순매수 유입' : '순매도 출회';

/// 공시 제목·예상 CAR 로 만드는 한두 문장 코멘트.
String demoAiComment({required String title, required double? car, String? topMetric, String? theme}) {
  final t = title.replaceAll(RegExp(r'\s+'), ' ').trim();
  final m = topMetric ?? '핵심 재무 지표';
  if (car == null) return '“$t” 공시를 분석하는 중입니다. 테마·재무 민감도 계산이 끝나면 예상 반응을 알려드릴게요.';
  final dir = car >= 0 ? '우호적' : '부담';
  final kw = _keyword(t);
  if (car >= 2) return '“$kw 기대감과 $m 개선 흐름이 겹쳐 단기 수급 유입 가능성이 우세합니다.”';
  if (car >= 0) return '“$kw 이슈는 ${theme ?? '업종'} 내에서 $dir 재료로, $m 변화가 완만한 상승 압력을 만듭니다.”';
  if (car <= -2) return '“$kw 공시로 $m 둔화 우려가 커져 단기 매물 출회 가능성이 높습니다.”';
  return '“$kw 내용은 시장에 $dir 요인이며, $m 약세가 제한적인 하락 압력으로 작용합니다.”';
}

String _keyword(String title) {
  for (final k in ['배당', '자사주', '유상증자', '무상증자', '공급계약', '실적', '영업', '합병', '분할', '임상', '수주', '최대주주', '전환사채', '투자']) {
    if (title.contains(k)) return k;
  }
  return title.length > 12 ? title.substring(0, 12) : title;
}

// ─── 보고서 상세 (Disclosure Dossier) ─────────────────────────────────────────

String demoDartRef(ReportDetail r) {
  final url = r.sourceDisclosure?.dartUrl ?? '';
  final m = RegExp(r'rcpNo=(\d+)').firstMatch(url);
  final no = m?.group(1) ?? '${r.generatedAt.replaceAll(RegExp(r'\D'), '').padRight(8, '0').substring(0, 8)}${(r.id * 37 % 1000000).toString().padLeft(6, '0')}';
  return no.length > 8 ? '${no.substring(0, 8)}-${no.substring(8, no.length.clamp(8, 13))}' : no;
}

String demoBriefing(ReportDetail r) {
  final top = [...r.metricContributions]..sort((a, b) => b.contribution.abs().compareTo(a.contribution.abs()));
  final m = top.isNotEmpty ? top.first.displayName : '핵심 지표';
  final car = r.expectedCar ?? 0;
  return car >= 0
      ? '$m 개선이 ${r.appliedTheme?.name ?? '테마'} 민감도와 맞물려 초과수익 예측을 견인합니다. 기관 순유입 모멘텀 가중치가 상위 ${(demoRand(r.ticker, 21) * 4 + 1).toStringAsFixed(1)}% 임계치를 돌파했습니다.'
      : '$m 둔화가 ${r.appliedTheme?.name ?? '테마'} 민감도와 겹쳐 하방 압력을 키웁니다. 단기 수급은 관망세로, 변동성 확대 구간에 진입했습니다.';
}

/// 판정이 끝난 전적이 아직 없을 때 데모용 전적. (전체 판정 수, 적중 수, 최근 순 승패)
({int judged, int hits, List<bool> recent}) demoTrackRecord(String ticker) {
  final judged = _pick(ticker, 31, 9, 16);
  final hits = (judged * (0.52 + demoRand(ticker, 32) * 0.22)).round();
  final recent = [for (var i = 0; i < judged; i++) demoRand(ticker, 40 + i) < hits / judged];
  return (judged: judged, hits: hits, recent: recent);
}

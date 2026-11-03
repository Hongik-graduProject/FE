// lib/widgets/ds.dart
// Stitch 디자인 시스템의 공용 컴포넌트. 화면은 이 위젯들을 조합한다.
import 'package:flutter/material.dart';

import '../utils/design_tokens.dart';
import '../utils/format.dart';

/// 흰 카드. outlined=true 는 ML 60일 전망처럼 "다른 종류의 예측" 을 구분할 때 쓴다 (테두리 1.5px, 그림자 없음).
class DsCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool outlined;
  final VoidCallback? onTap;
  final Color? color;

  const DsCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpace.lg),
    this.outlined = false,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.lg);
    return Container(
      decoration: BoxDecoration(
        color: color ?? AppColors.card,
        borderRadius: radius,
        border: Border.all(color: AppColors.border, width: outlined ? 1.5 : 1),
        boxShadow: outlined ? null : AppShadow.card,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// 둥근 칩. 테마, 시장, 데모 표시 등 모든 알약 모양의 기반.
class DsPill extends StatelessWidget {
  final String text;
  final Color background;
  final Color foreground;
  final IconData? icon;
  final double height;

  const DsPill(this.text,
      {super.key,
      required this.background,
      required this.foreground,
      this.icon,
      this.height = 24});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
          color: background, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: foreground),
          const SizedBox(width: 4),
        ],
        // 좁은 줄에 들어가면 넘치지 않고 말줄임표로 줄어든다.
        Flexible(
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.labelMd.copyWith(
                  color: foreground,
                  fontFeatures: AppText.numeric.fontFeatures)),
        ),
      ]),
    );
  }
}

/// 투자 테마 칩 (연한 남색 바탕)
class ThemeChip extends StatelessWidget {
  final String name;
  const ThemeChip(this.name, {super.key});
  @override
  Widget build(BuildContext context) => DsPill(name,
      background: AppColors.accentTint, foreground: AppColors.accent);
}

/// KOSPI / KOSDAQ 표시
class MarketBadge extends StatelessWidget {
  final String market;
  const MarketBadge(this.market, {super.key});
  @override
  Widget build(BuildContext context) => DsPill(market,
      height: 20,
      background: AppColors.subtle,
      foreground: AppColors.textTertiary);
}

/// 규칙 기반 데모 데이터라는 표시 (테마·β)
class DemoTag extends StatelessWidget {
  const DemoTag({super.key});
  @override
  Widget build(BuildContext context) => const DsPill('데모 데이터',
      height: 20,
      background: AppColors.subtle,
      foreground: AppColors.textTertiary);
}

/// 공시별 "예상 CAR" 칩. 양수 빨강, 음수 파랑. ML 60일 예측에는 쓰지 않는다.
class CarBadge extends StatelessWidget {
  final double? car;
  final bool withLabel;
  const CarBadge(this.car, {super.key, this.withLabel = true});

  @override
  Widget build(BuildContext context) {
    if (car == null) {
      return const DsPill('분석 대기',
          background: AppColors.subtle, foreground: AppColors.textTertiary);
    }
    final label =
        '${arrow(car)} ${signedPct(car, digits: 1)}${withLabel ? ' 예상 CAR' : ''}'
            .trim();
    return DsPill(label,
        background: AppColors.marketTint(car),
        foreground: AppColors.market(car));
  }
}

/// 가격 등락 "▲ 5,000 (2.22%)"
class PriceChange extends StatelessWidget {
  final num? amount;
  final num? rate;
  final TextStyle? style;
  const PriceChange({super.key, this.amount, this.rate, this.style});

  @override
  Widget build(BuildContext context) {
    final v = rate ?? amount;
    if (v == null) {
      return Text('—',
          style: (style ?? AppText.labelMd).copyWith(color: AppColors.flat));
    }
    final parts = <String>[
      if (arrow(v).isNotEmpty) arrow(v),
      if (amount != null) comma(amount!.abs()),
      if (rate != null)
        amount != null ? '(${signedPct(rate)})' : signedPct(rate),
    ];
    return Text(parts.join(' '),
        style: (style ?? AppText.labelMd).copyWith(
            color: AppColors.market(v),
            fontFeatures: AppText.numeric.fontFeatures));
  }
}

/// 섹션 제목 + 오른쪽 보조 동작
class SectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final Widget? info;
  const SectionTitle(this.title, {super.key, this.trailing, this.info});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm + 4),
      child: Row(children: [
        Text(title, style: AppText.headlineSm),
        if (info != null) ...[const SizedBox(width: 4), info!],
        const Spacer(),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

/// 숫자 옆 (i). 누르면 쉬운 말 설명을 바텀시트로 보여준다.
class InfoButton extends StatelessWidget {
  final String title;
  final String body;
  const InfoButton({super.key, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      radius: 16,
      onTap: () => showInfoSheet(context, title: title, body: body),
      child: const Icon(Icons.info_outline_rounded,
          size: 16, color: AppColors.textTertiary),
    );
  }
}

Future<void> showInfoSheet(BuildContext context,
    {required String title, required String body}) {
  return showDsSheet(
    context,
    child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: AppText.headlineMd),
          const SizedBox(height: AppSpace.sm + 4),
          Text(body,
              style: AppText.bodyMd
                  .copyWith(color: AppColors.textSecondary, height: 1.6)),
          const SizedBox(height: AppSpace.xl),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인')),
          ),
        ]),
  );
}

/// 디자인 시스템 바텀시트: 위 모서리 20, 손잡이 36x4.
Future<T?> showDsSheet<T>(BuildContext context, {required Widget child}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    barrierColor: const Color(0x66000000),
    shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.sheet))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.sm, AppSpace.lg,
            AppSpace.lg + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: AppSpace.md),
            decoration: BoxDecoration(
                color: AppColors.borderStrong,
                borderRadius: BorderRadius.circular(2)),
          ),
          child,
        ]),
      ),
    ),
  );
}

/// 분석·예측 화면 맨 아래 법적 고지
class Disclaimer extends StatelessWidget {
  const Disclaimer({super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.xl),
      child: Text('투자 참고용 정보이며 투자 권유가 아닙니다. 수익을 보장하지 않습니다.',
          textAlign: TextAlign.center,
          style: AppText.bodySm.copyWith(color: AppColors.textTertiary)),
    );
  }
}

/// 기여도 막대: 가운데 0 축, 양수는 오른쪽 빨강, 음수는 왼쪽 파랑.
class ContributionBar extends StatelessWidget {
  final double value;
  final double maxAbs;
  final double height;
  const ContributionBar(
      {super.key, required this.value, required this.maxAbs, this.height = 8});

  @override
  Widget build(BuildContext context) {
    final ratio = maxAbs <= 0 ? 0.0 : (value.abs() / maxAbs).clamp(0.0, 1.0);
    return LayoutBuilder(builder: (context, c) {
      final half = c.maxWidth / 2;
      final w = half * ratio;
      return SizedBox(
        height: height,
        child: Stack(children: [
          Positioned.fill(
              child: Container(
                  decoration: BoxDecoration(
                      color: AppColors.subtle,
                      borderRadius: BorderRadius.circular(height)))),
          Positioned(
            left: value >= 0 ? half : half - w,
            width: w,
            top: 0,
            bottom: 0,
            child: Container(
                decoration: BoxDecoration(
                    color: AppColors.market(value),
                    borderRadius: BorderRadius.circular(height))),
          ),
          Positioned(
              left: half - 0.5,
              width: 1,
              top: -2,
              bottom: -2,
              child: Container(color: AppColors.borderStrong)),
        ]),
      );
    });
  }
}

/// 읽지 않음 점
class UnreadDot extends StatelessWidget {
  const UnreadDot({super.key});
  @override
  Widget build(BuildContext context) => Container(
      width: 6,
      height: 6,
      decoration:
          const BoxDecoration(color: AppColors.bull, shape: BoxShape.circle));
}

/// 빈 상태
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  const EmptyState(
      {super.key,
      required this.icon,
      required this.title,
      this.message,
      this.actionLabel,
      this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          vertical: AppSpace.xxl, horizontal: AppSpace.lg),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 40, color: AppColors.textDisabled),
        const SizedBox(height: AppSpace.sm + 4),
        Text(title,
            textAlign: TextAlign.center,
            style: AppText.headlineSm.copyWith(color: AppColors.textSecondary)),
        if (message != null) ...[
          const SizedBox(height: AppSpace.xs),
          Text(message!,
              textAlign: TextAlign.center,
              style: AppText.bodySm.copyWith(color: AppColors.textTertiary)),
        ],
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: AppSpace.md),
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ]),
    );
  }
}

/// 오류 + 다시 시도
class ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorRetry({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => EmptyState(
      icon: Icons.error_outline_rounded,
      title: '불러오지 못했어요',
      message: message,
      actionLabel: '다시 시도',
      onAction: onRetry);
}

/// 로딩 자리표시 상자 (스켈레톤)
class SkeletonBox extends StatelessWidget {
  final double height;
  final double? width;
  final double radius;
  const SkeletonBox({super.key, this.height = 16, this.width, this.radius = 8});
  @override
  Widget build(BuildContext context) => Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
          color: AppColors.subtle,
          borderRadius: BorderRadius.circular(radius)));
}

/// 카드 3장 높이의 스켈레톤 목록
class SkeletonList extends StatelessWidget {
  final int count;
  final double itemHeight;
  const SkeletonList({super.key, this.count = 3, this.itemHeight = 88});
  @override
  Widget build(BuildContext context) => Column(children: [
        for (var i = 0; i < count; i++) ...[
          SkeletonBox(height: itemHeight, radius: AppRadius.lg),
          const SizedBox(height: AppSpace.sm + 4),
        ]
      ]);
}

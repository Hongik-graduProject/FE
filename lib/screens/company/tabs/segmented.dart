import 'package:flutter/material.dart';

import '../../../utils/design_tokens.dart';

/// 회색 바탕 위 알약 토글 (기간·재무제표 구분). expand=true 면 가로를 꽉 채운다.
class Segmented<T> extends StatelessWidget {
  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;
  final bool expand;

  const Segmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final items = options.map((o) {
      final selected = o.$1 == value;
      final pill = GestureDetector(
        onTap: () => onChanged(o.$1),
        behavior: HitTestBehavior.opaque,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: selected
              ? BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  boxShadow: AppShadow.card,
                )
              : null,
          child: Text(o.$2,
              style: AppText.labelMd.copyWith(
                  color: selected ? AppColors.textPrimary : AppColors.textTertiary)),
        ),
      );
      return expand ? Expanded(child: pill) : pill;
    }).toList();

    return Container(
      padding: const EdgeInsets.all(AppSpace.xs),
      decoration: BoxDecoration(
          color: AppColors.subtle, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Row(mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min, children: items),
    );
  }
}

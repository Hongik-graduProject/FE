// lib/utils/app_theme.dart
import 'package:flutter/material.dart';

import 'design_tokens.dart';

class AppTheme {
  static ThemeData get lightTheme {
    final outline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide.none,
    );
    return ThemeData(
      useMaterial3: true,
      // DESIGN.md 의 대체 글꼴 순서. iOS 는 Apple SD Gothic Neo 로 그려진다.
      fontFamilyFallback: const ['Pretendard', 'Apple SD Gothic Neo', 'Malgun Gothic'],
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.brand,
        primary: AppColors.brand,
        secondary: AppColors.accent,
        surface: AppColors.card,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.canvas,
      splashFactory: InkRipple.splashFactory,

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.canvas,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 56,
        titleTextStyle: AppText.headlineMd,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.borderStrong,
          disabledForegroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          elevation: 0,
          textStyle: AppText.labelLg.copyWith(fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          minimumSize: const Size(double.infinity, 52),
          side: const BorderSide(color: AppColors.borderStrong),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          textStyle: AppText.labelLg.copyWith(fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          textStyle: AppText.labelLg,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.subtle,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: outline,
        enabledBorder: outline,
        focusedBorder: outline.copyWith(
            borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
        errorBorder: outline.copyWith(borderSide: const BorderSide(color: AppColors.error)),
        focusedErrorBorder:
            outline.copyWith(borderSide: const BorderSide(color: AppColors.error, width: 1.5)),
        hintStyle: AppText.bodyMd.copyWith(color: AppColors.textTertiary),
        labelStyle: AppText.labelMd,
        errorStyle: AppText.labelSm.copyWith(color: AppColors.error),
      ),

      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppColors.border),
        ),
      ),

      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.textPrimary,
        unselectedLabelColor: AppColors.textTertiary,
        labelStyle: AppText.labelLg,
        unselectedLabelStyle: AppText.labelLg,
        indicatorColor: AppColors.brand,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: AppColors.border,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.card,
        selectedColor: AppColors.brand,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        labelStyle: AppText.labelMd,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: AppText.bodyMd.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        titleTextStyle: AppText.headlineMd,
      ),

      dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1, space: 1),

      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((s) => AppText.labelSm.copyWith(
            color: s.contains(WidgetState.selected) ? AppColors.brand : AppColors.textTertiary,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500)),
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
            size: 24,
            color: s.contains(WidgetState.selected) ? AppColors.brand : AppColors.textTertiary)),
      ),
    );
  }
}

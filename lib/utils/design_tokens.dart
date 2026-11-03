// lib/utils/design_tokens.dart
// Stitch 디자인 시스템 "Disclosure Radar" (docs/stitch-handoff, DESIGN.md) 의 토큰.
// 새 화면은 색·글자·간격을 여기서만 가져온다.

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // 브랜드·상호작용
  static const brand = Color(0xFF1A237E); // 기본 버튼, 하단 탭 활성, 탭 밑줄
  static const brandPressed = Color(0xFF121858);
  static const accent = Color(0xFF3D5AFE); // 토글, 선택 칩, 링크
  static const accentTint = Color(0xFFEEF2FF); // 테마 칩·보조 버튼 배경

  // 한국 시장 색 규칙: 상승·양수 빨강, 하락·음수 파랑. 초록을 "좋음" 에 쓰지 않는다.
  static const bull = Color(0xFFE53935);
  static const bullTint = Color(0xFFFDECEC);
  static const bear = Color(0xFF1E63D6);
  static const bearTint = Color(0xFFEDF4FC);
  static const flat = Color(0xFF8E929B);

  // 표면
  static const canvas = Color(0xFFF7F8FA);
  static const card = Color(0xFFFFFFFF);
  static const subtle = Color(0xFFF1F3F5); // 검색창, 데모 태그, 비활성 영역

  // 글자
  static const textPrimary = Color(0xFF191F28);
  static const textSecondary = Color(0xFF4E5968);
  static const textTertiary = Color(0xFF8B95A1);
  static const textDisabled = Color(0xFFB0B8C1);

  // 선
  static const border = Color(0xFFE5E8EB);
  static const borderStrong = Color(0xFFD1D6DB);

  static const error = Color(0xFFBA1A1A);
  static const errorTint = Color(0xFFFFDAD6);

  /// 값의 부호로 시장 색을 고른다 (0 은 회색).
  static Color market(num? v) =>
      v == null || v == 0 ? flat : (v > 0 ? bull : bear);
  static Color marketTint(num? v) =>
      v == null || v == 0 ? subtle : (v > 0 ? bullTint : bearTint);
}

class AppText {
  AppText._();

  static const _tnum = [FontFeature.tabularFigures()];

  static const headlineXl = TextStyle(
      fontSize: 28, fontWeight: FontWeight.w700, height: 36 / 28, letterSpacing: -0.56, color: AppColors.textPrimary);
  static const headlineLg = TextStyle(
      fontSize: 22, fontWeight: FontWeight.w700, height: 30 / 22, letterSpacing: -0.33, color: AppColors.textPrimary);
  static const headlineMd = TextStyle(
      fontSize: 18, fontWeight: FontWeight.w700, height: 26 / 18, letterSpacing: -0.18, color: AppColors.textPrimary);
  static const headlineSm = TextStyle(
      fontSize: 16, fontWeight: FontWeight.w600, height: 24 / 16, letterSpacing: -0.08, color: AppColors.textPrimary);
  static const bodyLg = TextStyle(fontSize: 16, height: 24 / 16, color: AppColors.textPrimary);
  static const bodyMd = TextStyle(fontSize: 14, height: 20 / 14, color: AppColors.textPrimary);
  static const bodySm = TextStyle(fontSize: 13, height: 18 / 13, color: AppColors.textSecondary);
  static const labelLg = TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 20 / 14, color: AppColors.textPrimary);
  static const labelMd = TextStyle(fontSize: 12, fontWeight: FontWeight.w600, height: 16 / 12, color: AppColors.textSecondary);
  static const labelSm = TextStyle(fontSize: 11, fontWeight: FontWeight.w500, height: 14 / 11, color: AppColors.textTertiary);

  // 숫자는 자릿수가 세로로 맞도록 고정폭 숫자를 쓴다.
  static const numericHero = TextStyle(
      fontSize: 32, fontWeight: FontWeight.w700, height: 40 / 32, letterSpacing: -0.64,
      color: AppColors.textPrimary, fontFeatures: _tnum);
  static const numericMetric = TextStyle(
      fontSize: 20, fontWeight: FontWeight.w700, height: 26 / 20, letterSpacing: -0.2,
      color: AppColors.textPrimary, fontFeatures: _tnum);
  static const numeric = TextStyle(fontFeatures: _tnum);
}

class AppSpace {
  AppSpace._();
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 20.0; // 화면 좌우 여백, 카드 안쪽 여백
  static const xl = 24.0; // 섹션 사이
  static const xxl = 32.0;
}

class AppRadius {
  AppRadius._();
  static const sm = 8.0; // 칩·아이콘 버튼
  static const md = 12.0; // 버튼·입력창
  static const lg = 16.0; // 카드
  static const sheet = 20.0; // 바텀시트 위 모서리
}

class AppShadow {
  AppShadow._();
  static const card = [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))];
  static const raised = [BoxShadow(color: Color(0x141A237E), blurRadius: 24, offset: Offset(0, 8))];
}

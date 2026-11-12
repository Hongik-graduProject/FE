// lib/utils/design_tokens.dart
// Stitch 디자인 시스템 "Disclosure Radar" 다크 테마 토큰 (2026-11-12 시안).
// 새 화면은 색·글자·간격을 여기서만 가져온다.

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Stitch "Disclosure Radar" 다크 팔레트 (FE/Referance/stitch DESIGN.md).
  // 브랜드·상호작용
  static const brand = Color(0xFF3B66FF); // 기본 버튼, 하단 탭 활성, 탭 밑줄
  static const brandPressed = Color(0xFF2F52CC);
  static const accent = Color(0xFF4F75FF); // 토글, 선택 칩, 링크
  static const accentTint = Color(0xFF1B2A5C); // 테마 칩·보조 버튼 배경
  static const glow = Color(0x593B66FF); // 레이더·강조 카드의 푸른 빛

  // 한국 시장 색 규칙: 상승·양수 빨강, 하락·음수 파랑. 초록을 "좋음" 에 쓰지 않는다.
  static const bull = Color(0xFFF04438);
  static const bullTint = Color(0xFF2B203B);
  static const bear = Color(0xFF2E90FA);
  static const bearTint = Color(0xFF122551);
  static const flat = Color(0xFF8E90A1);

  // 표면 (깊은 남색 캔버스 위에 한 단계씩 밝아지는 카드)
  static const canvas = Color(0xFF0A1128);
  static const card = Color(0xFF101B3B);
  static const raised = Color(0xFF16234D); // 카드 안의 카드, 선택된 항목
  static const subtle = Color(0xFF16234D); // 검색창, 데모 태그, 비활성 영역

  // 글자
  static const textPrimary = Color(0xFFEEF1FF);
  static const textSecondary = Color(0xFFC4C5D8);
  static const textTertiary = Color(0xFF8E90A1);
  static const textDisabled = Color(0xFF5A6178);

  // 선
  static const border = Color(0xFF222D4A);
  static const borderStrong = Color(0xFF34406A);

  static const error = Color(0xFFFF6B5E);
  static const errorTint = Color(0xFF3A1A24);

  /// 값의 부호로 시장 색을 고른다 (0 은 회색).
  static Color market(num? v) =>
      v == null || v == 0 ? flat : (v > 0 ? bull : bear);
  static Color marketTint(num? v) =>
      v == null || v == 0 ? subtle : (v > 0 ? bullTint : bearTint);
}

class AppText {
  AppText._();

  // 제목 Space Grotesk, 본문 Hanken Grotesk(한글은 시스템 글꼴로 대체), 숫자·코드 JetBrains Mono.
  // 가변 글꼴이라 굵기는 fontVariations 로 준다. fontWeight 는 한글 대체 글꼴용이다.
  static const display = 'SpaceGrotesk';
  static const mono = 'JetBrainsMono';
  static const _tnum = [FontFeature.tabularFigures(), FontFeature.slashedZero()];
  static const _w400 = [FontVariation.weight(400)];
  static const _w500 = [FontVariation.weight(500)];
  static const _w600 = [FontVariation.weight(600)];
  static const _w700 = [FontVariation.weight(700)];

  static const headlineXl = TextStyle(
      fontFamily: display, fontSize: 28, fontWeight: FontWeight.w700, fontVariations: _w700,
      height: 36 / 28, letterSpacing: -0.6, color: AppColors.textPrimary);
  static const headlineLg = TextStyle(
      fontFamily: display, fontSize: 22, fontWeight: FontWeight.w700, fontVariations: _w700,
      height: 30 / 22, letterSpacing: -0.33, color: AppColors.textPrimary);
  static const headlineMd = TextStyle(
      fontFamily: display, fontSize: 18, fontWeight: FontWeight.w700, fontVariations: _w700,
      height: 26 / 18, letterSpacing: -0.18, color: AppColors.textPrimary);
  static const headlineSm = TextStyle(
      fontFamily: display, fontSize: 16, fontWeight: FontWeight.w600, fontVariations: _w600,
      height: 24 / 16, letterSpacing: -0.08, color: AppColors.textPrimary);
  static const bodyLg = TextStyle(fontSize: 16, height: 26 / 16, fontVariations: _w400, color: AppColors.textPrimary);
  static const bodyMd = TextStyle(fontSize: 14, height: 22 / 14, fontVariations: _w400, color: AppColors.textPrimary);
  static const bodySm = TextStyle(fontSize: 13, height: 19 / 13, fontVariations: _w400, color: AppColors.textSecondary);
  static const labelLg = TextStyle(
      fontSize: 14, fontWeight: FontWeight.w600, fontVariations: _w600, height: 20 / 14, color: AppColors.textPrimary);
  static const labelMd = TextStyle(
      fontSize: 12, fontWeight: FontWeight.w600, fontVariations: _w600, height: 16 / 12, color: AppColors.textSecondary);
  static const labelSm = TextStyle(
      fontSize: 11, fontWeight: FontWeight.w500, fontVariations: _w500, height: 14 / 11, color: AppColors.textTertiary);

  /// 터미널 느낌의 작은 대문자 라벨 (예: LIVE DART, LATENCY).
  static const monoLabel = TextStyle(
      fontFamily: mono, fontSize: 11, fontWeight: FontWeight.w500, fontVariations: _w500,
      height: 14 / 11, letterSpacing: 0.44, color: AppColors.textTertiary, fontFeatures: _tnum);
  static const monoBadge = TextStyle(
      fontFamily: mono, fontSize: 10, fontWeight: FontWeight.w600, fontVariations: _w600,
      height: 12 / 10, letterSpacing: 0.6, color: AppColors.textSecondary, fontFeatures: _tnum);

  // 숫자는 JetBrains Mono 고정폭으로 자릿수를 세로로 맞춘다.
  static const numericHero = TextStyle(
      fontFamily: mono, fontSize: 32, fontWeight: FontWeight.w700, fontVariations: _w700,
      height: 38 / 32, letterSpacing: -0.96, color: AppColors.textPrimary, fontFeatures: _tnum);
  static const numericMetric = TextStyle(
      fontFamily: mono, fontSize: 18, fontWeight: FontWeight.w600, fontVariations: _w600,
      height: 24 / 18, letterSpacing: -0.36, color: AppColors.textPrimary, fontFeatures: _tnum);
  static const numeric = TextStyle(fontFamily: mono, fontFeatures: _tnum);
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
  static const xs = 4.0; // 배지
  static const sm = 8.0; // 칩·아이콘 버튼, 카드
  static const md = 12.0; // 버튼·입력창
  static const lg = 16.0; // 큰 카드·바텀시트
  static const sheet = 20.0; // 바텀시트 위 모서리
}

class AppShadow {
  AppShadow._();
  // 어두운 배경에선 큰 블러가 거의 안 보이고 스크롤 비용만 크다. 작게 둔다.
  static const card = [BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2))];
  static const raised = [BoxShadow(color: Color(0x2E3B66FF), blurRadius: 12, spreadRadius: -2)];
}

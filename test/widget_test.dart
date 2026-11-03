// Smoke test: the app builds, shows the splash screen, then moves to login (no saved token).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:disclosure_app/main.dart';
import 'package:disclosure_app/services/api_service.dart';

void main() {
  testWidgets('DisclosureApp builds and leaves the splash screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    ApiService().init();
    await tester.pumpWidget(const DisclosureApp());
    expect(find.byType(MaterialApp), findsOneWidget);

    // 스플래시는 1.8초 뒤 로그인 여부를 확인하고 이동한다. 타이머가 남지 않게 시간을 흘려보낸다.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('로그인'), findsWidgets);
  });
}

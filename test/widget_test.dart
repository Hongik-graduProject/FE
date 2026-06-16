// Smoke test: the app builds and shows its first (splash) screen.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:disclosure_app/main.dart';
import 'package:disclosure_app/services/api_service.dart';

void main() {
  testWidgets('DisclosureApp builds without crashing', (WidgetTester tester) async {
    ApiService().init();
    await tester.pumpWidget(const DisclosureApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}

// 타임머신·반박 패널이 진입하자마자 예외 없이 로딩 상태를 그리는지 확인한다.
// (회귀: setState(() => _future = ...) 는 Future 를 돌려줘 Flutter 가 예외를 던졌다)
import 'package:disclosure_app/screens/company/report_extras.dart';
import 'package:disclosure_app/services/api_service.dart';
import 'package:disclosure_app/widgets/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() => ApiService().init());

  Future<void> expectLoading(WidgetTester tester, Widget section, String title) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: section))));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text(title), findsOneWidget);
    expect(find.byType(SkeletonBox), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 2)); // Dio 타임아웃 타이머 정리
  }

  testWidgets('타임머신 패널',
      (t) => expectLoading(t, const ReplaySection(reportId: 1, name: '삼성전자'), '타임머신 리플레이 (실시간 성적표)'));
  testWidgets('반박 모드 패널',
      (t) => expectLoading(t, const CritiqueSection(reportId: 1, ticker: '005930'), '"이 분석이 틀렸다면?" (자가 검증)'));
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:travel_dosuka/widgets/common/dosuka_scaffold.dart';

void main() {
  testWidgets('DosukScaffold renders title', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DosukScaffold(
          title: 'テスト',
          child: SizedBox(),
        ),
      ),
    );
    expect(find.text('テスト'), findsOneWidget);
  });
}

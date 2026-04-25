import 'package:flutter_test/flutter_test.dart';

import 'package:caliana/main.dart';

void main() {
  testWidgets('Caliana app boots without throwing', (WidgetTester tester) async {
    await tester.pumpWidget(
      const CalianaApp(showOnboarding: false, firebaseReady: false),
    );
    // First frame should produce a MaterialApp.
    expect(find.byType(CalianaApp), findsOneWidget);
  });
}

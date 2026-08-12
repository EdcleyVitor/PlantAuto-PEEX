import 'package:flutter_test/flutter_test.dart';

import 'package:plantauto_peeex/main.dart';

void main() {
  testWidgets('App inicia', (WidgetTester tester) async {
    await tester.pumpWidget(const PlantAutoApp());
    expect(find.byType(PlantAutoApp), findsOneWidget);
  });
}

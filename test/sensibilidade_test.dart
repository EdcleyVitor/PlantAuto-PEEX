import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:plantauto_peeex/models/planta.dart';
import 'package:plantauto_peeex/screens/sensibilidade_screen.dart';

void main() {
  testWidgets('SensibilidadeScreen abre sem erro', (tester) async {
    final planta = Planta(
      id: 'p1',
      nome: 'Alface',
      umidadeIdeal: 70,
      fatorPlanta: 1.0,
      dataAdicionada: DateTime.now(),
    );
    await tester.pumpWidget(
      MaterialApp(home: SensibilidadeScreen(planta: planta)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SensibilidadeScreen), findsOneWidget);
  });
}

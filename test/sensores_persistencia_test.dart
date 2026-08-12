import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:plantauto_peeex/models/planta.dart';
import 'package:plantauto_peeex/screens/sensibilidade_screen.dart';
import 'package:plantauto_peeex/services/plantacao_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PlantacaoStore.instance.carregar();
  });

  testWidgets('toggle na tela Sensores persiste ao reabrir', (tester) async {
    final planta = Planta(
      id: 'p1',
      nome: 'Alface',
      umidadeIdeal: 70,
      fatorPlanta: 1.0,
      dataAdicionada: DateTime(2026, 1, 1),
    );
    await PlantacaoStore.instance.adicionar(planta);

    // 1a abertura
    await tester.pumpWidget(
      MaterialApp(home: SensibilidadeScreen(planta: planta)),
    );
    await tester.pumpAndSettle();

    // Rola até a seção "Inteligência" (o switch fica abaixo da dobra)
    await tester.scrollUntilVisible(
      find.text('Rega inteligente (IA)'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    // Liga a "Rega inteligente (IA)"
    await tester.tap(
      find.widgetWithText(SwitchListTile, 'Rega inteligente (IA)'),
    );
    await tester.pumpAndSettle();

    // Confere no store
    final atualizado = PlantacaoStore.instance.plantaPorId('p1');
    expect(atualizado!.mlAtivo, isTrue);

    // "Sai" (descarta a tela) e reabre com a mesma planta
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      MaterialApp(home: SensibilidadeScreen(planta: planta)),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Rega inteligente (IA)'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    // O switch deve continuar ligado
    final sw = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'Rega inteligente (IA)'),
    );
    expect(sw.value, isTrue);
  });

  testWidgets('amostras de calibração persistem ao reabrir a tela',
      (tester) async {
    final planta = Planta(
      id: 'p1',
      nome: 'Alface',
      umidadeIdeal: 70,
      fatorPlanta: 1.0,
      dataAdicionada: DateTime(2026, 1, 1),
    );
    await PlantacaoStore.instance.adicionar(planta);
    await PlantacaoStore.instance.atualizarConfig(
      'p1',
      70,
      1.0,
      80,
      amostras: {'seco': 3200},
    );

    // 1a abertura: a amostra capturada deve aparecer.
    await tester.pumpWidget(
      MaterialApp(home: SensibilidadeScreen(planta: planta)),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Solo seco'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('3200'), findsOneWidget);
    expect(find.textContaining('(1 amostra)'), findsOneWidget);

    // Sai e reabre: a amostra continua lá.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      MaterialApp(home: SensibilidadeScreen(planta: planta)),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Solo seco'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('3200'), findsOneWidget);
    expect(find.textContaining('(1 amostra)'), findsOneWidget);
  });

  testWidgets('modo sensor sensível persiste ao reabrir a tela',
      (tester) async {
    final planta = Planta(
      id: 'p1',
      nome: 'Alface',
      umidadeIdeal: 70,
      fatorPlanta: 1.0,
      dataAdicionada: DateTime(2026, 1, 1),
    );
    await PlantacaoStore.instance.adicionar(planta);

    // 1a abertura
    await tester.pumpWidget(
      MaterialApp(home: SensibilidadeScreen(planta: planta)),
    );
    await tester.pumpAndSettle();

    // Rola até a seção "Sensor sensível"
    await tester.scrollUntilVisible(
      find.text('Modo sensor sensível'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    // Liga o modo sensível
    await tester.tap(
      find.widgetWithText(SwitchListTile, 'Modo sensor sensível'),
    );
    await tester.pumpAndSettle();

    // O slider de sensibilidade deve aparecer
    expect(find.text('Sensibilidade'), findsOneWidget);

    final atualizado = PlantacaoStore.instance.plantaPorId('p1');
    expect(atualizado!.modoSensivel, isTrue);

    // "Sai" e reabre: o modo deve continuar ligado
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      MaterialApp(home: SensibilidadeScreen(planta: planta)),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Modo sensor sensível'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    final sw = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'Modo sensor sensível'),
    );
    expect(sw.value, isTrue);
    // O slider continua visível (modo ligado)
    expect(find.text('Sensibilidade'), findsOneWidget);
  });
}

extension on PlantacaoStore {
  Planta? plantaPorId(String id) {
    for (final p in plantas) {
      if (p.id == id) return p;
    }
    return null;
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:plantauto_peeex/models/planta.dart';
import 'package:plantauto_peeex/services/plantacao_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PlantacaoStore.instance.carregar();
  });

  test('configuração persiste após recarregar o store', () async {
    await PlantacaoStore.instance.adicionar(
      Planta(
        id: 'p1',
        nome: 'Alface',
        umidadeIdeal: 70,
        fatorPlanta: 1.0,
        dataAdicionada: DateTime(2026, 1, 1),
      ),
    );

    await PlantacaoStore.instance.atualizarConfig(
      'p1',
      65,
      1.5,
      85,
      regaInicio: 55,
      regaFim: 80,
      mlAtivo: true,
      mlRainAtivo: true,
      releAtivoAlto: true,
      modoSensivel: true,
      sensNivel: 30,
      amostras: {'seco': 3200, 'umido': 900, 'agua': 400},
    );

    var planta = PlantacaoStore.instance.plantaPorId('p1');
    expect(planta, isNotNull);
    expect(planta!.umidadeIdeal, 65);
    expect(planta.regaInicio, 55);
    expect(planta.mlAtivo, isTrue);
    expect(planta.mlRainAtivo, isTrue);
    expect(planta.modoSensivel, isTrue);
    expect(planta.sensNivel, 30);
    expect(planta.amostras['seco'], 3200);
    expect(planta.amostras['umido'], 900);

    // Simula sair e voltar ao app: recarrega tudo do disco.
    await PlantacaoStore.instance.carregar();
    planta = PlantacaoStore.instance.plantaPorId('p1');
    expect(planta, isNotNull);
    expect(planta!.umidadeIdeal, 65);
    expect(planta.regaInicio, 55);
    expect(planta.mlAtivo, isTrue);
    expect(planta.mlRainAtivo, isTrue);
    expect(planta.modoSensivel, isTrue);
    expect(planta.sensNivel, 30);
    expect(planta.amostras['seco'], 3200);
    expect(planta.amostras['umido'], 900);
    expect(planta.amostras['agua'], 400);
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

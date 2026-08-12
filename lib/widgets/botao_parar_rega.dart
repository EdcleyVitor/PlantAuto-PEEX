import 'package:flutter/material.dart';
import '../services/bluetooth_service.dart';

/// Botão flutuante VERMELHO (canto inferior direito) para parar a regação.
/// Só aparece enquanto algum ESP32 conectado estiver regando. Ícone: gota
/// de água com um X no meio.
class BotaoPararRega extends StatelessWidget {
  const BotaoPararRega({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: BluetoothService.instance,
      builder: (context, _) {
        final regando = BluetoothService.instance.conectadosAtivos
            .where((d) => d.bombaLigada)
            .toList();
        if (regando.isEmpty) return const SizedBox.shrink();
        return FloatingActionButton(
          heroTag: 'botao_parar_rega',
          tooltip: 'Parar regação',
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          onPressed: () async {
            final bt = BluetoothService.instance;
            for (final disp in regando) {
              await bt.desligarBomba(disp);
            }
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Regação parada.')),
            );
          },
          child: SizedBox(
            width: 32,
            height: 32,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.water_drop, size: 30, color: Colors.white),
                Container(
                  width: 15,
                  height: 15,
                  decoration: const BoxDecoration(
                    color: Color(0xFFB71C1C),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 11, color: Colors.white),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

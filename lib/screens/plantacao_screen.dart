import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/planta.dart';
import '../services/bluetooth_service.dart';
import '../services/plantacao_store.dart';
import 'adicionar_planta_screen.dart';
import 'planta_detail_screen.dart';
import '../widgets/botao_parar_rega.dart';

class PlantacaoScreen extends StatelessWidget {
  const PlantacaoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = PlantacaoStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Plantação')),
          body: store.plantas.isEmpty
              ? _EmptyState()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                  children: [
                    for (final planta in store.plantas)
                      _PlantaCard(
                        planta: planta,
                        ativa: store.plantaAtiva?.id == planta.id,
                      ),
                  ],
                ),
          floatingActionButton: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const BotaoPararRega(),
              const SizedBox(height: 12),
              FloatingActionButton.extended(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AdicionarPlantaScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('Adicionar Planta'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/logo.png', width: 96, height: 96),
          const SizedBox(height: 16),
          Text('Nenhuma planta adicionada',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Toque em "Adicionar Planta" para começar sua horta.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _PlantaCard extends StatelessWidget {
  const _PlantaCard({required this.planta, required this.ativa});
  final Planta planta;
  final bool ativa;

  Future<void> _adicionarEsp32(BuildContext context) async {
    final bt = BluetoothService.instance;
    final conectados = bt.conectadosAtivos;
    if (conectados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Nenhum ESP32 conectado. Conecte na aba Conectividade primeiro.'),
        ),
      );
      return;
    }
    final escolhido = await showModalBottomSheet<DispositivoConectado>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Escolha o ESP32 para a planta "${planta.nome}"',
                  style: Theme.of(ctx).textTheme.titleMedium),
            ),
            for (final disp in conectados)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      Theme.of(ctx).colorScheme.secondary.withValues(alpha: 0.2),
                  child: Icon(Icons.memory,
                      color: Theme.of(ctx).colorScheme.secondary),
                ),
                title: Text(disp.nome),
                subtitle: Text(disp.id),
                onTap: () => Navigator.pop(ctx, disp),
              ),
          ],
        ),
      ),
    );
    if (escolhido != null) {
      bt.vincularPlanta(escolhido, planta);
      await PlantacaoStore.instance
          .vincularEsp32(planta.id, escolhido.id, escolhido.nome);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'ESP32 "${escolhido.nome}" vinculado à ${planta.nome}'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: ativa ? cores.primary : Colors.transparent,
          width: 2,
        ),
      ),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PlantaDetailScreen(planta: planta),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  planta.imagemPerfil != null &&
                          planta.imagemPerfil!.isNotEmpty
                      ? CircleAvatar(
                          radius: 24,
                          backgroundImage: MemoryImage(
                            base64Decode(planta.imagemPerfil!),
                          ),
                        )
                      : CircleAvatar(
                          backgroundColor:
                              cores.primary.withValues(alpha: 0.15),
                          child: Icon(Icons.grass, color: cores.primary),
                        ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          planta.nome,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (planta.esp32Nome != null)
                          Row(
                            children: [
                              Icon(Icons.memory,
                                  size: 14, color: cores.secondary),
                              const SizedBox(width: 4),
                              Text(
                                planta.esp32Nome!,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: cores.secondary),
                              ),
                            ],
                          )
                        else if (ativa)
                          Text(
                            'Planta ativa',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: cores.primary),
                          ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (opcao) {
                      if (opcao == 'ativa') {
                        PlantacaoStore.instance.setPlantaAtiva(planta.id);
                      } else if (opcao == 'esp32') {
                        _adicionarEsp32(context);
                      } else if (opcao == 'remover') {
                        PlantacaoStore.instance.remover(planta.id);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'ativa',
                        child: Text('Definir como ativa'),
                      ),
                      const PopupMenuItem(
                        value: 'esp32',
                        child: Text('Adicionar ESP32'),
                      ),
                      const PopupMenuItem(
                        value: 'remover',
                        child: Text('Remover'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _InfoItem(
                      icon: Icons.water_drop_outlined,
                      rotulo: 'Umidade ideal',
                      valor: '${planta.umidadeIdeal}%',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _InfoItem(
                      icon: Icons.tune,
                      rotulo: 'Irrigação',
                      valor: planta.fatorNome,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _InfoItem(
                      icon: Icons.south_west,
                      rotulo: 'Regar <',
                      valor: '${planta.regaInicio}%',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _InfoItem(
                      icon: Icons.north_east,
                      rotulo: 'Parar >',
                      valor: '${planta.regaFim}%',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem({
    required this.icon,
    required this.rotulo,
    required this.valor,
  });
  final IconData icon;
  final String rotulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cores.secondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: cores.secondary),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(rotulo, style: Theme.of(context).textTheme.bodySmall),
              Text(
                valor,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

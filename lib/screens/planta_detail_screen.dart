import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/leitura.dart';
import '../models/planta.dart';
import '../services/bluetooth_service.dart';
import '../services/leitura_store.dart';
import '../services/plantacao_store.dart';
import 'configuracao_planta_screen.dart';
import 'estatisticas_screen.dart';
import 'relatorios_screen.dart';
import 'sensibilidade_screen.dart';

class PlantaDetailScreen extends StatefulWidget {
  const PlantaDetailScreen({super.key, required this.planta});

  final Planta planta;

  @override
  State<PlantaDetailScreen> createState() => _PlantaDetailScreenState();
}

class _PlantaDetailScreenState extends State<PlantaDetailScreen> {
  List<Leitura>? _offline;

  @override
  void initState() {
    super.initState();
    _carregarOffline();
  }

  Future<void> _carregarOffline() async {
    final esp32Id = widget.planta.esp32Id;
    if (esp32Id == null) return;
    final leituras = await LeituraStore.instance.carregarLeituras(esp32Id);
    if (mounted) setState(() => _offline = leituras);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        BluetoothService.instance,
        PlantacaoStore.instance,
      ]),
      builder: (context, _) {
        final bt = BluetoothService.instance;
        final planta = widget.planta;
        final disp = planta.esp32Id != null
            ? bt.dispositivoPorId(planta.esp32Id!)
            : null;
        final conectado = disp != null && disp.conectado;
        final leituras =
            conectado ? disp.leituras : (_offline ?? <Leitura>[]);
        return Scaffold(
          appBar: AppBar(title: Text(planta.nome)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (!conectado) ...[
                _SemConexao(planta: planta),
                const SizedBox(height: 12),
              ],
              _ResumoAoVivo(
                nome: disp?.nome ?? planta.esp32Nome ?? 'ESP32',
                conectado: conectado,
                leituras: leituras,
                irrigacoesHoje: conectado ? disp.irrigacoesHoje : 0,
                regaInicio: planta.regaInicio,
                regaFim: planta.regaFim,
                fatorNome: planta.fatorNome,
                imagemPerfil: planta.imagemPerfil,
              ),
              const SizedBox(height: 12),
              Text('Ações', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _AcaoCard(
                      icone: Icons.query_stats,
                      cor: Colors.blue,
                      rotulo: 'Estatísticas',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => EstatisticasScreen(
                              planta: planta,
                              leituras: leituras,
                              conectado: conectado,
                              irrigacoesHoje: conectado
                                  ? disp.irrigacoesHoje
                                  : 0,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _AcaoCard(
                      icone: Icons.sensors,
                      cor: Colors.green,
                      rotulo: 'Sensores',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SensibilidadeScreen(planta: planta),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _AcaoCard(
                      icone: Icons.description_outlined,
                      cor: Colors.blueGrey,
                      rotulo: 'Relatórios',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => RelatoriosScreen(
                              planta: planta,
                              leituras: leituras,
                              conectado: conectado,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _AcaoCard(
                      icone: Icons.settings_outlined,
                      cor: Colors.deepPurple,
                      rotulo: 'Configurações',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                ConfiguracaoPlantaScreen(planta: planta),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}

class _AcaoCard extends StatelessWidget {
  const _AcaoCard({
    required this.icone,
    required this.cor,
    required this.rotulo,
    required this.onTap,
  });
  final IconData icone;
  final Color cor;
  final String rotulo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cor.withValues(alpha: 0.3)),
      ),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: cor.withValues(alpha: 0.15),
                child: Icon(icone, color: cor, size: 24),
              ),
              const SizedBox(height: 8),
              Text(rotulo,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SemConexao extends StatelessWidget {
  const _SemConexao({required this.planta});
  final Planta planta;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: cores.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.bluetooth_disabled, size: 40, color: cores.primary),
            const SizedBox(height: 12),
            Text(
              planta.esp32Id == null
                  ? 'Nenhum ESP32 vinculado a esta planta.'
                  : 'ESP32 vinculado, mas não conectado.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(
              planta.esp32Id == null
                  ? 'Toque nos 3 pontinhos do card e escolha "Adicionar ESP32".'
                  : 'Conecte na aba Conectividade para ver os dados ao vivo.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ResumoAoVivo extends StatelessWidget {
  const _ResumoAoVivo({
    required this.nome,
    required this.conectado,
    required this.leituras,
    required this.irrigacoesHoje,
    required this.regaInicio,
    required this.regaFim,
    required this.fatorNome,
    this.imagemPerfil,
  });
  final String nome;
  final bool conectado;
  final List<Leitura> leituras;
  final int irrigacoesHoje;
  final int regaInicio;
  final int regaFim;
  final String fatorNome;
  final String? imagemPerfil;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    final ultima = leituras.isNotEmpty ? leituras.last : null;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: cores.primary.withValues(alpha: 0.10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (imagemPerfil != null && imagemPerfil!.isNotEmpty) ...[
                  CircleAvatar(
                    radius: 22,
                    backgroundImage: MemoryImage(
                      base64Decode(imagemPerfil!),
                    ),
                  ),
                  const SizedBox(width: 10),
                ] else ...[
                  Icon(Icons.memory, color: cores.secondary),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(nome,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: conectado
                        ? Colors.green.withValues(alpha: 0.2)
                        : cores.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.circle,
                          size: 10,
                          color: conectado
                              ? Colors.green
                              : Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                        conectado ? 'AO VIVO' : 'LOCAL',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ValorVivo(
                    icon: Icons.water_drop,
                    cor: Colors.blue,
                    rotulo: 'Solo',
                    valor: ultima != null ? '${ultima.umidadeSolo}%' : '—',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ValorVivo(
                    icon: Icons.cloud,
                    cor: Colors.teal,
                    rotulo: 'Ar',
                    valor: ultima != null ? '${ultima.umidadeAr}%' : '—',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ValorVivo(
                    icon: Icons.thermostat,
                    cor: Colors.orange,
                    rotulo: 'Temp.',
                    valor: ultima != null
                        ? '${ultima.temperatura.toStringAsFixed(1)}°'
                        : '—',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ValorVivo(
                    icon: Icons.power,
                    cor: Colors.blue,
                    rotulo: 'Regas hoje',
                    valor: '$irrigacoesHoje',
                  ),
                ),
              ],
            ),
            if (leituras.any((l) => l.vazao > 0)) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _ValorVivo(
                      icon: Icons.water_outlined,
                      cor: Colors.cyan,
                      rotulo: 'Vazão',
                      valor: ultima != null
                          ? '${ultima.vazao.toStringAsFixed(2)} L/min'
                          : '—',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ValorVivo(
                      icon: Icons.local_drink_outlined,
                      cor: Colors.indigo,
                      rotulo: 'Consumo',
                      valor: ultima != null
                          ? '${ultima.litros.toStringAsFixed(2)} L'
                          : '—',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ValorVivo(
                      icon: Icons.south_west,
                      cor: Colors.purple,
                      rotulo: 'Regar <',
                      valor: '$regaInicio%',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ValorVivo(
                      icon: Icons.north_east,
                      cor: Colors.purple,
                      rotulo: 'Parar >',
                      valor: '$regaFim%',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ValorVivo(
                      icon: Icons.tune,
                      cor: Colors.green,
                      rotulo: 'Irrig.',
                      valor: fatorNome,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ValorVivo extends StatelessWidget {
  const _ValorVivo({
    required this.icon,
    required this.cor,
    required this.rotulo,
    required this.valor,
  });
  final IconData icon;
  final Color cor;
  final String rotulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: cor, size: 22),
          const SizedBox(height: 4),
          Text(valor,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          Text(rotulo, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

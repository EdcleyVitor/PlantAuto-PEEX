import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/leitura.dart';
import '../models/planta.dart';
import '../services/bluetooth_service.dart';

class EstatisticasScreen extends StatelessWidget {
  const EstatisticasScreen({
    super.key,
    required this.planta,
    required this.leituras,
    required this.conectado,
    required this.irrigacoesHoje,
  });

  final Planta planta;
  final List<Leitura> leituras;
  final bool conectado;
  final int irrigacoesHoje;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Estatísticas')),
      body: leituras.isEmpty
          ? const Center(child: Text('Aguardando dados de telemetria...'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _ResumoEstatistico(leituras: leituras),
                const SizedBox(height: 12),
                _TaxasCard(
                  leituras: leituras,
                  regasPorDia: BluetoothService.instance.regasPorDia,
                ),
                const SizedBox(height: 12),
                _GraficoCard(
                  titulo: 'Umidade do solo (%)',
                  icone: Icons.water_drop_outlined,
                  cor: Colors.blue,
                  valores: leituras.map((l) => l.umidadeSolo.toDouble()).toList(),
                  ideal: planta.umidadeIdeal.toDouble(),
                  minVal: 0,
                  maxVal: 100,
                ),
                const SizedBox(height: 12),
                _GraficoCard(
                  titulo: 'Umidade do ar (%)',
                  icone: Icons.cloud_outlined,
                  cor: Colors.teal,
                  valores: leituras.map((l) => l.umidadeAr.toDouble()).toList(),
                  minVal: 0,
                  maxVal: 100,
                ),
                const SizedBox(height: 12),
                _GraficoCard(
                  titulo: 'Temperatura (°C)',
                  icone: Icons.thermostat,
                  cor: Colors.orange,
                  valores: leituras.map((l) => l.temperatura).toList(),
                  minVal: -40,
                  maxVal: 80,
                ),
                if (leituras.any((l) => l.vazao > 0)) ...[
                  const SizedBox(height: 12),
                  _GraficoCard(
                    titulo: 'Vazão (L/min)',
                    icone: Icons.water_outlined,
                    cor: Colors.cyan,
                    valores: leituras.map((l) => l.vazao).toList(),
                  ),
                ],
                if (leituras.any((l) => l.litros > 0)) ...[
                  const SizedBox(height: 12),
                  _GraficoCard(
                    titulo: 'Consumo acumulado (L)',
                    icone: Icons.local_drink_outlined,
                    cor: Colors.indigo,
                    valores: leituras.map((l) => l.litros).toList(),
                  ),
                ],
                if (conectado) ...[
                  const SizedBox(height: 12),
                  _HeatmapCard(
                    bt: BluetoothService.instance,
                    irrigacoesHoje: irrigacoesHoje,
                  ),
                ],
              ],
            ),
    );
  }
}

class _ResumoEstatistico extends StatelessWidget {
  const _ResumoEstatistico({required this.leituras});
  final List<Leitura> leituras;

  double _media(Iterable<double> v) =>
      v.isEmpty ? 0 : v.reduce((a, b) => a + b) / v.length;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    final solos = leituras
        .map((l) => l.umidadeSolo.toDouble())
        .where((v) => !v.isNaN && v >= 0 && v <= 100)
        .toList();
    final ares = leituras
        .map((l) => l.umidadeAr.toDouble())
        .where((v) => !v.isNaN && v >= 0 && v <= 100)
        .toList();
    final temps = leituras
        .map((l) => l.temperatura)
        .where((v) => !v.isNaN && v >= -40 && v <= 80)
        .toList();

    Widget item(String rotulo, String valor, Color cor) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(rotulo, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 2),
            Text(valor,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: cores.primary.withValues(alpha: 0.10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Médias das leituras',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: item('Solo',
                        '${_media(solos).toStringAsFixed(0)}%', Colors.blue)),
                const SizedBox(width: 8),
                Expanded(
                    child: item('Ar', '${_media(ares).toStringAsFixed(0)}%',
                        Colors.teal)),
                const SizedBox(width: 8),
                Expanded(
                    child: item('Temp',
                        '${_media(temps).toStringAsFixed(1)}°', Colors.orange)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Cobertura do histórico: '
              '${_fmtCobertura(leituras.first.tempo, leituras.last.tempo)} '
              '(${leituras.length} registros)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

String _fmtCobertura(DateTime inicio, DateTime fim) {
  final d = fim.difference(inicio);
  if (d.inHours >= 24) return '${d.inDays} dias e ${d.inHours % 24} h';
  if (d.inHours > 0) return '${d.inHours} h ${d.inMinutes % 60} min';
  return '${d.inMinutes} min';
}

class _TaxasCard extends StatelessWidget {
  const _TaxasCard({required this.leituras, required this.regasPorDia});
  final List<Leitura> leituras;
  final Map<String, int> regasPorDia;

  String _chaveDia(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;

    // Consumo: maior `litros` de cada dia (o valor zera todo dia) somado e
    // dividido pelo nº de dias cobertos -> L/dia.
    final porDia = <String, double>{};
    for (final l in leituras) {
      final chave = _chaveDia(l.tempo);
      final atual = porDia[chave] ?? 0;
      if (l.litros > atual) porDia[chave] = l.litros;
    }
    final totalLitros = porDia.values.fold<double>(0, (a, b) => a + b);
    final dias = porDia.length;
    final litrosDia = dias == 0 ? 0.0 : totalLitros / dias;

    // Regações: soma as regas registradas nos mesmos dias do histórico,
    // dividida pelo nº de dias -> regas/dia.
    var totalRegas = 0;
    for (final chave in porDia.keys) {
      totalRegas += regasPorDia[chave] ?? 0;
    }
    final regasDia = dias == 0 ? 0.0 : totalRegas / dias;

    Widget item(IconData icone, Color cor, String rotulo, String valor) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icone, color: cor),
              const SizedBox(height: 6),
              Text(rotulo, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 2),
              Text(
                valor,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: cores.primary.withValues(alpha: 0.10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Taxas (por dia)',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                item(Icons.water_drop_outlined, Colors.blueAccent,
                    'Consumo de água', '${litrosDia.toStringAsFixed(2)} L/dia'),
                const SizedBox(width: 8),
                item(Icons.repeat, Colors.green,
                    'Regações', '${regasDia.toStringAsFixed(1)}/dia'),
              ],
            ),
            if (dias > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Baseado em $dias dia(s) com dados, '
                  'total de ${totalLitros.toStringAsFixed(2)} L consumidos '
                  'e $totalRegas rega(s).',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GraficoCard extends StatelessWidget {
  const _GraficoCard({
    required this.titulo,
    required this.icone,
    required this.cor,
    required this.valores,
    this.ideal,
    this.minVal,
    this.maxVal,
  });
  final String titulo;
  final IconData icone;
  final Color cor;
  final List<double> valores;
  final double? ideal;
  final double? minVal;
  final double? maxVal;

  @override
  Widget build(BuildContext context) {
    // Ignora leituras fora da faixa física (ex.: -999/-1 quando o DHT falha)
    // para não distorcer o gráfico nem as médias.
    final limpos = valores
        .where((v) => !v.isNaN && !v.isInfinite)
        .where((v) =>
            (minVal == null || v >= minVal!) && (maxVal == null || v <= maxVal!))
        .toList();
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icone, size: 20, color: cor),
                const SizedBox(width: 8),
                Text(titulo, style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 140,
              child: limpos.isEmpty
                  ? const Center(
                      child: Text('Sem leituras válidas (verifique o sensor)'))
                  : _MiniGrafico(valores: limpos, cor: cor, ideal: ideal),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniGrafico extends StatelessWidget {
  const _MiniGrafico({
    required this.valores,
    required this.cor,
    this.ideal,
  });
  final List<double> valores;
  final Color cor;
  final double? ideal;

  @override
  Widget build(BuildContext context) {
    final visiveis = valores.length > 60
        ? valores.sublist(valores.length - 60)
        : valores;
    final maxV = visiveis.fold<double>(
        visiveis.first, (a, b) => b > a ? b : a);
    final minV = visiveis.fold<double>(
        visiveis.first, (a, b) => b < a ? b : a);
    // Eixo adaptado aos dados (suporta valores negativos, ex.: temperatura)
    var limiteMax = maxV + 10;
    var limiteMin = minV - 10;
    if (limiteMax - limiteMin < 20) {
      limiteMax = maxV + 10;
      limiteMin = minV - 10;
    }
    limiteMax = limiteMax.clamp(-50.0, 150.0);
    limiteMin = limiteMin.clamp(-50.0, 100.0);
    if (limiteMin >= limiteMax) {
      limiteMin = limiteMax - 20;
    }

    final spots = <FlSpot>[];
    for (var i = 0; i < visiveis.length; i++) {
      spots.add(FlSpot(i.toDouble(), visiveis[i]));
    }

    return LineChart(
      LineChartData(
        minY: limiteMin,
        maxY: limiteMax,
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        titlesData: const FlTitlesData(
          leftTitles: AxisTitles(),
          bottomTitles: AxisTitles(),
          topTitles: AxisTitles(),
          rightTitles: AxisTitles(),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: true),
        lineBarsData: [
          if (ideal != null)
            LineChartBarData(
              spots: [
                FlSpot(0, ideal!),
                FlSpot((visiveis.length - 1).toDouble(), ideal!),
              ],
              color: Colors.grey.withValues(alpha: 0.5),
              dotData: const FlDotData(show: false),
              barWidth: 1.5,
              dashArray: [4, 4],
              isCurved: false,
            ),
          LineChartBarData(
            spots: spots,
            color: cor,
            isCurved: true,
            curveSmoothness: 0.35,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: cor.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 400),
    );
  }
}

class _HeatmapCard extends StatelessWidget {
  const _HeatmapCard({required this.bt, required this.irrigacoesHoje});
  final BluetoothService bt;
  final int irrigacoesHoje;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    final regas = bt.regasPorDia;
    final hoje = DateTime.now();
    const totalDias = 70;

    int contar(int offset) {
      final dia = hoje.subtract(Duration(days: offset));
      final chave = '${dia.year}-${dia.month.toString().padLeft(2, '0')}-${dia.day.toString().padLeft(2, '0')}';
      return regas[chave] ?? 0;
    }

    var maxV = 0;
    for (var i = 0; i < totalDias; i++) {
      final c = contar(i);
      if (c > maxV) maxV = c;
    }
    if (maxV == 0) maxV = 1;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.grid_on, size: 20, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Histórico de irrigação (70 dias)',
                      style: Theme.of(context).textTheme.titleSmall),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Hoje: $irrigacoesHoje',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(width: 14),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var col = 0; col < (totalDias ~/ 7); col++)
                          Row(
                            children: [
                              for (var lin = 0; lin < 7; lin++)
                                _CellReza(
                                  intensidade: contar(
                                          ((totalDias ~/ 7) - 1 - col) * 7 +
                                              (6 - lin)) /
                                      maxV,
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('Menos', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(width: 4),
                for (var i = 0; i < 5; i++)
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: _corCell(i / 5, cores),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                const SizedBox(width: 4),
                Text('Mais', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Color _corCell(double intensidade, ColorScheme cores) {
  if (intensidade <= 0) {
    return cores.surfaceContainerHighest;
  }
  const baixo = Color(0xFFBBDEFB);
  const alto = Color(0xFF0D47A1);
  return Color.lerp(baixo, alto, intensidade.clamp(0.0, 1.0))!;
}

class _CellReza extends StatelessWidget {
  const _CellReza({required this.intensidade});
  final double intensidade;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return Container(
      width: 11,
      height: 11,
      margin: const EdgeInsets.symmetric(horizontal: 1.5, vertical: 1.5),
      decoration: BoxDecoration(
        color: _corCell(intensidade, cores),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/leitura.dart';
import '../models/planta.dart';
import '../services/bluetooth_service.dart';

class RelatoriosScreen extends StatelessWidget {
  const RelatoriosScreen({
    super.key,
    required this.planta,
    required this.leituras,
    required this.conectado,
  });

  final Planta planta;
  final List<Leitura> leituras;
  final bool conectado;

  // Compressão de períodos parados nos gráficos do PDF: leitura repetida
  // por mais de 10 min ocupa no máximo 90s no eixo do tempo.
  static const double _flatMinSeg = 600;
  static const double _flatCapSeg = 90;

  Future<void> _gerarPdf(BuildContext context) async {
    if (leituras.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sem dados de telemetria para gerar o relatório.'),
          ),
        );
      }
      return;
    }
    try {
      final doc = pw.Document();
      // Compacta leituras repetidas: enquanto o valor se repete, conta o tempo;
      // quando muda, a leitura anterior recebe quanto tempo durou. Assim a
      // coluna "Durou" mostra o tempo até a próxima mudança mesmo com a
      // telemetria de 200 ms (que grava várias linhas iguais).
      final compactadas = _compactar(leituras);
      final ordenadas = List<Leitura>.from(compactadas)
        ..sort((a, b) => a.tempo.compareTo(b.tempo));
      final primeiro = ordenadas.first.tempo;
      final ultimo = ordenadas.last.tempo;

      double media(List<double> v) =>
          v.isEmpty ? 0 : v.reduce((a, b) => a + b) / v.length;
      double minimo(List<double> v) => v.isEmpty ? 0 : v.reduce((a, b) => a < b ? a : b);
      double maximo(List<double> v) => v.isEmpty ? 0 : v.reduce((a, b) => a > b ? a : b);

      final solos = ordenadas.map((l) => l.umidadeSolo.toDouble()).toList();
      final ares = ordenadas.map((l) => l.umidadeAr.toDouble()).toList();
      final temps = ordenadas.map((l) => l.temperatura).toList();
      final vazoes = ordenadas.map((l) => l.vazao).toList();

      final regasHoje = ordenadas.last.irrigacoesHoje;
      final litrosHoje = ordenadas.last.litros;
      final vazaoMedia = vazoes.where((v) => v > 0).isEmpty
          ? 0.0
          : media(vazoes.where((v) => v > 0).toList());
      final cobertura = ultimo.difference(primeiro);

      String fmt(DateTime d) =>
          '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
          '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

      String fmtDuracao(Duration d) {
        if (d.inHours >= 24) return '${d.inDays} dias e ${d.inHours % 24} h';
        if (d.inHours > 0) return '${d.inHours} h ${d.inMinutes % 60} min';
        return '${d.inMinutes} min';
      }

      // Formato "min e seg" para a coluna Durou: mostra quanto tempo a
      // leitura ficou REPETINDO. Ex.: 185s -> "3min 5s"; 45s -> "45s";
      // leitura que não repetiu (durou menos de 1s) -> "0s".
      String fmtDuracaoSec(int sec) {
        if (sec <= 0) return '0s';
        final h = sec ~/ 3600;
        final m = (sec % 3600) ~/ 60;
        final s = sec % 60;
        final partes = <String>[
          if (h > 0) '${h}h',
          if (m > 0) '${m}min',
          if (s > 0 && h == 0) '${s}s',
        ];
        return partes.isEmpty ? '0s' : partes.join(' ');
      }

      // Duração da repetição da leitura. Usa a duração gravada pelo ESP32
      // (tempo em que o valor ficou igual); na última linha, conta até agora
      // porque a leitura ainda está valendo. Sem repetição -> "0s".
      String duracaoRelatorio(List<Leitura> linhas, int i) {
        final l = linhas[i];
        var seg = l.duracao;
        if (seg <= 0 && i == linhas.length - 1) {
          seg = DateTime.now().difference(l.tempo).inSeconds;
        }
        return fmtDuracaoSec(seg);
      }

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (ctx) => [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Horta EETEPA',
                    style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.green800)),
                pw.Text('PlantAuto PEEX - Relatório',
                    style: pw.TextStyle(
                        fontSize: 14, color: PdfColors.grey700)),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Divider(color: PdfColors.grey400),
            pw.SizedBox(height: 12),
            pw.Text('Planta: ${planta.nome}',
                style: pw.TextStyle(
                    fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text(
                'ESP32: ${planta.esp32Nome ?? planta.esp32Id ?? 'não vinculado'}'),
            pw.Text('Período: ${fmt(primeiro)} até ${fmt(ultimo)}'),
            pw.Text('Gerado em: ${fmt(DateTime.now())}'),
            pw.SizedBox(height: 16),
            pw.Text('Resumo',
                style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green800)),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ['Métrica', 'Média', 'Mín', 'Máx'],
              data: [
                ['Umidade do solo (%)', _f(media(solos)), _f(minimo(solos)), _f(maximo(solos))],
                ['Umidade do ar (%)', _f(media(ares)), _f(minimo(ares)), _f(maximo(ares))],
                ['Temperatura (°C)', _f(media(temps)), _f(minimo(temps)), _f(maximo(temps))],
                ['Vazão (L/min)', _f(vazaoMedia), '-', '-'],
              ],
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.green100),
              headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold, color: PdfColors.green900),
              cellAlignment: pw.Alignment.centerLeft,
              headerAlignment: pw.Alignment.centerLeft,
              border: pw.TableBorder(
                  bottom: pw.BorderSide(color: PdfColors.grey400)),
              cellStyle: const pw.TextStyle(fontSize: 10),
            ),
            pw.SizedBox(height: 12),
            pw.Text('Status atual:',
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, fontSize: 12)),
            pw.SizedBox(height: 4),
            pw.Text(
                '- Irrigações hoje: $regasHoje\n'
                '- Consumo acumulado hoje: ${litrosHoje.toStringAsFixed(2)} L\n'
                '- Histórico cobre: ${fmtDuracao(cobertura)} '
                '(leituras repetidas não são gravadas; a coluna Durou mostra '
                'quanto tempo cada leitura ficou repetindo — 0s se mudou na hora)\n'
                '- Configuração: umidade ideal ${planta.umidadeIdeal}%, '
                'rega quando solo < ${planta.regaInicio}% / para > ${planta.regaFim}%, '
                'irrigação ${planta.fatorNome}, '
                'tempo máx. ${planta.tempoMaxRega == 0 ? 'auto' : '${planta.tempoMaxRega} min'}, '
                'intervalo ${planta.intervaloRega == 0 ? 'sem' : '${planta.intervaloRega} min'}'),
            pw.SizedBox(height: 8),
            _secaoProblemasPdf(),
            pw.SizedBox(height: 16),
            pw.Text('Dados (últimas ${ordenadas.length > 200 ? 200 : ordenadas.length} leituras)',
                style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green800)),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ['Data/Hora', 'Solo %', 'Ar %', 'Temp (°C)', 'Regas', 'Vazão L/min', 'Consumo L', 'Durou'],
              data: [
                for (var i = ordenadas.length > 200
                    ? ordenadas.length - 200
                    : 0;
                    i < ordenadas.length;
                    i++)
                  [
                    fmt(ordenadas[i].tempo),
                    '${ordenadas[i].umidadeSolo}',
                    '${ordenadas[i].umidadeAr}',
                    ordenadas[i].temperatura.toStringAsFixed(1),
                    '${ordenadas[i].irrigacoesHoje}',
                    ordenadas[i].vazao.toStringAsFixed(2),
                    ordenadas[i].litros.toStringAsFixed(2),
                    duracaoRelatorio(ordenadas, i),
                  ],
              ],
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.blueGrey100),
              headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
              cellAlignment: pw.Alignment.centerLeft,
              headerAlignment: pw.Alignment.centerLeft,
              border: pw.TableBorder(
                  bottom: pw.BorderSide(color: PdfColors.blueGrey100)),
              cellStyle: const pw.TextStyle(fontSize: 8),
            ),
            pw.SizedBox(height: 16),
            pw.Text('Gráficos',
                style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green800)),
            pw.SizedBox(height: 8),
            ..._secaoGraficosPdf(ordenadas),
          ],
        ),
      );
      await Printing.layoutPdf(onLayout: (format) => doc.save());
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao gerar relatório: $e')),
        );
      }
    }
  }

  String _f(double v) => v.toStringAsFixed(1);

  // v4.12: seção "Problemas" do PDF (lê o log baixado do ESP32, se houver).
  pw.Widget _secaoProblemasPdf() {
    final disp = _dispositivo();
    final problemas = disp?.problemas ?? const [];
    if (problemas.isEmpty) {
      return pw.Text('Problemas: nenhum problema detectado no dispositivo.',
          style: pw.TextStyle(fontSize: 10));
    }
    String fmt(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Problemas detectados (${problemas.length}):',
            style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 12,
                color: PdfColors.orange900)),
        pw.SizedBox(height: 4),
        for (final p in problemas.reversed)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 2),
            child: pw.Text(
              '- ${p.rotulo}: ${p.mensagem} (${fmt(p.tempo)})',
              style: const pw.TextStyle(fontSize: 10),
            ),
          ),
      ],
    );
  }

  // Une leituras seguidas com os mesmos valores, acumulando em `duracao` o
  // tempo decorrido até a leitura mudar. A última (ainda aberta) fica com
  // duracao 0 — o PDF mostra quanto já está durando.
  List<Leitura> _compactar(List<Leitura> origem) {
    final ordenada = List<Leitura>.from(origem)
      ..sort((a, b) => a.tempo.compareTo(b.tempo));
    final res = <Leitura>[];
    for (final x in ordenada) {
      if (res.isEmpty) {
        res.add(x);
        continue;
      }
      final ult = res.last;
      final mesma = ult.umidadeSolo == x.umidadeSolo &&
          ult.umidadeAr == x.umidadeAr &&
          ult.temperatura == x.temperatura &&
          ult.vazao == x.vazao &&
          ult.litros == x.litros;
      if (mesma) {
        res[res.length - 1] = Leitura(
          tempo: ult.tempo,
          umidadeSolo: ult.umidadeSolo,
          umidadeAr: ult.umidadeAr,
          temperatura: ult.temperatura,
          irrigacoesHoje: ult.irrigacoesHoje,
          vazao: ult.vazao,
          litros: ult.litros,
          duracao: x.tempo.difference(ult.tempo).inSeconds,
        );
      } else {
        res.add(x);
      }
    }
    return res;
  }

  DispositivoConectado? _dispositivo() {
    final esp32Id = planta.esp32Id;
    if (esp32Id == null) return null;
    return BluetoothService.instance.dispositivoPorId(esp32Id);
  }

  Future<void> _pedirHistorico(BuildContext context) async {
    final bt = BluetoothService.instance;
    final esp32Id = planta.esp32Id;
    final disp = esp32Id != null ? bt.dispositivoPorId(esp32Id) : null;
    if (disp == null || !disp.conectado) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ESP32 não conectado. Conecte na aba Conectividade.'),
          ),
        );
      }
      return;
    }
    await bt.pedirHistorico(disp);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Histórico solicitado. Aguarde o download dos dados...'),
        ),
      );
    }
  }

  // v4.12: baixa o log de problemas do ESP32 e mostra numa caixa de diálogo.
  Future<void> _pedirProblemas(BuildContext context) async {
    final bt = BluetoothService.instance;
    final disp = _dispositivo();
    if (disp == null || !disp.conectado) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ESP32 não conectado. Conecte na aba Conectividade.'),
          ),
        );
      }
      return;
    }
    await bt.pedirErros(disp);
    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Problemas do dispositivo'),
        content: SizedBox(
          width: double.maxFinite,
          child: disp.problemas.isEmpty
              ? const Text('Nenhum problema registrado no ESP32. 🌱')
              : ListView(
                  shrinkWrap: true,
                  children: [
                    for (final p in disp.problemas.reversed)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.warning_amber,
                            color: Colors.orange),
                        title: Text(p.rotulo),
                        subtitle: Text(
                          '${p.mensagem}\n${p.tempo.day.toString().padLeft(2, '0')}/${p.tempo.month.toString().padLeft(2, '0')} '
                          '${p.tempo.hour.toString().padLeft(2, '0')}:${p.tempo.minute.toString().padLeft(2, '0')}',
                        ),
                        isThreeLine: true,
                      ),
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              bt.limparErrosFirmware(disp);
              Navigator.pop(context);
            },
            child: const Text('Limpar log'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Relatórios')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
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
                      const Icon(Icons.description_outlined,
                          size: 20, color: Colors.blueGrey),
                      const SizedBox(width: 8),
                      Text('Relatório de telemetria',
                          style: Theme.of(context).textTheme.titleSmall),
                    ],
                  ),
                  const SizedBox(height: 4),
                    Text(
                      leituras.isEmpty
                          ? 'Sem dados ainda. Conecte o ESP32 para coletar telemetria.'
                          : '${leituras.length} leituras armazenadas cobrindo '
                              '${_fmtCobertura(leituras.first.tempo, leituras.last.tempo)}. '
                              'Leituras repetidas são unidas no relatório: a '
                              'coluna Durou mostra quanto tempo a leitura ficou '
                              'repetindo (0s se mudou na hora).',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: leituras.isEmpty ? null : () => _gerarPdf(context),
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    label: const Text('Baixar relatório em PDF'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (leituras.isNotEmpty) ...[
            const SizedBox(height: 12),
            _GraficoGrandeCard(
              titulo: 'Umidade do solo (%)',
              icone: Icons.water_drop_outlined,
              cor: Colors.blue,
              leituras: leituras,
              extrair: (l) => l.umidadeSolo.toDouble(),
              filtroMin: 0,
              filtroMax: 100,
              eixoMin: 0,
              eixoMax: 100,
              unidade: '%',
              referencias: [
                _Ref('Ideal', planta.umidadeIdeal.toDouble(), Colors.green),
                _Ref('Liga', planta.regaInicio.toDouble(), Colors.orange),
                _Ref('Desliga', planta.regaFim.toDouble(), Colors.redAccent),
              ],
            ),
            const SizedBox(height: 12),
            _GraficoGrandeCard(
              titulo: 'Umidade do ar (%)',
              icone: Icons.cloud_outlined,
              cor: Colors.teal,
              leituras: leituras,
              extrair: (l) => l.umidadeAr.toDouble(),
              filtroMin: 0,
              filtroMax: 100,
              eixoMin: 0,
              eixoMax: 100,
              unidade: '%',
            ),
            const SizedBox(height: 12),
            _GraficoGrandeCard(
              titulo: 'Temperatura (°C)',
              icone: Icons.thermostat,
              cor: Colors.orange,
              leituras: leituras,
              extrair: (l) => l.temperatura,
              filtroMin: -40,
              filtroMax: 80,
              casas: 1,
              unidade: '°C',
            ),
            if (leituras.any((l) => l.vazao > 0)) ...[
              const SizedBox(height: 12),
              _GraficoGrandeCard(
                titulo: 'Vazão (L/min)',
                icone: Icons.water_outlined,
                cor: Colors.cyan,
                leituras: leituras,
                extrair: (l) => l.vazao,
                filtroMin: 0,
                casas: 2,
                unidade: ' L/min',
              ),
            ],
            if (leituras.any((l) => l.litros > 0)) ...[
              const SizedBox(height: 12),
              _GraficoGrandeCard(
                titulo: 'Consumo acumulado (L)',
                icone: Icons.local_drink_outlined,
                cor: Colors.indigo,
                leituras: leituras,
                extrair: (l) => l.litros,
                filtroMin: 0,
                casas: 2,
                unidade: ' L',
              ),
            ],
            const SizedBox(height: 12),
            _GraficoGrandeCard(
              titulo: 'Irrigações hoje (acumulado do dia)',
              icone: Icons.repeat,
              cor: Colors.purple,
              leituras: leituras,
              extrair: (l) => l.irrigacoesHoje.toDouble(),
              filtroMin: 0,
              suave: false,
              casas: 0,
            ),
          ],
          const SizedBox(height: 12),
          Card(
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
                      const Icon(Icons.download_outlined,
                          size: 20, color: Colors.green),
                      const SizedBox(width: 8),
                      Text('Sincronizar dados',
                          style: Theme.of(context).textTheme.titleSmall),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    conectado
                        ? 'Baixe o histórico gravado no ESP32 para o celular.'
                        : 'Conecte o ESP32 na aba Conectividade para baixar o histórico.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: () => _pedirHistorico(context),
                    icon: const Icon(Icons.sync, size: 18),
                    label: const Text('Solicitar histórico do ESP32'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: conectado
                          ? cores.secondary
                          : cores.surfaceContainerHighest,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
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
                      const Icon(Icons.warning_amber_outlined,
                          size: 20, color: Colors.orange),
                      const SizedBox(width: 8),
                      Text('Problemas do dispositivo',
                          style: Theme.of(context).textTheme.titleSmall),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _problemasResumo(),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _pedirProblemas(context),
                    icon: const Icon(Icons.warning_amber, size: 18),
                    label: const Text('Ver problemas detectados'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      foregroundColor: Colors.orange,
                      side: const BorderSide(color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _problemasResumo() {
    final disp = _dispositivo();
    final n = disp?.problemas.length ?? 0;
    if (n == 0) {
      return conectado
          ? 'Nenhum problema registrado no ESP32. 🌱'
          : 'Conecte o ESP32 para consultar o log de problemas.';
    }
    return 'O ESP32 registrou $n problema${n > 1 ? 's' : ''}. Toque para ver e '
        'consultar o log gravado no firmware. ⚠️';
  }

  // ---------------- Gráficos do PDF (v1.0.0+19) ----------------

  /// Converte as leituras em pontos (x = epoch em segundos, y = valor),
  /// com média por fatia quando há dados demais (máx. [max] pontos).
  List<pw.PointChartValue> _pontosPdf(
      List<Leitura> vs, double Function(Leitura) f, int max) {
    if (vs.length <= max) {
      return [
        for (final l in vs)
          pw.PointChartValue(
              l.tempo.millisecondsSinceEpoch / 1000.0, f(l)),
      ];
    }
    final passo = vs.length / max;
    final res = <pw.PointChartValue>[];
    for (var i = 0; i < max; i++) {
      final ini = (i * passo).floor();
      final fim = ((i + 1) * passo).floor().clamp(ini + 1, vs.length);
      var soma = 0.0;
      for (var j = ini; j < fim; j++) {
        soma += f(vs[j]);
      }
      final meio = vs[(ini + fim) >> 1];
      res.add(pw.PointChartValue(
          meio.tempo.millisecondsSinceEpoch / 1000.0, soma / (fim - ini)));
    }
    return res;
  }

  /// Gera os valores do eixo Y com passos "bonitos" cobrindo [lo]..[hi].
  /// [divisoes] controla a densidade (mais divisões = mais números no eixo).
  List<double> _ticksY(double lo, double hi, {int divisoes = 3}) {
    if (hi - lo < 1e-9) {
      lo -= 1;
      hi += 1;
    }
    final passo = _passoBonitoEixo((hi - lo) / divisoes);
    final inicio = (lo / passo).floor() * passo;
    final res = <double>[];
    for (var v = inicio; v <= hi + passo * 0.001; v += passo) {
      res.add(v);
    }
    return res;
  }

  /// Série pronta para o gráfico do PDF, com o eixo X já comprimido nos
  /// períodos em que a leitura ficou parada (repetições).
  _SerieGrafico _serieComprimida(List<Leitura> vs,
      double Function(Leitura) f, int maxPontos, bool horas) {
    final pts = _pontosPdf(vs, f, maxPontos);

    // Tolerância para considerar dois valores "iguais" (repetição).
    var lo = pts.first.y;
    var hi = pts.first.y;
    for (final p in pts) {
      if (p.y < lo) lo = p.y;
      if (p.y > hi) hi = p.y;
    }
    final eps = 0.005 * ((hi - lo) == 0 ? 1 : (hi - lo));

    // Eixo X virtual: quando o valor fica parado por mais de 10 minutos,
    // esse tempo é comprimido para no máx. 90s — assim o gráfico mostra
    // só o que importa ("quando ele funcionou") sem apagar os dados.
    final xs = <double>[0];
    for (var i = 1; i < pts.length; i++) {
      final dt = pts[i].x - pts[i - 1].x;
      final parado = (pts[i].y - pts[i - 1].y).abs() <= eps;
      var passo = dt;
      if (parado && dt > _flatMinSeg) {
        passo = _flatCapSeg + (dt % 60);
      }
      xs.add(xs.last + passo);
    }
    final pontos = [
      for (var i = 0; i < pts.length; i++) pw.PointChartValue(xs[i], pts[i].y),
    ];

    // Âncoras do eixo X: 6 pontos reais da série, cada um rotulado com o
    // HORÁRIO VERDADEIRO daquele momento.
    final xTicks = <double>[];
    final rotulos = <String>[];
    const nAncoras = 6;
    for (var k = 0; k < nAncoras; k++) {
      final idx =
          ((pts.length - 1) * k / (nAncoras - 1)).round();
      if (xTicks.isNotEmpty && xs[idx] <= xTicks.last) continue;
      xTicks.add(xs[idx]);
      final t = DateTime.fromMillisecondsSinceEpoch(
          (pts[idx].x * 1000).round());
      rotulos.add(horas
          ? '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}'
          : '${t.day.toString().padLeft(2, '0')}/${t.month.toString().padLeft(2, '0')}');
    }
    return _SerieGrafico(pontos, xTicks, rotulos);
  }

  /// Uma PÁGINA INTEIRA de PDF dedicada a um único gráfico, no tamanho
  /// máximo que cabe na folha A4.
  pw.Widget _paginaGraficoPdf({
    required String titulo,
    required String subtitulo,
    required _SerieGrafico serie,
    required PdfColor cor,
    required bool curva,
    pw.LineDataSet Function(_SerieGrafico s)? extraBuilder,
  }) {
    final ys = serie.pontos.map((p) => p.y).toList();
    final yTicks = _ticksY(ys.reduce(min), ys.reduce(max), divisoes: 6);

    final rotuloPorTick = <double, String>{
      for (var i = 0; i < serie.xTicks.length; i++)
        serie.xTicks[i]: serie.rotulosX[i],
    };
    String fmtX(num v) => rotuloPorTick[v.toDouble()] ?? '';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(titulo,
            style: pw.TextStyle(
                fontSize: 15, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 2),
        pw.Text(subtitulo,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
        pw.SizedBox(height: 8),
        pw.Container(
          height: 680,
          child: pw.Chart(
            left: pw.ChartLegend(
              direction: pw.Axis.vertical,
              textStyle: const pw.TextStyle(fontSize: 8),
              position: pw.Alignment.topCenter,
              padding: const pw.EdgeInsets.only(right: 4),
            ),
            bottom: pw.ChartLegend(
              direction: pw.Axis.horizontal,
              textStyle: const pw.TextStyle(fontSize: 8),
              padding: const pw.EdgeInsets.only(top: 2),
            ),
            grid: pw.CartesianGrid(
              xAxis: pw.FixedAxis<double>(serie.xTicks,
                  format: fmtX, divisions: true, ticks: true),
              yAxis: pw.FixedAxis<double>(yTicks,
                  format: (v) => v.toStringAsFixed(v % 1 == 0 ? 0 : 1),
                  divisions: true,
                  ticks: true,
                  marginStart: 10,
                  marginEnd: 10),
            ),
            datasets: [
              if (extraBuilder != null) extraBuilder(serie),
              pw.LineDataSet(
                data: serie.pontos,
                legend: titulo,
                color: cor,
                lineColor: cor,
                lineWidth: 1.4,
                drawPoints: false,
                drawSurface: true,
                surfaceColor: cor,
                surfaceOpacity: 0.15,
                isCurved: curva,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Seção "Gráficos" do PDF: UM GRÁFICO POR PÁGINA, no tamanho máximo,
  /// para todas as leituras (solo, ar, temperatura, vazão, consumo e
  /// irrigações). Períodos parados são comprimidos e os rótulos mostram o
  /// horário real de cada ponto.
  List<pw.Widget> _secaoGraficosPdf(List<Leitura> ordenadas) {
    final paginas = <pw.Widget>[];

    List<Leitura> filtrar(double Function(Leitura) f,
        {double? fMin, double? fMax}) {
      return ordenadas.where((l) {
        final v = f(l);
        return !v.isNaN &&
            !v.isInfinite &&
            (fMin == null || v >= fMin) &&
            (fMax == null || v <= fMax);
      }).toList();
    }

    void adicionar({
      required String titulo,
      required List<Leitura> serieBruta,
      required double Function(Leitura) f,
      PdfColor cor = PdfColors.blue700,
      bool curva = true,
      pw.LineDataSet Function(_SerieGrafico s)? extraBuilder,
    }) {
      if (serieBruta.length < 2) return;
      final x0 =
          serieBruta.first.tempo.millisecondsSinceEpoch / 1000.0;
      final x1 = serieBruta.last.tempo.millisecondsSinceEpoch / 1000.0;
      final spanHoras = (x1 - x0) / 3600.0;
      final serie = _serieComprimida(serieBruta, f, 400, spanHoras < 24);
      if (serie.pontos.length < 2) return;

      final ys = serie.pontos.map((p) => p.y).toList();
      final minY = ys.reduce(min);
      final maxY = ys.reduce(max);
      final media = ys.fold<double>(0, (a, b) => a + b) / ys.length;
      final casas = maxY - minY < 5 ? 2 : (maxY - minY < 20 ? 1 : 0);
      String n(double v) => v.toStringAsFixed(casas);

      paginas.add(pw.NewPage());
      paginas.add(_paginaGraficoPdf(
        titulo: titulo,
        subtitulo:
            'Mínimo ${n(minY)} • Média ${n(media)} • Máximo ${n(maxY)} • '
            '${ys.length} pontos • períodos parados comprimidos no eixo do tempo',
        serie: serie,
        cor: cor,
        curva: curva,
        extraBuilder: extraBuilder,
      ));
    }

    // Solo: inclui a linha da umidade ideal (verde).
    adicionar(
      titulo:
          'Umidade do solo (%) — linha verde = ideal ${planta.umidadeIdeal}%',
      serieBruta:
          filtrar((l) => l.umidadeSolo.toDouble(), fMin: 0, fMax: 100),
      f: (l) => l.umidadeSolo.toDouble(),
      cor: PdfColors.blue700,
      extraBuilder: (s) => pw.LineDataSet(
        data: [
          pw.PointChartValue(s.pontos.first.x, planta.umidadeIdeal.toDouble()),
          pw.PointChartValue(s.pontos.last.x, planta.umidadeIdeal.toDouble()),
        ],
        legend: 'Ideal',
        color: PdfColors.green600,
        lineColor: PdfColors.green600,
        lineWidth: 0.9,
        drawPoints: false,
      ),
    );
    adicionar(
      titulo: 'Umidade do ar (%)',
      serieBruta:
          filtrar((l) => l.umidadeAr.toDouble(), fMin: 0, fMax: 100),
      f: (l) => l.umidadeAr.toDouble(),
      cor: PdfColors.teal,
    );
    adicionar(
      titulo: 'Temperatura (°C)',
      serieBruta: filtrar((l) => l.temperatura, fMin: -40, fMax: 80),
      f: (l) => l.temperatura,
      cor: PdfColors.orange700,
    );
    adicionar(
      titulo: 'Vazão (L/min)',
      serieBruta: filtrar((l) => l.vazao, fMin: 0),
      f: (l) => l.vazao,
      cor: PdfColors.cyan700,
      curva: false,
    );
    adicionar(
      titulo: 'Consumo acumulado (L)',
      serieBruta: filtrar((l) => l.litros, fMin: 0),
      f: (l) => l.litros,
      cor: PdfColors.indigo,
    );
    adicionar(
      titulo: 'Irrigações hoje (acumulado do dia)',
      serieBruta: filtrar((l) => l.irrigacoesHoje.toDouble(), fMin: 0),
      f: (l) => l.irrigacoesHoje.toDouble(),
      cor: PdfColors.purple,
      curva: false,
    );

    return paginas;
  }
}

String _fmtCobertura(DateTime inicio, DateTime fim) {
  final d = fim.difference(inicio);
  if (d.inHours >= 24) return '${d.inDays} dias e ${d.inHours % 24} h';
  if (d.inHours > 0) return '${d.inHours} h ${d.inMinutes % 60} min';
  return '${d.inMinutes} min';
}

/// Escolhe um passo "bonito" para eixos (1, 2, 2.5, 5, 10...).
double _passoBonitoEixo(double faixa) {
  if (faixa <= 0) return 1;
  final bruto = faixa / 4;
  final mag = pow(10, (log(bruto) / ln10).floor()).toDouble();
  for (final m in const [1.0, 2.0, 2.5, 5.0, 10.0]) {
    if (bruto <= m * mag) return m * mag;
  }
  return 10 * mag;
}

/// Série preparada para os gráficos do PDF: pontos com o eixo X já
/// comprimido nos períodos parados + rótulos de horário real das âncoras.
class _SerieGrafico {
  _SerieGrafico(this.pontos, this.xTicks, this.rotulosX);
  final List<pw.PointChartValue> pontos;
  final List<double> xTicks;
  final List<String> rotulosX;
}

/// Linha de referência desenhada sobre o gráfico (ex.: umidade ideal).
class _Ref {
  const _Ref(this.rotulo, this.valor, this.cor);
  final String rotulo;
  final double valor;
  final Color cor;
}

/// Gráfico GRANDE e detalhado para o relatório: eixos com valores e horários,
/// grade, tooltip ao tocar, linha de referência, preenchimento com gradiente
/// e estatísticas (mín/média/máx/atual). Mostra o histórico inteiro — quando
/// há leituras demais, faz a média de cada fatia de tempo (até 400 pontos).
class _GraficoGrandeCard extends StatelessWidget {
  const _GraficoGrandeCard({
    required this.titulo,
    required this.icone,
    required this.cor,
    required this.leituras,
    required this.extrair,
    this.filtroMin,
    this.filtroMax,
    this.eixoMin,
    this.eixoMax,
    this.casas = 0,
    this.unidade = '',
    this.suave = true,
    this.referencias = const [],
  });

  final String titulo;
  final IconData icone;
  final Color cor;
  final List<Leitura> leituras;
  final double Function(Leitura) extrair;

  /// Faixa física válida do sensor (fora dela = falha de leitura, ignora).
  final double? filtroMin;
  final double? filtroMax;

  /// Limites fixos do eixo Y (ex.: 0..100 para umidade). Nulo = automático.
  final double? eixoMin;
  final double? eixoMax;

  final int casas;
  final String unidade;

  /// true = linha curvada; false = degraus (contadores, ex.: irrigações).
  final bool suave;

  final List<_Ref> referencias;

  static const int _maxPontos = 400;

  String _fmt(double v) => v.toStringAsFixed(casas);

  @override
  Widget build(BuildContext context) {
    final ordenadas = List<Leitura>.from(leituras)
      ..sort((a, b) => a.tempo.compareTo(b.tempo));
    final validas = ordenadas.where((l) {
      final v = extrair(l);
      return !v.isNaN &&
          !v.isInfinite &&
          (filtroMin == null || v >= filtroMin!) &&
          (filtroMax == null || v <= filtroMax!);
    }).toList();

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
                Expanded(
                  child: Text(titulo,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: cor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${validas.length} leituras',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: cor)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 260,
              child: validas.length < 2
                  ? Center(
                      child: Text('Sem leituras válidas suficientes',
                          style: Theme.of(context).textTheme.bodySmall),
                    )
                  : _linha(context, validas),
            ),
            if (referencias.isNotEmpty && validas.length >= 2) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 14,
                runSpacing: 4,
                children: [
                  for (final r in referencias)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 14, height: 3, color: r.cor),
                        const SizedBox(width: 5),
                        Text('${r.rotulo}: ${_fmt(r.valor)}$unidade',
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            if (validas.isNotEmpty) _estatisticas(context, validas),
          ],
        ),
      ),
    );
  }

  Widget _estatisticas(BuildContext context, List<Leitura> vs) {
    final vals = vs.map(extrair).toList();
    final minV = vals.reduce((a, b) => a < b ? a : b);
    final maxV = vals.reduce((a, b) => a > b ? a : b);
    final med =
        vals.fold<double>(0, (a, b) => a + b) / vals.length;
    final atual = vals.last;

    Widget item(String rotulo, String valor) => Expanded(
          child: Column(
            children: [
              Text(rotulo,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Theme.of(context).hintColor)),
              const SizedBox(height: 2),
              Text(valor,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
        );

    return Row(
      children: [
        item('Mínimo', '${_fmt(minV)}$unidade'),
        item('Média', '${_fmt(med)}$unidade'),
        item('Máximo', '${_fmt(maxV)}$unidade'),
        item('Atual', '${_fmt(atual)}$unidade'),
      ],
    );
  }

  /// Converte as leituras em pontos. Com dados demais, divide a linha do
  /// tempo em até [_maxPontos] fatias e usa a média de cada uma.
  List<FlSpot> _spots(List<Leitura> vs) {
    if (vs.length <= _maxPontos) {
      return [
        for (var i = 0; i < vs.length; i++)
          FlSpot(vs[i].tempo.millisecondsSinceEpoch.toDouble(), extrair(vs[i])),
      ];
    }
    final passo = vs.length / _maxPontos;
    final res = <FlSpot>[];
    for (var i = 0; i < _maxPontos; i++) {
      final ini = (i * passo).floor();
      final fim = ((i + 1) * passo).floor().clamp(ini + 1, vs.length);
      var soma = 0.0;
      for (var j = ini; j < fim; j++) {
        soma += extrair(vs[j]);
      }
      final meio = vs[(ini + fim) >> 1];
      res.add(FlSpot(meio.tempo.millisecondsSinceEpoch.toDouble(),
          soma / (fim - ini)));
    }
    return res;
  }

  // Escolhe um passo "bonito" para a grade do eixo Y (1, 2, 2.5, 5, 10...).
  double _passoBonito(double faixa) => _passoBonitoEixo(faixa);

  String _rotuloX(DateTime t, Duration span) {
    if (span.inHours < 24) {
      return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    }
    return '${t.day.toString().padLeft(2, '0')}/${t.month.toString().padLeft(2, '0')}';
  }

  String _rotuloXCompleto(DateTime t) =>
      '${t.day.toString().padLeft(2, '0')}/${t.month.toString().padLeft(2, '0')} '
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Widget _linha(BuildContext context, List<Leitura> vs) {
    final spots = _spots(vs);
    final t0 = vs.first.tempo;
    final t1 = vs.last.tempo;
    final span = t1.difference(t0);
    final minX = t0.millisecondsSinceEpoch.toDouble();
    final maxX = t1.millisecondsSinceEpoch.toDouble();

    // Eixo Y: fixo quando definido; senão, automático com folga de 15%.
    double minY;
    double maxY;
    if (eixoMin != null && eixoMax != null) {
      minY = eixoMin!;
      maxY = eixoMax!;
    } else {
      final vals = spots.map((s) => s.y).toList();
      var lo = vals.reduce((a, b) => a < b ? a : b);
      var hi = vals.reduce((a, b) => a > b ? a : b);
      final margem =
          hi - lo == 0 ? (hi.abs() + 1) * 0.2 : (hi - lo) * 0.15;
      lo -= margem;
      hi += margem;
      if (eixoMin != null) lo = eixoMin!;
      minY = lo;
      maxY = hi;
    }

    // Só desenha linhas de referência que caibam no eixo.
    final refsVisiveis = referencias
        .where((r) => r.valor >= minY && r.valor <= maxY)
        .toList();

    final yStep = _passoBonito(maxY - minY);
    final xInterval = (maxX - minX) / 4;
    final corGrade =
        Theme.of(context).brightness == Brightness.dark
            ? Colors.white24
            : Colors.black12;
    final corEixo =
        Theme.of(context).brightness == Brightness.dark
            ? Colors.white38
            : Colors.black26;

    return LineChart(
      LineChartData(
        minX: minX,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: yStep,
          verticalInterval: xInterval,
          getDrawingHorizontalLine: (v) =>
              FlLine(color: corGrade, strokeWidth: 1),
          getDrawingVerticalLine: (v) =>
              FlLine(color: corGrade.withValues(alpha: 0.5), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 46,
              interval: yStep,
              getTitlesWidget: (v, meta) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(_fmt(v),
                    style: TextStyle(fontSize: 10, color: corEixo)),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              interval: xInterval,
              getTitlesWidget: (v, meta) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                    _rotuloX(
                        DateTime.fromMillisecondsSinceEpoch(v.toInt()),
                        span),
                    style: TextStyle(fontSize: 10, color: corEixo)),
              ),
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            left: BorderSide(color: corEixo),
            bottom: BorderSide(color: corEixo),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => Colors.blueGrey.shade900,
            tooltipRoundedRadius: 8,
            getTooltipItems: (tocados) => [
              for (final s in tocados)
                LineTooltipItem(
                  '${_fmt(s.y)}$unidade\n'
                  '${_rotuloXCompleto(DateTime.fromMillisecondsSinceEpoch(s.x.toInt()))}',
                  const TextStyle(
                      color: Colors.white, fontSize: 11, height: 1.35),
                ),
            ],
          ),
        ),
        lineBarsData: [
          for (final r in refsVisiveis)
            LineChartBarData(
              spots: [
                FlSpot(minX, r.valor),
                FlSpot(maxX, r.valor),
              ],
              color: r.cor.withValues(alpha: 0.8),
              barWidth: 1.3,
              isCurved: false,
              dashArray: const [5, 4],
              dotData: const FlDotData(show: false),
            ),
          LineChartBarData(
            spots: spots,
            color: cor,
            isCurved: suave,
            curveSmoothness: 0.25,
            preventCurveOverShooting: true,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  cor.withValues(alpha: 0.25),
                  cor.withValues(alpha: 0.02),
                ],
              ),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 300),
    );
  }
}

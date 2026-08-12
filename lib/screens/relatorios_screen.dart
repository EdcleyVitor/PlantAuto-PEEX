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

      String fmtDuracaoSec(int sec) => fmtDuracao(Duration(seconds: sec));

      // Duração que o valor durou. Prefere a duração gravada pelo ESP32;
      // se não veio, calcula até a próxima leitura (ou até agora, na última).
      String duracaoRelatorio(List<Leitura> linhas, int i) {
        final l = linhas[i];
        if (l.duracao > 0) return fmtDuracaoSec(l.duracao);
        if (i < linhas.length - 1) {
          return fmtDuracao(linhas[i + 1].tempo.difference(l.tempo));
        }
        final ateAgora = DateTime.now().difference(l.tempo);
        return ateAgora.inSeconds > 0 ? fmtDuracao(ateAgora) : '-';
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
                '(leituras repetidas não são gravadas; cada linha mostra '
                'quanto tempo o valor durou)\n'
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
                            'Leituras repetidas são unidas no relatório: cada '
                            'registro mostra quanto tempo o valor durou até a '
                            'próxima mudança.',
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
}

String _fmtCobertura(DateTime inicio, DateTime fim) {
  final d = fim.difference(inicio);
  if (d.inHours >= 24) return '${d.inDays} dias e ${d.inHours % 24} h';
  if (d.inHours > 0) return '${d.inHours} h ${d.inMinutes % 60} min';
  return '${d.inMinutes} min';
}

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/planta.dart';
import '../services/bluetooth_service.dart';
import '../services/plantacao_store.dart';

class ConfiguracaoPlantaScreen extends StatefulWidget {
  const ConfiguracaoPlantaScreen({super.key, required this.planta});

  final Planta planta;

  @override
  State<ConfiguracaoPlantaScreen> createState() =>
      _ConfiguracaoPlantaScreenState();
}

class _ConfiguracaoPlantaScreenState extends State<ConfiguracaoPlantaScreen> {
  static const _fatores = [
    (rotulo: 'Mínima', valor: 0.5),
    (rotulo: 'Média', valor: 1.0),
    (rotulo: 'Frequente', valor: 1.5),
  ];

  late TextEditingController _nomeController;
  late int _umidadeIdeal;
  late double _fatorPlanta;
  late int _margem;
  late int _regaInicio;
  late int _regaFim;
  late int _tempoMaxRega;
  late int _intervaloRega;
  late int _limiteAR;
  late int _umidoAlvo;
  late bool _mlAtivo;
  late bool _releAtivoAlto;
  String? _imagem;
  Timer? _debounceEnvio;

  DispositivoConectado? get _disp {
    final id = widget.planta.esp32Id;
    if (id == null) return null;
    return BluetoothService.instance.dispositivoPorId(id);
  }

  @override
  void initState() {
    super.initState();
    final p = widget.planta;
    _nomeController = TextEditingController(text: p.nome);
    _umidadeIdeal = p.umidadeIdeal;
    _fatorPlanta = p.fatorPlanta;
    _margem = p.margem;
    _regaInicio = p.regaInicio;
    _regaFim = p.regaFim;
    _tempoMaxRega = p.tempoMaxRega;
    _intervaloRega = p.intervaloRega;
    _limiteAR = p.limiteAR;
    _umidoAlvo = p.umidoAlvo;
    _mlAtivo = p.mlAtivo;
    _releAtivoAlto = p.releAtivoAlto;
    _imagem = p.imagemPerfil;
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _debounceEnvio?.cancel();
    super.dispose();
  }

  Future<void> _persistir() async {
    await PlantacaoStore.instance.atualizarConfig(
      widget.planta.id,
      _umidadeIdeal,
      _fatorPlanta,
      _margem,
      regaInicio: _regaInicio,
      regaFim: _regaFim,
      tempoMaxRega: _tempoMaxRega,
      intervaloRega: _intervaloRega,
      limiteAR: _limiteAR,
      umidoAlvo: _umidoAlvo,
      mlAtivo: _mlAtivo,
      releAtivoAlto: _releAtivoAlto,
    );
  }

  void _agendarEnvio() {
    _debounceEnvio?.cancel();
    _debounceEnvio = Timer(const Duration(milliseconds: 600), () {
      final d = _disp;
      if (d == null || !d.conectado) return;
      final bt = BluetoothService.instance;
      bt.enviarConfig(
        d,
        _nomeController.text.trim().isEmpty
            ? widget.planta.nome
            : _nomeController.text.trim(),
        _umidadeIdeal,
        _fatorPlanta,
        _margem,
        regaInicio: _regaInicio,
        regaFim: _regaFim,
        tempoMaxRega: _tempoMaxRega,
        intervaloRega: _intervaloRega,
        limiteAR: _limiteAR,
        umidoAlvo: _umidoAlvo,
      );
      bt.enviarML(d, _mlAtivo);
      bt.enviarReleAtivo(d, _releAtivoAlto);
    });
  }

  Future<void> _salvarAlteracao() async {
    await _persistir();
    _agendarEnvio();
  }

  Future<void> _trocarFoto() async {
    try {
      final arquivo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 900,
        imageQuality: 82,
      );
      if (arquivo == null) return;
      final bytes = await arquivo.readAsBytes();
      final imagem = await _reduzirImagem(bytes);
      if (!mounted) return;
      setState(() => _imagem = imagem);
      await PlantacaoStore.instance.atualizarImagem(
        widget.planta.id,
        imagem,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível carregar a imagem.'),
        ),
      );
    }
  }

  Future<String> _reduzirImagem(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 600);
    final frame = await codec.getNextFrame();
    final byteData =
        await frame.image.toByteData(format: ui.ImageByteFormat.png);
    return base64Encode(byteData!.buffer.asUint8List());
  }

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações da planta')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: InkWell(
              onTap: _trocarFoto,
              borderRadius: BorderRadius.circular(64),
              child: Stack(
                children: [
                  _imagem == null || _imagem!.isEmpty
                      ? CircleAvatar(
                          radius: 48,
                          backgroundColor: cores.primary.withValues(alpha: 0.15),
                          child: Icon(Icons.grass,
                              size: 44, color: cores.primary),
                        )
                      : CircleAvatar(
                          radius: 48,
                          backgroundImage:
                              MemoryImage(base64Decode(_imagem!)),
                        ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: cores.primary,
                      child: Icon(Icons.photo_camera,
                          size: 18, color: cores.onPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Toque na foto para trocar a imagem da planta.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nomeController,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Nome da horta / planta',
              hintText: 'Ex: Hortelã',
              prefixIcon: const Icon(Icons.grass),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (_) => _salvarAlteracao(),
          ),
          const SizedBox(height: 16),
          _CardSecao(
            titulo: 'Rega',
            icone: Icons.water_drop_outlined,
            cor: Colors.blue,
            children: [
              _SliderLinha(
                rotulo: 'Ligar quando umidade <',
                valor: '$_regaInicio%',
                min: 5,
                max: 95,
                valorAtual: _regaInicio.toDouble(),
                onChanged: (v) => setState(() => _regaInicio = v.round()),
                onChangedEnd: (_) => _salvarAlteracao(),
              ),
              _SliderLinha(
                rotulo: 'Desligar quando umidade >',
                valor: '$_regaFim%',
                min: 10,
                max: 100,
                valorAtual: _regaFim.toDouble(),
                onChanged: (v) => setState(() => _regaFim = v.round()),
                onChangedEnd: (_) => _salvarAlteracao(),
              ),
              _SliderLinha(
                rotulo: 'Umidade ideal',
                valor: '$_umidadeIdeal%',
                min: 0,
                max: 100,
                valorAtual: _umidadeIdeal.toDouble(),
                onChanged: (v) => setState(() => _umidadeIdeal = v.round()),
                onChangedEnd: (_) => _salvarAlteracao(),
              ),
              _SliderLinha(
                rotulo: 'Margem de rega',
                valor: '±$_margem%',
                min: 5,
                max: 95,
                valorAtual: _margem.toDouble(),
                onChanged: (v) => setState(() => _margem = v.round()),
                onChangedEnd: (_) => _salvarAlteracao(),
              ),
              _SliderLinha(
                rotulo: 'Tempo máximo de rega',
                valor: _tempoMaxRega == 0
                    ? 'Auto'
                    : '$_tempoMaxRega min',
                min: 0,
                max: 60,
                valorAtual: _tempoMaxRega.toDouble(),
                onChanged: (v) => setState(() => _tempoMaxRega = v.round()),
                onChangedEnd: (_) => _salvarAlteracao(),
              ),
              _SliderLinha(
                rotulo: 'Intervalo entre regas',
                valor: _intervaloRega == 0
                    ? 'Sem'
                    : '$_intervaloRega min',
                min: 0,
                max: 120,
                valorAtual: _intervaloRega.toDouble(),
                onChanged: (v) => setState(() => _intervaloRega = v.round()),
                onChangedEnd: (_) => _salvarAlteracao(),
              ),
              const SizedBox(height: 8),
              Text('Nível de irrigação',
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 4),
              Row(
                children: [
                  for (final fator in _fatores) ...[
                    Expanded(
                      child: ChoiceChip(
                        label: Text(fator.rotulo),
                        selected: _fatorPlanta == fator.valor,
                        onSelected: (_) {
                          setState(() => _fatorPlanta = fator.valor);
                          _salvarAlteracao();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Relé aciona com HIGH'),
                value: _releAtivoAlto,
                onChanged: (v) {
                  setState(() => _releAtivoAlto = v);
                  _salvarAlteracao();
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Rega inteligente (IA)'),
                value: _mlAtivo,
                onChanged: (v) {
                  setState(() => _mlAtivo = v);
                  _salvarAlteracao();
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          _CardSecao(
            titulo: 'Calibração',
            icone: Icons.adjust,
            cor: Colors.green,
            children: [
              _SliderLinha(
                rotulo: 'Solo seco (ADC)',
                valor: '$_limiteAR',
                min: 0,
                max: 4095,
                divisions: 4095,
                valorAtual: _limiteAR.toDouble(),
                onChanged: (v) => setState(() => _limiteAR = v.round()),
                onChangedEnd: (_) => _salvarAlteracao(),
              ),
              _SliderLinha(
                rotulo: 'Solo úmido (ADC)',
                valor: '$_umidoAlvo',
                min: 0,
                max: 4095,
                divisions: 4095,
                valorAtual: _umidoAlvo.toDouble(),
                onChanged: (v) => setState(() => _umidoAlvo = v.round()),
                onChangedEnd: (_) => _salvarAlteracao(),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _CardSecao extends StatelessWidget {
  const _CardSecao({
    required this.titulo,
    required this.icone,
    required this.cor,
    required this.children,
  });
  final String titulo;
  final IconData icone;
  final Color cor;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
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
            ...children,
          ],
        ),
      ),
    );
  }
}

class _SliderLinha extends StatelessWidget {
  const _SliderLinha({
    required this.rotulo,
    required this.valor,
    required this.min,
    required this.max,
    required this.valorAtual,
    required this.onChanged,
    required this.onChangedEnd,
    this.divisions,
  });
  final String rotulo;
  final String valor;
  final double min;
  final double max;
  final double valorAtual;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangedEnd;
  final int? divisions;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    final divisoes = divisions ??
        (max.round() - min.round()).clamp(1, 120);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(rotulo, style: Theme.of(context).textTheme.bodyMedium),
        Row(
          children: [
            Expanded(
              child: Slider(
                min: min,
                max: max,
                divisions: divisoes,
                value: valorAtual.clamp(min, max),
                label: valor,
                onChanged: onChanged,
                onChangeEnd: onChangedEnd,
              ),
            ),
            CircleAvatar(
              backgroundColor: cores.primary.withValues(alpha: 0.15),
              child: Text(
                valor,
                style: TextStyle(
                  color: cores.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

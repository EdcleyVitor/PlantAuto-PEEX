import 'package:flutter/material.dart';
import '../models/planta.dart';
import '../services/bluetooth_service.dart';
import '../services/plantacao_store.dart';

class SensibilidadeScreen extends StatefulWidget {
  const SensibilidadeScreen({super.key, required this.planta});

  final Planta planta;

  @override
  State<SensibilidadeScreen> createState() => _SensibilidadeScreenState();
}

class _SensibilidadeScreenState extends State<SensibilidadeScreen> {
  static const _fatores = [
    (rotulo: 'Mínima', valor: 0.5),
    (rotulo: 'Média', valor: 1.0),
    (rotulo: 'Frequente', valor: 1.5),
  ];

  // Tipos de amostra da calibração com a umidade de referência de cada um.
  static const _tipos = [
    (chave: 'ar', rotulo: 'Ar', pct: 0, icone: Icons.air),
    (
      chave: 'seco',
      rotulo: 'Solo seco',
      pct: 25,
      icone: Icons.landscape_outlined
    ),
    (
      chave: 'umido',
      rotulo: 'Solo úmido',
      pct: 75,
      icone: Icons.water_drop_outlined
    ),
    (chave: 'agua', rotulo: 'Água', pct: 100, icone: Icons.water),
    (chave: 'metal', rotulo: 'Em metal', pct: 100, icone: Icons.hardware),
  ];

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
  late bool _mlRainAtivo;
  late bool _modoSensivel;
  late int _sensNivel;
  late bool _releAtivoAlto;
  late bool _regaTravada;
  late bool _leitAuto;
  late int _intervaloSolo;
  late int _intervaloArTemp;
  late int _intervaloVazao;
  late bool _calibracaoInvertida;

  final Map<String, int> _amostras = {};
  bool _capturando = false;

  bool get _conectado {
    final disp = _dispositivo();
    return disp != null && disp.conectado;
  }

  DispositivoConectado? _dispositivo() {
    final esp32Id = widget.planta.esp32Id;
    if (esp32Id == null) return null;
    return BluetoothService.instance.dispositivoPorId(esp32Id);
  }

  @override
  void initState() {
    super.initState();
    Planta? atual;
    for (final x in PlantacaoStore.instance.plantas) {
      if (x.id == widget.planta.id) {
        atual = x;
        break;
      }
    }
    final p = atual ?? widget.planta;
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
    _mlRainAtivo = p.mlRainAtivo;
    _modoSensivel = p.modoSensivel;
    _sensNivel = p.sensNivel;
    _releAtivoAlto = p.releAtivoAlto;
    _regaTravada = p.regaTravada;
    _leitAuto = p.leitAuto;
    _intervaloSolo = p.intervaloSolo;
    _intervaloArTemp = p.intervaloArTemp;
    _intervaloVazao = p.intervaloVazao;
    _calibracaoInvertida = p.calibracaoInvertida;
    _amostras.addAll(p.amostras);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final disp = _dispositivo();
      if (disp != null && disp.conectado) {
        BluetoothService.instance.pedirAdc(disp);
        BluetoothService.instance.pedirFluxo(disp);
      }
    });
  }

  Future<void> _enviarTudo(BluetoothService bt, DispositivoConectado disp) {
    return bt
        .enviarConfig(
          disp,
          widget.planta.nome,
          _umidadeIdeal,
          _fatorPlanta,
          _margem,
          regaInicio: _regaInicio,
          regaFim: _regaFim,
          tempoMaxRega: _tempoMaxRega,
          intervaloRega: _intervaloRega,
          limiteAR: _limiteAR,
          umidoAlvo: _umidoAlvo,
        )
        .then((_) => bt.enviarML(disp, _mlAtivo))
        .then((_) => bt.enviarMLRain(disp, _mlRainAtivo))
        .then((_) => bt.enviarModoSensivel(disp, _modoSensivel))
        .then((_) => bt.enviarSensNivel(disp, _sensNivel))
        .then((_) => bt.enviarReleAtivo(disp, _releAtivoAlto))
        .then((_) => bt.enviarLeitura(
              disp,
              auto: _leitAuto,
              solo: _intervaloSolo,
              arTemp: _intervaloArTemp,
              vazao: _intervaloVazao,
            ));
  }

  Future<void> _salvar({bool enviar = true}) async {
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
      mlRainAtivo: _mlRainAtivo,
      modoSensivel: _modoSensivel,
      sensNivel: _sensNivel,
      releAtivoAlto: _releAtivoAlto,
      regaTravada: _regaTravada,
      leitAuto: _leitAuto,
      intervaloSolo: _intervaloSolo,
      intervaloArTemp: _intervaloArTemp,
      intervaloVazao: _intervaloVazao,
      calibracaoInvertida: _calibracaoInvertida,
      amostras: _amostras,
    );
    if (!enviar || !_conectado) return;
    final bt = BluetoothService.instance;
    final disp = _dispositivo();
    if (disp != null && disp.conectado) {
      await _enviarTudo(bt, disp);
      await bt.travarRega(disp, _regaTravada);
    }
  }

  void _onChanged() {
    PlantacaoStore.instance.atualizarConfig(
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
      mlRainAtivo: _mlRainAtivo,
      modoSensivel: _modoSensivel,
      sensNivel: _sensNivel,
      releAtivoAlto: _releAtivoAlto,
      regaTravada: _regaTravada,
      leitAuto: _leitAuto,
      intervaloSolo: _intervaloSolo,
      intervaloArTemp: _intervaloArTemp,
      intervaloVazao: _intervaloVazao,
      calibracaoInvertida: _calibracaoInvertida,
      amostras: _amostras,
    );
    final bt = BluetoothService.instance;
    final disp = _dispositivo();
    if (disp != null && disp.conectado) {
      _enviarTudo(bt, disp);
      bt.travarRega(disp, _regaTravada);
    }
  }

  // ---------------- Calibração pelo toque (5 amostras) ----------------

  Future<void> _capturar(String chave) async {
    final disp = _dispositivo();
    if (disp == null || !disp.conectado) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Conecte o ESP32 na aba Conectividade primeiro.'),
        ),
      );
      return;
    }
    setState(() => _capturando = true);
    final v = await _capturarMediana(disp);
    if (!mounted) return;
    setState(() {
      _capturando = false;
      if (v >= 0) {
        _amostras[chave] = v;
        _recalcularCalibracao();
      }
    });
    if (v >= 0) {
      final tipo = _tipos.firstWhere((t) => t.chave == chave);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${tipo.rotulo}: ADC $v capturado.')),
      );
    }
  }

  Future<int> _capturarMediana(DispositivoConectado disp) async {
    final valores = <int>[];
    for (var i = 0; i < 5; i++) {
      final v = await BluetoothService.instance.capturarAdc(disp);
      if (v < 0) return -1;
      valores.add(v);
      await Future.delayed(const Duration(milliseconds: 200));
    }
    valores.sort();
    return valores[valores.length ~/ 2];
  }

  // Usa TODAS as amostras capturadas (nenhuma é obrigatória) para montar a
  // calibração. Com 2+ amostras faz uma regressão linear (ADC x umidade) que
  // detecta a orientação do sensor sozinha; com 1 amostra ancora o extremo
  // tocado e usa o ADC AO VIVO como o outro extremo. Se o sensor quase não
  // varia entre as amostras, usa a leitura ao vivo para criar uma faixa —
  // aceitando qualquer tipo de sensor.
  void _recalcularCalibracao() {
    final pontos = <(double pct, int adc)>[];
    for (final tipo in _tipos) {
      final v = _amostras[tipo.chave];
      if (v != null) pontos.add((tipo.pct.toDouble(), v));
    }
    if (pontos.isEmpty) return;

    final adcs = pontos.map((p) => p.$2).toList();
    final minAdc = adcs.reduce((a, b) => a < b ? a : b);
    final maxAdc = adcs.reduce((a, b) => a > b ? a : b);
    final temVariacao = maxAdc - minAdc >= 50;
    final disp = _dispositivo();
    final vivo = (disp != null && disp.ultimoAdc >= 0) ? disp.ultimoAdc : null;

    if (temVariacao && pontos.length >= 2) {
      double sx = 0, sy = 0, sxy = 0, sxx = 0;
      for (final p in pontos) {
        sx += p.$1;
        sy += p.$2;
        sxy += p.$1 * p.$2;
        sxx += p.$1 * p.$1;
      }
      final denom = pontos.length * sxx - sx * sx;
      if (denom.abs() > 1e-6) {
        final m = (pontos.length * sxy - sx * sy) / denom;
        final b = (sy - m * sx) / pontos.length;
        _limiteAR = b.round().clamp(0, 4095);
        _umidoAlvo = (m * 100 + b).round().clamp(0, 4095);
        _aplicarOrdem();
      } else {
        _aplicarExtremos();
      }
    } else if (vivo != null && (vivo - minAdc).abs() >= 50) {
      // Sem variação entre amostras, mas o ADC ao vivo é diferente: monta uma
      // faixa usando a amostra de um lado e o vivo como o outro extremo.
      final secoSide = pontos.where((p) => p.$1 <= 25).toList();
      final umidoSide = pontos.where((p) => p.$1 >= 75).toList();
      if (secoSide.isNotEmpty && umidoSide.isEmpty) {
        _limiteAR = secoSide.first.$2.clamp(0, 4095);
        _umidoAlvo = vivo.clamp(0, 4095);
        _aplicarOrdem();
      } else if (umidoSide.isNotEmpty && secoSide.isEmpty) {
        _umidoAlvo = umidoSide.first.$2.clamp(0, 4095);
        _limiteAR = vivo.clamp(0, 4095);
        _aplicarOrdem();
      } else {
        _aplicarExtremos();
      }
    } else {
      _aplicarExtremos();
    }
    _salvar();
  }

  // Ordena "seco" e "úmido" conforme a chave Inverter:
  //  - desligada: seco = ADC ALTO, úmido = ADC baixo (sensores comuns)
  //  - ligada:    seco = ADC BAIXO, úmido = ADC alto (valor alto = rega)
  void _aplicarOrdem() {
    if (_calibracaoInvertida) {
      if (_limiteAR > _umidoAlvo) {
        final t = _limiteAR;
        _limiteAR = _umidoAlvo;
        _umidoAlvo = t;
      }
    } else {
      if (_limiteAR < _umidoAlvo) {
        final t = _limiteAR;
        _limiteAR = _umidoAlvo;
        _umidoAlvo = t;
      }
    }
  }

  void _aplicarExtremos() {
    for (final tipo in _tipos) {
      final v = _amostras[tipo.chave];
      if (v == null) continue;
      if (tipo.pct <= 25) {
        _limiteAR = v.clamp(0, 4095);
      } else {
        _umidoAlvo = v.clamp(0, 4095);
      }
    }
    _aplicarOrdem();
  }

  // ---------------- Build ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _PainelSensoresBrutos(planta: widget.planta),
          const SizedBox(height: 12),
          _CardSecao(
            titulo: 'Segurança',
            icone: Icons.lock_outline,
            cor: Colors.red,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Travar regação'),
                subtitle: const Text(
                  'Enquanto ligado, o ESP32 não liga a rega (nem manual, '
                  'nem automática). Segurança extra para o dia a dia.',
                ),
                value: _regaTravada,
                activeColor: Colors.red,
                onChanged: (v) {
                  setState(() => _regaTravada = v);
                  _salvar();
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          _CardSecao(
            titulo: 'Calibração por toque',
            icone: Icons.adjust,
            cor: Colors.green,
            children: [
              _gradeAmostras(),
              const SizedBox(height: 8),
              _linhaResultadoCalibracao(),
              const SizedBox(height: 8),
              _SliderLinha(
                rotulo: 'Solo seco (ADC)',
                valor: '$_limiteAR',
                min: 0,
                max: 4095,
                divisions: 4095,
                valorAtual: _limiteAR.toDouble(),
                onChanged: (v) => setState(() => _limiteAR = v.round()),
                onChangedEnd: (_) => _onChanged(),
              ),
              _SliderLinha(
                rotulo: 'Solo úmido (ADC)',
                valor: '$_umidoAlvo',
                min: 0,
                max: 4095,
                divisions: 4095,
                valorAtual: _umidoAlvo.toDouble(),
                onChanged: (v) => setState(() => _umidoAlvo = v.round()),
                onChangedEnd: (_) => _onChanged(),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Inverter sensor'),
                subtitle: const Text(
                  'Desligada: ADC ALTO = seco (não rega). '
                  'Ligada: ADC ALTO = úmido (rega).',
                ),
                value: _calibracaoInvertida,
                activeColor: Colors.green,
                onChanged: (v) {
                  setState(() {
                    _calibracaoInvertida = v;
                    if (_amostras.isNotEmpty) {
                      _recalcularCalibracao();
                    } else {
                      _aplicarOrdem();
                    }
                  });
                  _salvar();
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          _CardSecao(
            titulo: 'Leitura por tempo',
            icone: Icons.timer_outlined,
            cor: Colors.orange,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Automático'),
                subtitle: const Text(
                  'Usa o intervalo ideal de cada sensor. '
                  'Ao ligar, os ajustes manuais ficam bloqueados.',
                ),
                value: _leitAuto,
                activeColor: Colors.orange,
                onChanged: (v) {
                  setState(() => _leitAuto = v);
                  _onChanged();
                },
              ),
              const Divider(height: 16),
              _SliderLinha(
                rotulo: 'Solo',
                valor: '$_intervaloSolo ms',
                min: 50,
                max: 3000,
                divisions: 295,
                valorAtual: _intervaloSolo.toDouble(),
                habilitado: !_leitAuto,
                onChanged: (v) => setState(() => _intervaloSolo = v.round()),
                onChangedEnd: (_) => _onChanged(),
              ),
              _SliderLinha(
                rotulo: 'Ar e temperatura',
                valor: '$_intervaloArTemp ms',
                min: 50,
                max: 3000,
                divisions: 295,
                valorAtual: _intervaloArTemp.toDouble(),
                habilitado: !_leitAuto,
                onChanged: (v) => setState(() => _intervaloArTemp = v.round()),
                onChangedEnd: (_) => _onChanged(),
              ),
              _SliderLinha(
                rotulo: 'Vazão',
                valor: '$_intervaloVazao ms',
                min: 50,
                max: 3000,
                divisions: 295,
                valorAtual: _intervaloVazao.toDouble(),
                habilitado: !_leitAuto,
                onChanged: (v) => setState(() => _intervaloVazao = v.round()),
                onChangedEnd: (_) => _onChanged(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _CardSecao(
            titulo: 'Sensor sensível',
            icone: Icons.speed,
            cor: Colors.teal,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Modo sensor sensível'),
                subtitle: const Text(
                  'Para sensores de umidade MUITO sensíveis (leitura '
                  'tremida/saturada). Desligado: funciona como está.',
                ),
                value: _modoSensivel,
                activeColor: Colors.teal,
                onChanged: (v) {
                  setState(() => _modoSensivel = v);
                  _onChanged();
                },
              ),
              if (_modoSensivel) ...[
                const Divider(height: 16),
                _SliderLinha(
                  rotulo: 'Sensibilidade',
                  valor: '$_sensNivel',
                  min: 1,
                  max: 100,
                  valorAtual: _sensNivel.toDouble(),
                  onChanged: (v) => setState(() => _sensNivel = v.round()),
                  onChangedEnd: (_) => _onChanged(),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '50 = igual ao normal · menor = leitura mais estável '
                    '· maior = reage mais forte.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          _CardSecao(
            titulo: 'Rega automática',
            icone: Icons.water_drop_outlined,
            cor: Colors.blue,
            children: [
              _SliderLinha(
                rotulo: 'Regar quando umidade <',
                valor: '$_regaInicio%',
                min: 5,
                max: 95,
                valorAtual: _regaInicio.toDouble(),
                onChanged: (v) => setState(() => _regaInicio = v.round()),
                onChangedEnd: (_) => _onChanged(),
              ),
              _SliderLinha(
                rotulo: 'Desligar quando umidade >',
                valor: '$_regaFim%',
                min: 10,
                max: 100,
                valorAtual: _regaFim.toDouble(),
                onChanged: (v) => setState(() => _regaFim = v.round()),
                onChangedEnd: (_) => _onChanged(),
              ),
              _SliderLinha(
                rotulo: 'Umidade ideal',
                valor: '$_umidadeIdeal%',
                min: 0,
                max: 100,
                valorAtual: _umidadeIdeal.toDouble(),
                onChanged: (v) => setState(() => _umidadeIdeal = v.round()),
                onChangedEnd: (_) => _onChanged(),
              ),
              _SliderLinha(
                rotulo: 'Margem de rega',
                valor: '±$_margem%',
                min: 5,
                max: 95,
                valorAtual: _margem.toDouble(),
                onChanged: (v) => setState(() => _margem = v.round()),
                onChangedEnd: (_) => _onChanged(),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Relé aciona com HIGH'),
                value: _releAtivoAlto,
                onChanged: (v) {
                  setState(() => _releAtivoAlto = v);
                  _onChanged();
                },
              ),
              _SliderLinha(
                rotulo: 'Tempo máximo de rega',
                valor: _tempoMaxRega == 0 ? 'Auto' : '$_tempoMaxRega min',
                min: 0,
                max: 60,
                valorAtual: _tempoMaxRega.toDouble(),
                onChanged: (v) => setState(() => _tempoMaxRega = v.round()),
                onChangedEnd: (_) => _onChanged(),
              ),
              _SliderLinha(
                rotulo: 'Intervalo entre regas',
                valor: _intervaloRega == 0 ? 'Sem' : '$_intervaloRega min',
                min: 0,
                max: 120,
                valorAtual: _intervaloRega.toDouble(),
                onChanged: (v) => setState(() => _intervaloRega = v.round()),
                onChangedEnd: (_) => _onChanged(),
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
                          _onChanged();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          _CardSecao(
            titulo: 'Inteligência',
            icone: Icons.psychology_outlined,
            cor: Colors.deepPurple,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Rega inteligente (IA)'),
                value: _mlAtivo,
                onChanged: (v) {
                  setState(() => _mlAtivo = v);
                  _onChanged();
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Verificar clima (chuva)'),
                subtitle: const Text(
                  'Se o ar está úmido e a temperatura baixa, o ESP32 espera '
                  '30 min (15 min à noite) para ver se chove antes de regar.',
                ),
                value: _mlRainAtivo,
                onChanged: (v) {
                  setState(() => _mlRainAtivo = v);
                  _onChanged();
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _gradeAmostras() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.35,
      children: [
        for (final tipo in _tipos)
          _BotaoAmostra(
            rotulo: tipo.rotulo,
            icone: tipo.icone,
            capturado: _amostras[tipo.chave],
            desabilitado: _capturando,
            onTap: () => _capturar(tipo.chave),
          ),
      ],
    );
  }

  Widget _linhaResultadoCalibracao() {
    final cores = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cores.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_fix_high, size: 18, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _amostras.isEmpty
                  ? 'Seco $_limiteAR  ·  Úmido $_umidoAlvo'
                  : 'Seco $_limiteAR  ·  Úmido $_umidoAlvo  (${_amostras.length} amostra${_amostras.length > 1 ? 's' : ''})',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- Build ----------------
}

class _PainelSensoresBrutos extends StatelessWidget {
  const _PainelSensoresBrutos({required this.planta});
  final Planta planta;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: BluetoothService.instance,
      builder: (context, _) {
        final disp = planta.esp32Id != null
            ? BluetoothService.instance.dispositivoPorId(planta.esp32Id!)
            : null;
        final conectado = disp != null && disp.conectado;
        final leitura = disp != null && disp.leituras.isNotEmpty
            ? disp.leituras.last
            : null;
        return _CardSecao(
          titulo: 'Sensores em bruto',
          icone: Icons.sensors,
          cor: Colors.teal,
          children: [
            if (!conectado)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'Conecte o ESP32 para ver as leituras.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              )
            else
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.5,
                children: [
                  _TileBruto(
                    icone: Icons.memory,
                    cor: Colors.blue,
                    rotulo: 'Solo ADC',
                    valor: disp.ultimoAdc < 0 ? '—' : '${disp.ultimoAdc}',
                  ),
                  _TileBruto(
                    icone: Icons.water_drop,
                    cor: Colors.blueAccent,
                    rotulo: 'Solo',
                    valor: leitura != null ? '${leitura.umidadeSolo}%' : '—',
                  ),
                  _TileBruto(
                    icone: Icons.cloud,
                    cor: Colors.teal,
                    rotulo: 'Ar',
                    valor: leitura != null ? '${leitura.umidadeAr}%' : '—',
                  ),
                  _TileBruto(
                    icone: Icons.thermostat,
                    cor: Colors.orange,
                    rotulo: 'Temp',
                    valor: leitura != null
                        ? '${leitura.temperatura.toStringAsFixed(1)}°'
                        : '—',
                  ),
                  _TileBruto(
                    icone: Icons.water_outlined,
                    cor: Colors.cyan,
                    rotulo: 'Vazão',
                    valor: '${disp.vazaoAtual.toStringAsFixed(2)} L/m',
                  ),
                  _TileBruto(
                    icone: Icons.local_drink_outlined,
                    cor: Colors.indigo,
                    rotulo: 'Litros hoje',
                    valor: '${disp.litrosHoje.toStringAsFixed(1)} L',
                  ),
                ],
              ),
          ],
        );
      },
    );
  }
}

class _TileBruto extends StatelessWidget {
  const _TileBruto({
    required this.icone,
    required this.cor,
    required this.rotulo,
    required this.valor,
  });
  final IconData icone;
  final Color cor;
  final String rotulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icone, color: cor, size: 20),
          const SizedBox(height: 4),
          Text(
            valor,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(rotulo, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _BotaoAmostra extends StatelessWidget {
  const _BotaoAmostra({
    required this.rotulo,
    required this.icone,
    required this.capturado,
    required this.desabilitado,
    required this.onTap,
  });
  final String rotulo;
  final IconData icone;
  final int? capturado;
  final bool desabilitado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    final tem = capturado != null;
    return Material(
      color: tem
          ? Colors.green.withValues(alpha: 0.15)
          : cores.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: desabilitado ? null : onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              tem ? Icons.check_circle : icone,
              size: 22,
              color: tem ? Colors.green : cores.primary,
            ),
            const SizedBox(height: 4),
            Text(
              rotulo,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (tem)
              Text('$capturado', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
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
    this.habilitado = true,
  });
  final String rotulo;
  final String valor;
  final double min;
  final double max;
  final double valorAtual;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangedEnd;
  final int? divisions;
  final bool habilitado;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    final divisoes = divisions ?? (max.round() - min.round()).clamp(1, 120);
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
                onChanged: habilitado ? onChanged : null,
                onChangeEnd: habilitado ? onChangedEnd : null,
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

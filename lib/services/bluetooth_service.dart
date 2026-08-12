import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/leitura.dart';
import '../models/planta.dart';
import '../models/problema.dart';
import 'leitura_store.dart';
import 'plantacao_store.dart';
import 'settings_manager.dart';

class DispositivoConectado {
  final BluetoothDevice device;
  BluetoothCharacteristic? writeChar;
  BluetoothCharacteristic? notifyChar;
  StreamSubscription<List<int>>? notifySub;
  bool conectado = false;
  bool conectando = false;
  bool bombaLigada = false;
  bool regaTravada = false;
  bool leitAuto = true;
  int intervaloSolo = 200;
  int intervaloArTemp = 2000;
  int intervaloVazao = 200;
  String? ultimaLeitura;
  DateTime? ultimaPersistencia;
  String? nomePlanta;
  String? firmwareVersion;
  int margemAtiva = 80;
  int irrigacoesHoje = 0;
  double vazaoAtual = 0;
  double litrosHoje = 0;
  int ultimoAdc = -1;
  bool mlRainAtivo = false; // v4.12: verificar clima
  String estadoChuva = ''; // v4.12: ESPERANDO / CHOVEU / REGANDO
  bool modoSensivel = false; // v4.13: modo sensor sensível
  int sensNivel = 50; // v4.13: nível de sensibilidade (1-100)
  final List<Problema> problemas = [];
  Completer<int>? _calCompleter;
  Completer<int>? _adcCompleter;
  final List<Leitura> leituras = [];
  final List<String> log = [];
  final StringBuffer _histBuffer = StringBuffer();
  final StringBuffer _errBuffer = StringBuffer();
  bool _aguardandoErros = false;
  Timer? _errTimeout;

  DispositivoConectado(this.device);

  String get nome {
    if (nomePlanta != null && nomePlanta!.isNotEmpty) return nomePlanta!;
    if (device.platformName.isNotEmpty) return device.platformName;
    return 'ESP32 ${device.remoteId.str.substring(0, 5)}';
  }

  // Versão do firmware como inteiro (ex.: "4.6" -> 46). null = não identificada.
  int? get versaoFirmware {
    final v = firmwareVersion;
    if (v == null || v.isEmpty) return null;
    final partes = v.split('.');
    if (partes.length < 2) return null;
    final major = int.tryParse(partes[0]);
    final minor = int.tryParse(partes[1]);
    if (major == null || minor == null) return null;
    return major * 10 + minor;
  }

  String? get versaoFirmwareTexto {
    if (firmwareVersion == null) return null;
    return 'PEEX v$firmwareVersion';
  }

  String get id => device.remoteId.str;
}

class BluetoothService extends ChangeNotifier {
  BluetoothService._();
  static final BluetoothService instance = BluetoothService._();

  static const String serviceUuid = "6e400001-b5a3-f393-e0a9-e50e24dcca9e";
  static const String writeUuid = "6e400002-b5a3-f393-e0a9-e50e24dcca9e";
  static const String notifyUuid = "6e400003-b5a3-f393-e0a9-e50e24dcca9e";

  static const String cmdUmidade = "@UMIDADE";
  static const String cmdBombaOn = "@BOMBA_ON";
  static const String cmdBombaOff = "@BOMBA_OFF";
  static const String cmdStatus = "@STATUS";
  static const String cmdHist = "@HISTORY";
  static const String cmdLock = "@LOCK";
  static const String cmdErros = "@ERRORS";
  static const String cmdErrLimpar = "@ERRLIMPAR";
  static const String cmdMLRain = "@ML_RAIN";

  final List<BluetoothDevice> _descobertos = [];
  final List<DispositivoConectado> _conectados = [];

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<bool>? _scanningSub;

  bool _isScanning = false;
  bool _soMostrarPeeX = true;
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;

  final Map<String, int> _regasPorDia = {};

  List<BluetoothDevice> get descobertos => List.unmodifiable(_descobertos);
  List<DispositivoConectado> get conectados => List.unmodifiable(_conectados);
  List<DispositivoConectado> get conectadosAtivos =>
      _conectados.where((d) => d.conectado).toList();
  bool get isScanning => _isScanning;
  bool get isConnected => _conectados.any((d) => d.conectado);
  BluetoothAdapterState get adapterState => _adapterState;
  Map<String, int> get regasPorDia => Map.unmodifiable(_regasPorDia);

  bool get soMostrarPeeX => _soMostrarPeeX;
  set soMostrarPeeX(bool valor) {
    _soMostrarPeeX = valor;
    notifyListeners();
  }

  // Lista visível: com o filtro ativo, mostra só dispositivos PEEX
  List<BluetoothDevice> get descobertosVisiveis {
    if (!_soMostrarPeeX) return descobertos;
    return _descobertos
        .where((d) => d.platformName.toUpperCase().contains('PEEX'))
        .toList();
  }

  int get irrigacoesHoje => _regasPorDia[_chaveHoje()] ?? 0;

  String _chaveHoje() {
    final agora = DateTime.now();
    return '${agora.year}-${agora.month.toString().padLeft(2, '0')}-${agora.day.toString().padLeft(2, '0')}';
  }

  Future<void> init() async {
    FlutterBluePlus.adapterState.listen((state) {
      _adapterState = state;
      notifyListeners();
    });
    _scanningSub = FlutterBluePlus.isScanning.listen((v) {
      _isScanning = v;
      notifyListeners();
    });
  }

  Future<bool> ensureAdapterOn() async {
    if (!await FlutterBluePlus.isSupported) return false;
    try {
      await FlutterBluePlus.turnOn();
      await FlutterBluePlus.adapterState
          .where((s) => s == BluetoothAdapterState.on)
          .first
          .timeout(const Duration(seconds: 10));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> startScan() async {
    if (_isScanning) return;
    if (!await ensureAdapterOn()) return;
    _descobertos.clear();
    notifyListeners();

    _scanSub?.cancel();
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        if (!_descobertos.any((d) => d.remoteId == r.device.remoteId)) {
          _descobertos.add(r.device);
        }
      }
      notifyListeners();
    });
    FlutterBluePlus.cancelWhenScanComplete(_scanSub!);

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    } catch (e) {
      SettingsManager.instance.registrarErro("Falha no scan BLE: $e");
    }
  }

  Future<void> stopScan() async {
    if (_isScanning) await FlutterBluePlus.stopScan();
  }

  DispositivoConectado? dispositivoPorId(String id) {
    for (final d in _conectados) {
      if (d.id == id) return d;
    }
    return null;
  }

  DispositivoConectado? dispositivoPorPlanta(String plantaId) {
    return null; // vínculo resolvido pelo esp32Id salvo na planta
  }

  Future<void> conectar(BluetoothDevice device) async {
    DispositivoConectado? disp;
    for (final d in _conectados) {
      if (d.id == device.remoteId.str) disp = d;
    }
    disp ??= DispositivoConectado(device);
    if (!_conectados.contains(disp)) _conectados.add(disp);
    if (disp.conectado || disp.conectando) return;

    disp.conectando = true;
    disp.log.insert(0, "Conectando...");
    notifyListeners();

    try {
      await device.connect(timeout: const Duration(seconds: 20));
      await device.requestMtu(512).catchError((_) => 512);

      disp.conectado = true;
      disp.conectando = false;
      disp.log.insert(0, "Conectado: ${device.platformName}");

      final services = await device.discoverServices();
      for (final s in services) {
        if (s.uuid.str128.toLowerCase() == serviceUuid) {
          for (final c in s.characteristics) {
            if (c.uuid.str128.toLowerCase() == writeUuid) disp.writeChar = c;
            if (c.uuid.str128.toLowerCase() == notifyUuid) {
              disp.notifyChar = c;
            }
          }
        }
      }

      if (disp.notifyChar != null) {
        await disp.notifyChar!.setNotifyValue(true);
        disp.notifySub?.cancel();
        disp.notifySub = disp.notifyChar!.onValueReceived.listen((bytes) {
          _processarDados(disp!, bytes);
        });
      }

      _restaurarPersistidos(disp);
      enviarSincronizarTempo(disp);
      enviar(disp, cmdStatus);
      enviar(disp, '@VERSION'); // v4.6: mostra a versão do firmware no log
      pedirErros(disp); // v4.12: log de problemas do firmware
      final plantaVinculada = PlantacaoStore.instance.plantaPorEsp32(disp.id);
      if (plantaVinculada != null) {
        await _enviarConfigCompleta(disp, plantaVinculada);
      }
      notifyListeners();
    } catch (e) {
      disp.conectando = false;
      disp.conectado = false;
      disp.log.insert(0, "Erro ao conectar: $e");
      SettingsManager.instance
          .registrarErro("Falha ao conectar ${device.platformName}: $e");
      notifyListeners();
    }
  }

  Future<void> conectarTodos() async {
    if (!await ensureAdapterOn()) return;
    final alvos = List<BluetoothDevice>.from(_descobertos);
    for (final d in alvos) {
      if (d.remoteId.str == "") continue;
      await conectar(d);
    }
  }

  void enviarSincronizarTempo(DispositivoConectado disp) {
    final agora = DateTime.now();
    final epoch = agora.millisecondsSinceEpoch ~/ 1000;
    enviar(disp, '@TIME:$epoch');
  }

  Future<void> desconectar(DispositivoConectado disp) async {
    disp.notifySub?.cancel();
    disp.notifySub = null;
    try {
      await disp.device.disconnect();
    } catch (_) {}
    disp.conectado = false;
    disp.conectando = false;
    disp.log.insert(0, "Desconectado");
    _conectados.remove(disp);
    notifyListeners();
  }

  Future<void> desconectarTudo() async {
    for (final d in List.of(_conectados)) {
      await desconectar(d);
    }
  }

  Future<void> desconectarPorId(String esp32Id) async {
    final disp = dispositivoPorId(esp32Id);
    if (disp != null) {
      await desconectar(disp);
    }
  }

  Future<void> carregarPersistenciaGlobal() async {
    final regas = await LeituraStore.instance.carregarRegasPorDia();
    _regasPorDia.clear();
    _regasPorDia.addAll(regas);
    notifyListeners();
  }

  Future<void> _restaurarPersistidos(DispositivoConectado disp) async {
    final persistidos = await LeituraStore.instance.carregarLeituras(disp.id);
    if (persistidos.isEmpty) return;
    _mesclarLeituras(disp.leituras, persistidos);
    if (disp.irrigacoesHoje == 0 && disp.leituras.isNotEmpty) {
      disp.irrigacoesHoje = disp.leituras.last.irrigacoesHoje;
      _regasPorDia[_chaveHoje()] = disp.irrigacoesHoje;
    }
  }

  static void _mesclarLeituras(List<Leitura> destino, List<Leitura> novas) {
    for (final l in novas) {
      final existe = destino.any((d) =>
          d.tempo.millisecondsSinceEpoch == l.tempo.millisecondsSinceEpoch);
      if (!existe) destino.add(l);
    }
    destino.sort((a, b) => a.tempo.compareTo(b.tempo));
    while (destino.length > 500) {
      destino.removeAt(0);
    }
  }

  void vincularPlanta(DispositivoConectado disp, Planta planta) {
    disp.nomePlanta = planta.nome;
    disp.log.insert(0, "Vinculada: ${planta.nome}");
    _enviarConfigCompleta(disp, planta);
    notifyListeners();
  }

  Future<bool> enviarConfigPlanta(Planta planta) async {
    final esp32Id = planta.esp32Id;
    if (esp32Id == null) return false;
    final disp = dispositivoPorId(esp32Id);
    if (disp == null) return false;
    await _enviarConfigCompleta(disp, planta);
    return true;
  }

  Future<bool> enviarConfig(
    DispositivoConectado disp,
    String nomePlanta,
    int umidadeIdeal,
    double fator,
    int margem, {
    int regaInicio = 60,
    int regaFim = 75,
    int tempoMaxRega = 0,
    int intervaloRega = 0,
    int limiteAR = 2400,
    int umidoAlvo = 1200,
  }) async {
    if (!disp.conectado) {
      disp.log.insert(0, "Nao conectado p/ config");
      notifyListeners();
      return false;
    }
    final ok = await enviar(
        disp,
        '@CONFIG:$nomePlanta|$umidadeIdeal|'
        '${fator.toStringAsFixed(1)}|$margem|$tempoMaxRega|$intervaloRega|'
        '$limiteAR|$umidoAlvo|$regaInicio|$regaFim');
    if (ok) {
      disp.margemAtiva = margem;
    }
    return ok;
  }

  Future<bool> enviarML(DispositivoConectado disp, bool ativo) {
    return enviar(disp, ativo ? '@ML:1' : '@ML:0');
  }

  // Nível que LIGA o relé (v4.5+): 0 = LOW, 1 = HIGH. Se o relé fica SEMPRE
  // ligado mesmo desligado, o módulo é provavelmente HIGH-trigger: envie 1.
  Future<bool> enviarReleAtivo(DispositivoConectado disp, bool alto) {
    return enviar(disp, alto ? '@RELE_ATIVO:1' : '@RELE_ATIVO:0');
  }

  // v4.11: leitura por tempo dos sensores (50ms-3s). auto=1 usa os intervalos
  // ideais de cada sensor no firmware; auto=0 usa os valores manuais em ms.
  Future<bool> enviarLeitura(
    DispositivoConectado disp, {
    required bool auto,
    required int solo,
    required int arTemp,
    required int vazao,
  }) {
    return enviar(
      disp,
      '@LEITURA:${auto ? 1 : 0}|$solo|$arTemp|$vazao',
    );
  }

  // Envia config + aprendizado de máquina + leitura por tempo dos sensores
  Future<void> _enviarConfigCompleta(
      DispositivoConectado disp, Planta p) async {
    await enviarConfig(
      disp,
      p.nome,
      p.umidadeIdeal,
      p.fatorPlanta,
      p.margem,
      regaInicio: p.regaInicio,
      regaFim: p.regaFim,
      tempoMaxRega: p.tempoMaxRega,
      intervaloRega: p.intervaloRega,
      limiteAR: p.limiteAR,
      umidoAlvo: p.umidoAlvo,
    );
    await enviarML(disp, p.mlAtivo);
    await enviarMLRain(disp, p.mlRainAtivo);
    await enviarModoSensivel(disp, p.modoSensivel);
    await enviarSensNivel(disp, p.sensNivel);
    await enviarReleAtivo(disp, p.releAtivoAlto);
    await enviarLeitura(
      disp,
      auto: p.leitAuto,
      solo: p.intervaloSolo,
      arTemp: p.intervaloArTemp,
      vazao: p.intervaloVazao,
    );
  }

  Future<bool> enviar(DispositivoConectado disp, String comando) async {
    if (!disp.conectado || disp.writeChar == null) {
      disp.log.insert(0, "Nao conectado");
      notifyListeners();
      return false;
    }
    try {
      await disp.writeChar!.write(utf8.encode(comando), withoutResponse: true);
      disp.log.insert(0, "TX: $comando");
      notifyListeners();
      return true;
    } catch (e) {
      disp.log.insert(0, "Erro ao enviar: $e");
      notifyListeners();
      return false;
    }
  }

  Future<void> lerUmidade(DispositivoConectado disp) =>
      enviar(disp, cmdUmidade);
  Future<void> ligarBomba(DispositivoConectado disp) =>
      enviar(disp, cmdBombaOn);
  Future<void> desligarBomba(DispositivoConectado disp) =>
      enviar(disp, cmdBombaOff);
  Future<void> travarRega(DispositivoConectado disp, bool travada) =>
      enviar(disp, '@LOCK:${travada ? 1 : 0}');
  Future<void> pedirStatus(DispositivoConectado disp) =>
      enviar(disp, cmdStatus);
  Future<void> pedirHistorico(DispositivoConectado disp) async {
    disp._histBuffer.clear();
    await enviar(disp, cmdHist);
  }

  // v4.12: pede o log de problemas gravado no ESP32 (responde várias linhas
  // "epoch,codigo,msg" seguidas de "@ERR_END", igual ao padrão do histórico).
  Future<void> pedirErros(DispositivoConectado disp) async {
    disp._errBuffer.clear();
    disp._aguardandoErros = true;
    disp._errTimeout?.cancel();
    disp._errTimeout = Timer(const Duration(seconds: 5), () {
      disp._aguardandoErros = false; // protege contra firmware sem @ERR_END
      notifyListeners();
    });
    await enviar(disp, cmdErros);
  }

  Future<void> limparErrosFirmware(DispositivoConectado disp) async {
    disp.problemas.clear();
    await enviar(disp, cmdErrLimpar);
  }

  // v4.12: verificar clima (espera chuva em vez de regar na hora)
  Future<bool> enviarMLRain(DispositivoConectado disp, bool ativo) {
    return enviar(disp, ativo ? '$cmdMLRain:1' : '$cmdMLRain:0');
  }

  // v4.13: modo sensor sensível. 0 = desligado (igual à v4.12); 1 = ligado.
  Future<bool> enviarModoSensivel(DispositivoConectado disp, bool ativo) {
    return enviar(disp, ativo ? '@MODO_SENSIVEL:1' : '@MODO_SENSIVEL:0');
  }

  // v4.13: nível de sensibilidade do solo (1-100; 50 = igual ao normal).
  Future<bool> enviarSensNivel(DispositivoConectado disp, int nivel) {
    return enviar(disp, '@SENSIBILIDADE:${nivel.clamp(1, 100)}');
  }

  Future<void> pedirFluxo(DispositivoConectado disp) => enviar(disp, '@FLUXO');
  Future<void> pedirAdc(DispositivoConectado disp) => enviar(disp, '@ADC');

  // Captura a calibração atual do sensor de solo no ESP32.
  // Retorna o novo valor de referência, ou -1 em caso de falha.
  Future<int> capturarCalibracao(
    DispositivoConectado disp, {
    required bool seco,
  }) async {
    if (!disp.conectado) return -1;
    disp._calCompleter = Completer<int>();
    final cmd = seco ? '@CAL:DRY' : '@CAL:WET';
    final ok = await enviar(disp, cmd);
    if (!ok) return -1;
    try {
      return await disp._calCompleter!.future
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      disp._calCompleter = null;
      return -1;
    }
  }

  // Lê o ADC bruto atual do sensor de solo. Retorna -1 em caso de falha.
  Future<int> capturarAdc(DispositivoConectado disp) async {
    if (!disp.conectado) return -1;
    disp._adcCompleter = Completer<int>();
    final ok = await enviar(disp, '@ADC');
    if (!ok) return -1;
    try {
      return await disp._adcCompleter!.future
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      disp._adcCompleter = null;
      return -1;
    }
  }

  void _processarDados(DispositivoConectado disp, List<int> bytes) {
    final txt = utf8.decode(bytes, allowMalformed: true);
    disp.ultimaLeitura = txt;
    disp.log.insert(0, "RX: $txt");
    if (disp.log.length > 80) disp.log.removeLast();

    if (disp._histBuffer.isNotEmpty) {
      disp._histBuffer.write(txt);
      if (txt.contains('@HIST_END')) {
        _finalizarHistorico(disp);
      }
      return;
    }

    if (disp._aguardandoErros) {
      disp._errBuffer.write(txt);
      if (txt.contains('@ERR_END')) {
        _finalizarErros(disp);
      }
      return;
    }

    if (txt.startsWith('@DATA:')) {
      final partes = txt.replaceFirst('@DATA:', '').split(',');
      if (partes.length >= 5) {
        final epoch = int.tryParse(partes[0]) ?? 0;
        final solo = int.tryParse(partes[1]) ?? 0;
        final ar = int.tryParse(partes[2]) ?? 0;
        final temp = double.tryParse(partes[3]) ?? 0;
        final irrHoje = int.tryParse(partes[4]) ?? 0;
        final vazao =
            partes.length > 5 ? double.tryParse(partes[5]) ?? 0.0 : 0.0;
        final litros =
            partes.length > 6 ? double.tryParse(partes[6]) ?? 0.0 : 0.0;
        final adc = partes.length > 7 ? int.tryParse(partes[7]) ?? -1 : -1;
        disp.ultimoAdc = adc;
        final tempo = epoch > 0
            ? DateTime.fromMillisecondsSinceEpoch(epoch * 1000)
            : DateTime.now();
        _registrarLeitura(
            disp,
            Leitura(
              tempo: tempo,
              umidadeSolo: solo,
              umidadeAr: ar,
              temperatura: temp,
              irrigacoesHoje: irrHoje,
              vazao: vazao,
              litros: litros,
            ));
        disp.irrigacoesHoje = irrHoje;
        disp.vazaoAtual = vazao;
        disp.litrosHoje = litros;
        if (irrHoje > 0) _registrarRega(irrHoje);
      }
    } else if (txt.startsWith('@FLUXO:')) {
      final partes = txt.replaceFirst('@FLUXO:', '').split(',');
      if (partes.isNotEmpty) disp.vazaoAtual = double.tryParse(partes[0]) ?? 0;
      if (partes.length > 1) disp.litrosHoje = double.tryParse(partes[1]) ?? 0;
    } else if (txt.startsWith('@ADC:')) {
      final v = int.tryParse(txt.replaceFirst('@ADC:', '')) ?? -1;
      disp.ultimoAdc = v;
      final c = disp._adcCompleter;
      disp._adcCompleter = null;
      if (c != null && !c.isCompleted) c.complete(v);
    } else if (txt.startsWith('@CAL:')) {
      // @CAL:DRY:<val> / @CAL:WET:<val>
      final partes = txt.split(':');
      if (partes.length >= 3) {
        final v = int.tryParse(partes[2]) ?? -1;
        final c = disp._calCompleter;
        disp._calCompleter = null;
        if (c != null && !c.isCompleted) c.complete(v);
      }
    } else if (txt.startsWith('@VERSION:')) {
      disp.firmwareVersion = txt.replaceFirst('@VERSION:', '').trim();
    } else if (txt.startsWith('@ERR:OK')) {
      // Log de problemas apagado no firmware (v4.12)
      disp.problemas.clear();
      notifyListeners();
    } else if (txt.startsWith('@ML_RAIN:')) {
      final v = txt.replaceFirst('@ML_RAIN:', '').trim();
      disp.mlRainAtivo = (v == 'ON' || v == '1' || v.toLowerCase() == 'on');
    } else if (txt.startsWith('@MODO_SENSIVEL:')) {
      // v4.13: resposta "@MODO_SENSIVEL:<0|1>|<nível>" (via @STATUS)
      final partes = txt.replaceFirst('@MODO_SENSIVEL:', '').trim().split('|');
      if (partes.isNotEmpty) {
        disp.modoSensivel =
            (partes[0] == '1' || partes[0].toLowerCase() == 'on');
      }
      if (partes.length >= 2) {
        final n = int.tryParse(partes[1]);
        if (n != null && n >= 1 && n <= 100) disp.sensNivel = n;
      }
    } else if (txt.startsWith('@RAIN:')) {
      disp.estadoChuva = txt.replaceFirst('@RAIN:', '').trim();
    } else if (txt.startsWith('@ERRO:')) {
      // O ESP32 respondeu com erro (ex.: comando desconhecido = firmware
      // antigo). Encerra imediatamente as capturas pendentes (calibração/ADC)
      // para o app avisar o motivo certo em vez de esperar o timeout.
      final c = disp._adcCompleter;
      disp._adcCompleter = null;
      if (c != null && !c.isCompleted) c.complete(-1);
      final cal = disp._calCompleter;
      disp._calCompleter = null;
      if (cal != null && !cal.isCompleted) cal.complete(-1);
    } else if (txt.startsWith('@CONFIG:OK')) {
      final restante = txt.replaceFirst('@CONFIG:OK', '').trim();
      if (restante.isNotEmpty) disp.nomePlanta = restante;
      _aplicarConfigLida(disp);
    } else if (txt.startsWith('@IRR:')) {
      final irrHoje = int.tryParse(txt.replaceFirst('@IRR:', '')) ?? 0;
      disp.irrigacoesHoje = irrHoje;
      _registrarRega(irrHoje);
    } else if (txt.startsWith('@BOMBA:')) {
      if (txt.contains('LIGADA')) {
        disp.bombaLigada = true;
        final atual = _regasPorDia[_chaveHoje()] ?? 0;
        _registrarRega(atual + 1);
      } else if (txt.contains('DESLIGADA')) {
        disp.bombaLigada = false;
      }
    } else if (txt.startsWith('@LOCK:')) {
      final v = txt.replaceFirst('@LOCK:', '').trim();
      disp.regaTravada = (v == '1' || v.toLowerCase() == 'on');
    } else if (txt.startsWith('@LEITURA:')) {
      final partes = txt
          .replaceFirst('@LEITURA:', '')
          .trim()
          .split('|')
          .map((s) => s.trim())
          .toList();
      if (partes.isNotEmpty && partes[0] != 'OK') {
        disp.leitAuto = partes.isNotEmpty && partes[0] == '1';
        if (partes.length >= 2) {
          disp.intervaloSolo = int.tryParse(partes[1]) ?? disp.intervaloSolo;
        }
        if (partes.length >= 3) {
          disp.intervaloArTemp =
              int.tryParse(partes[2]) ?? disp.intervaloArTemp;
        }
        if (partes.length >= 4) {
          disp.intervaloVazao = int.tryParse(partes[3]) ?? disp.intervaloVazao;
        }
      }
    } else if (txt.startsWith('@STATUS:')) {
      _aplicarConfigLida(disp);
    }
    notifyListeners();
  }

  void _registrarLeitura(DispositivoConectado disp, Leitura leitura) {
    disp.leituras.add(leitura);
    if (disp.leituras.length > 500) disp.leituras.removeAt(0);
    // Tempo real: a lista em memória atualiza sempre; gravar em disco no
    // máximo 1x/30s (com telemetria de 200ms, gravar a cada pacote travaria).
    final agora = DateTime.now();
    final ant = disp.ultimaPersistencia;
    if (ant == null || agora.difference(ant) >= const Duration(seconds: 30)) {
      disp.ultimaPersistencia = agora;
      LeituraStore.instance.salvarLeituras(disp.id, disp.leituras);
    }
  }

  void _registrarRega(int totalHoje) {
    // Só grava quando o total do dia muda (durante a rega o @DATA repete o
    // mesmo valor a cada 200ms — evitar gravações em disco desnecessárias).
    final chave = _chaveHoje();
    if ((_regasPorDia[chave] ?? 0) == totalHoje) return;
    _regasPorDia[chave] = totalHoje;
    LeituraStore.instance.salvarRegasPorDia(_regasPorDia);
  }

  void _aplicarConfigLida(DispositivoConectado disp) {
    if (disp.leituras.isNotEmpty) {
      disp.irrigacoesHoje = disp.leituras.last.irrigacoesHoje;
    }
  }

  void _finalizarHistorico(DispositivoConectado disp) {
    final bruto = disp._histBuffer.toString();
    disp._histBuffer.clear();
    final linhas = bruto
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.startsWith('@'))
        .toList();
    final historico = <Leitura>[];
    for (final linha in linhas) {
      final partes = linha.split(',');
      if (partes.length < 7) continue;
      final epoch = int.tryParse(partes[0]) ?? 0;
      if (epoch <= 0) continue;
      historico.add(Leitura(
        tempo: DateTime.fromMillisecondsSinceEpoch(epoch * 1000),
        umidadeSolo: int.tryParse(partes[1]) ?? 0,
        umidadeAr: int.tryParse(partes[2]) ?? 0,
        temperatura: double.tryParse(partes[3]) ?? 0,
        irrigacoesHoje: int.tryParse(partes[4]) ?? 0,
        vazao: double.tryParse(partes[5]) ?? 0,
        litros: double.tryParse(partes[6]) ?? 0,
        duracao: partes.length > 7 ? int.tryParse(partes[7]) ?? 0 : 0,
      ));
    }
    if (historico.isEmpty) {
      notifyListeners();
      return;
    }
    _mesclarLeituras(disp.leituras, historico);
    LeituraStore.instance.salvarLeituras(disp.id, disp.leituras);
    if (disp.leituras.isNotEmpty) {
      final ultima = disp.leituras.last;
      disp.irrigacoesHoje = ultima.irrigacoesHoje;
      disp.litrosHoje = ultima.litros;
      _registrarRega(ultima.irrigacoesHoje);
    }
    notifyListeners();
  }

  // v4.12: termina de ler o log de problemas vindo do ESP32 (@ERRORS).
  void _finalizarErros(DispositivoConectado disp) {
    disp._aguardandoErros = false;
    disp._errTimeout?.cancel();
    disp._errTimeout = null;
    final bruto = disp._errBuffer.toString();
    disp._errBuffer.clear();
    final linhas = bruto
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.startsWith('@'))
        .toList();
    disp.problemas
      ..clear()
      ..addAll(linhas.map(Problema.fromLinha));
    notifyListeners();
  }

  void disposeAll() {
    _scanSub?.cancel();
    _scanningSub?.cancel();
    for (final d in _conectados) {
      d.notifySub?.cancel();
    }
    dispose();
  }
}

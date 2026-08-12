import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/planta.dart';

class PlantacaoStore extends ChangeNotifier {
  PlantacaoStore._();
  static final PlantacaoStore instance = PlantacaoStore._();

  static const String _kKey = 'plantas';

  final List<Planta> _plantas = [];
  String? _plantaAtivaId;

  List<Planta> get plantas => List.unmodifiable(_plantas);
  Planta? get plantaAtiva {
    if (_plantaAtivaId == null) return null;
    for (final p in _plantas) {
      if (p.id == _plantaAtivaId) return p;
    }
    return null;
  }

  Planta? plantaPorEsp32(String esp32Id) {
    for (final p in _plantas) {
      if (p.esp32Id == esp32Id) return p;
    }
    return null;
  }

  Future<void> carregar() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw != null) {
      final lista = jsonDecode(raw) as List;
      _plantas.clear();
      for (final item in lista) {
        _plantas.add(Planta.fromJson(item as Map<String, dynamic>));
      }
    }
    _plantaAtivaId = prefs.getString('planta_ativa');
    notifyListeners();
  }

  Future<void> adicionar(Planta planta) async {
    _plantas.add(planta);
    _plantaAtivaId ??= planta.id;
    await _salvar();
    notifyListeners();
  }

  Future<void> remover(String id) async {
    _plantas.removeWhere((p) => p.id == id);
    if (_plantaAtivaId == id)
      _plantaAtivaId = _plantas.isNotEmpty ? _plantas.first.id : null;
    await _salvar();
    notifyListeners();
  }

  Future<void> setPlantaAtiva(String id) async {
    _plantaAtivaId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('planta_ativa', id);
    notifyListeners();
  }

  Future<void> vincularEsp32(
      String plantaId, String esp32Id, String esp32Nome) async {
    for (final p in _plantas) {
      if (p.id == plantaId) {
        p.esp32Id = esp32Id;
        p.esp32Nome = esp32Nome;
      }
    }
    await _salvar();
    notifyListeners();
  }

  Future<void> atualizarNome(String plantaId, String nome) async {
    for (final p in _plantas) {
      if (p.id == plantaId) p.nome = nome;
    }
    await _salvar();
    notifyListeners();
  }

  Future<void> atualizarImagem(String plantaId, String? imagem) async {
    for (final p in _plantas) {
      if (p.id == plantaId) p.imagemPerfil = imagem;
    }
    await _salvar();
    notifyListeners();
  }

  Future<void> atualizarConfig(
    String plantaId,
    int umidadeIdeal,
    double fatorPlanta,
    int margem, {
    int? regaInicio,
    int? regaFim,
    int? tempoMaxRega,
    int? intervaloRega,
    int? limiteAR,
    int? umidoAlvo,
    bool? mlAtivo,
    bool? mlRainAtivo,
    bool? modoSensivel,
    int? sensNivel,
    bool? releAtivoAlto,
    bool? regaTravada,
    bool? leitAuto,
    int? intervaloSolo,
    int? intervaloArTemp,
    int? intervaloVazao,
    bool? calibracaoInvertida,
    Map<String, int>? amostras,
  }) async {
    for (final p in _plantas) {
      if (p.id == plantaId) {
        p.umidadeIdeal = umidadeIdeal;
        p.fatorPlanta = fatorPlanta;
        p.margem = margem;
        if (regaInicio != null) p.regaInicio = regaInicio;
        if (regaFim != null) p.regaFim = regaFim;
        if (tempoMaxRega != null) p.tempoMaxRega = tempoMaxRega;
        if (intervaloRega != null) p.intervaloRega = intervaloRega;
        if (limiteAR != null) p.limiteAR = limiteAR;
        if (umidoAlvo != null) p.umidoAlvo = umidoAlvo;
        if (mlAtivo != null) p.mlAtivo = mlAtivo;
        if (mlRainAtivo != null) p.mlRainAtivo = mlRainAtivo;
        if (modoSensivel != null) p.modoSensivel = modoSensivel;
        if (sensNivel != null) p.sensNivel = sensNivel;
        if (releAtivoAlto != null) p.releAtivoAlto = releAtivoAlto;
        if (regaTravada != null) p.regaTravada = regaTravada;
        if (leitAuto != null) p.leitAuto = leitAuto;
        if (intervaloSolo != null) p.intervaloSolo = intervaloSolo;
        if (intervaloArTemp != null) p.intervaloArTemp = intervaloArTemp;
        if (intervaloVazao != null) p.intervaloVazao = intervaloVazao;
        if (calibracaoInvertida != null)
          p.calibracaoInvertida = calibracaoInvertida;
        if (amostras != null) p.amostras = amostras;
      }
    }
    await _salvar();
    notifyListeners();
  }

  Future<void> desvincularEsp32(String plantaId) async {
    for (final p in _plantas) {
      if (p.id == plantaId) {
        p.esp32Id = null;
        p.esp32Nome = null;
      }
    }
    await _salvar();
    notifyListeners();
  }

  Future<void> _salvar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kKey,
      jsonEncode(_plantas.map((p) => p.toJson()).toList()),
    );
    await prefs.setString('planta_ativa', _plantaAtivaId ?? '');
  }

  Future<void> limpar() async {
    _plantas.clear();
    _plantaAtivaId = null;
    await _salvar();
    notifyListeners();
  }
}

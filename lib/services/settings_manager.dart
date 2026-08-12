import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsManager extends ChangeNotifier {
  SettingsManager._();
  static final SettingsManager instance = SettingsManager._();

  static const String _kReconnect = 'reconectar_auto';
  static const String _kConstante = 'constante_irrigacao';
  static const String _kTema = 'modo_tema';
  static const String _kFonte = 'fonte_familia';

  static const List<String> fontesDisponiveis = [
    'Sistema',
    'Poppins',
    'Roboto',
    'Montserrat',
    'Lora',
    'Playfair Display',
  ];

  bool _reconectarAuto = true;
  double _constanteIrrigacao = 1.0;
  String _modoTema = 'system';
  String _fonte = 'Sistema';
  bool _carregado = false;
  final List<String> _erros = [];

  bool get reconectarAuto => _reconectarAuto;
  double get constanteIrrigacao => _constanteIrrigacao;
  String get modoTema => _modoTema;
  String get fonte => _fonte;
  bool get carregado => _carregado;
  List<String> get erros => List.unmodifiable(_erros);

  ThemeMode get themeMode {
    switch (_modoTema) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> carregar() async {
    final prefs = await SharedPreferences.getInstance();
    _reconectarAuto = prefs.getBool(_kReconnect) ?? true;
    _constanteIrrigacao = prefs.getDouble(_kConstante) ?? 1.0;
    _modoTema = prefs.getString(_kTema) ?? 'system';
    _fonte = prefs.getString(_kFonte) ?? 'Sistema';
    _carregado = true;
    notifyListeners();
  }

  Future<void> setReconectarAuto(bool valor) async {
    _reconectarAuto = valor;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kReconnect, valor);
  }

  Future<void> setConstanteIrrigacao(double valor) async {
    _constanteIrrigacao = valor;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kConstante, valor);
  }

  Future<void> setModoTema(String valor) async {
    _modoTema = valor;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTema, valor);
  }

  Future<void> setFonte(String valor) async {
    _fonte = valor;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kFonte, valor);
  }

  void registrarErro(String erro) {
    _erros.insert(
      0,
      '${DateTime.now().toString().substring(0, 19)} - $erro',
    );
    if (_erros.length > 100) _erros.removeLast();
    notifyListeners();
  }

  void limparErros() {
    _erros.clear();
    notifyListeners();
  }

  Future<void> limparTudo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _reconectarAuto = true;
    _constanteIrrigacao = 1.0;
    _modoTema = 'system';
    _fonte = 'Sistema';
    _erros.clear();
    notifyListeners();
  }
}

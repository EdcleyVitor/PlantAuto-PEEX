import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/leitura.dart';

class LeituraStore extends ChangeNotifier {
  LeituraStore._();
  static final LeituraStore instance = LeituraStore._();

  static const int maxPorDispositivo = 1500;

  Future<void> salvarLeituras(String esp32Id, List<Leitura> leituras) async {
    if (esp32Id.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final lista = leituras.length > maxPorDispositivo
        ? leituras.sublist(leituras.length - maxPorDispositivo)
        : leituras;
    await prefs.setString(
      'leituras_$esp32Id',
      jsonEncode(lista.map((l) => l.toJson()).toList()),
    );
  }

  Future<List<Leitura>> carregarLeituras(String esp32Id) async {
    if (esp32Id.isEmpty) return [];
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('leituras_$esp32Id');
    if (raw == null) return [];
    try {
      final lista = jsonDecode(raw) as List;
      final leituras = lista
          .map((item) => Leitura.fromJson(item as Map<String, dynamic>))
          .toList();
      leituras.sort((a, b) => a.tempo.compareTo(b.tempo));
      return leituras;
    } catch (_) {
      return [];
    }
  }

  Future<void> salvarRegasPorDia(Map<String, int> regas) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'regas_por_dia',
      jsonEncode(regas.map((k, v) => MapEntry(k, v))),
    );
  }

  Future<Map<String, int>> carregarRegasPorDia() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('regas_por_dia');
    if (raw == null) return {};
    try {
      final mapa = jsonDecode(raw) as Map<String, dynamic>;
      return mapa.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  // Apaga TODAS as leituras salvas e o mapa de regas por dia.
  Future<void> limparTudo() async {
    final prefs = await SharedPreferences.getInstance();
    for (final chave in prefs.getKeys().toList()) {
      if (chave.startsWith('leituras_') || chave == 'regas_por_dia') {
        await prefs.remove(chave);
      }
    }
  }
}

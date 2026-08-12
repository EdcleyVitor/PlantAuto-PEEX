class Leitura {
  final DateTime tempo;
  final int umidadeSolo;
  final int umidadeAr;
  final double temperatura;
  final int irrigacoesHoje;
  final double vazao;
  final double litros;
  final int duracao;

  Leitura({
    required this.tempo,
    required this.umidadeSolo,
    required this.umidadeAr,
    required this.temperatura,
    required this.irrigacoesHoje,
    this.vazao = 0,
    this.litros = 0,
    this.duracao = 0,
  });

  factory Leitura.fromLinha(String linha) {
    final partes = linha.split(',');
    return Leitura(
      tempo: DateTime.now(),
      umidadeSolo: partes.isNotEmpty ? int.tryParse(partes[0]) ?? 0 : 0,
      umidadeAr: partes.length > 1 ? int.tryParse(partes[1]) ?? 0 : 0,
      temperatura: partes.length > 2 ? double.tryParse(partes[2]) ?? 0 : 0,
      irrigacoesHoje: partes.length > 3 ? int.tryParse(partes[3]) ?? 0 : 0,
      vazao: partes.length > 4 ? double.tryParse(partes[4]) ?? 0 : 0,
      litros: partes.length > 5 ? double.tryParse(partes[5]) ?? 0 : 0,
      duracao: partes.length > 6 ? int.tryParse(partes[6]) ?? 0 : 0,
    );
  }

  Map<String, dynamic> toJson() => {
        't': tempo.millisecondsSinceEpoch,
        'solo': umidadeSolo,
        'ar': umidadeAr,
        'temp': temperatura,
        'irr': irrigacoesHoje,
        'vazao': vazao,
        'litros': litros,
        'dur': duracao,
      };

  factory Leitura.fromJson(Map<String, dynamic> json) => Leitura(
        tempo: DateTime.fromMillisecondsSinceEpoch(
            (json['t'] as num?)?.toInt() ?? 0),
        umidadeSolo: (json['solo'] as num?)?.toInt() ?? 0,
        umidadeAr: (json['ar'] as num?)?.toInt() ?? 0,
        temperatura: (json['temp'] as num?)?.toDouble() ?? 0,
        irrigacoesHoje: (json['irr'] as num?)?.toInt() ?? 0,
        vazao: (json['vazao'] as num?)?.toDouble() ?? 0,
        litros: (json['litros'] as num?)?.toDouble() ?? 0,
        duracao: (json['dur'] as num?)?.toInt() ?? 0,
      );
}

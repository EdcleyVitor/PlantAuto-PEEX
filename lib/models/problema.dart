class Problema {
  final DateTime tempo;
  final String codigo;
  final String mensagem;

  Problema({required this.tempo, required this.codigo, required this.mensagem});

  factory Problema.fromLinha(String linha) {
    final partes = linha.split(',');
    final epoch = partes.isNotEmpty ? int.tryParse(partes[0]) ?? 0 : 0;
    return Problema(
      tempo: epoch > 0
          ? DateTime.fromMillisecondsSinceEpoch(epoch * 1000)
          : DateTime.now(),
      codigo: partes.length > 1 ? partes[1] : 'DESCONHECIDO',
      mensagem: partes.length > 2
          ? partes.sublist(2).join(',')
          : 'Problema desconhecido',
    );
  }

  String get rotulo {
    switch (codigo) {
      case 'SEM_AGUA':
        return 'Sem água';
      case 'SENSOR_DHT':
        return 'Sensor de ar';
      case 'SENSOR_SOLO':
        return 'Sensor de solo';
      default:
        return codigo;
    }
  }

  Map<String, dynamic> toJson() => {
        't': tempo.millisecondsSinceEpoch,
        'codigo': codigo,
        'msg': mensagem,
      };

  factory Problema.fromJson(Map<String, dynamic> json) => Problema(
        tempo: DateTime.fromMillisecondsSinceEpoch(
            (json['t'] as num?)?.toInt() ?? 0),
        codigo: (json['codigo'] as String?) ?? 'DESCONHECIDO',
        mensagem: (json['msg'] as String?) ?? 'Problema desconhecido',
      );
}

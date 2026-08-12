class Planta {
  final String id;
  String nome;
  int umidadeIdeal;
  double fatorPlanta;
  int margem;
  int regaInicio;
  int regaFim;
  int tempoMaxRega;
  int intervaloRega;
  int limiteAR;
  int umidoAlvo;
  bool mlAtivo;
  bool mlRainAtivo;
  bool modoSensivel;
  int sensNivel;
  bool releAtivoAlto;
  bool regaTravada;
  bool leitAuto;
  int intervaloSolo;
  int intervaloArTemp;
  int intervaloVazao;
  bool calibracaoInvertida;
  Map<String, int> amostras;
  final DateTime dataAdicionada;
  String? esp32Id;
  String? esp32Nome;
  String? imagemPerfil;

  Planta({
    required this.id,
    required this.nome,
    required this.umidadeIdeal,
    required this.fatorPlanta,
    required this.dataAdicionada,
    this.margem = 80,
    this.regaInicio = 60,
    this.regaFim = 75,
    this.tempoMaxRega = 0,
    this.intervaloRega = 0,
    this.limiteAR = 2400,
    this.umidoAlvo = 1200,
    this.mlAtivo = false,
    this.mlRainAtivo = false,
    this.modoSensivel = false,
    this.sensNivel = 50,
    this.releAtivoAlto = false,
    this.regaTravada = false,
    this.leitAuto = true,
    this.intervaloSolo = 200,
    this.intervaloArTemp = 2000,
    this.intervaloVazao = 200,
    this.calibracaoInvertida = false,
    this.amostras = const {},
    this.esp32Id,
    this.esp32Nome,
    this.imagemPerfil,
  });

  String get fatorNome {
    if (fatorPlanta <= 0.6) return "Mínima";
    if (fatorPlanta >= 1.4) return "Frequente";
    return "Média";
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'umidadeIdeal': umidadeIdeal,
        'fatorPlanta': fatorPlanta,
        'margem': margem,
        'regaInicio': regaInicio,
        'regaFim': regaFim,
        'tempoMaxRega': tempoMaxRega,
        'intervaloRega': intervaloRega,
        'limiteAR': limiteAR,
        'umidoAlvo': umidoAlvo,
        'mlAtivo': mlAtivo,
        'mlRainAtivo': mlRainAtivo,
        'modoSensivel': modoSensivel,
        'sensNivel': sensNivel,
        'releAtivoAlto': releAtivoAlto,
        'regaTravada': regaTravada,
        'leitAuto': leitAuto,
        'intervaloSolo': intervaloSolo,
        'intervaloArTemp': intervaloArTemp,
        'intervaloVazao': intervaloVazao,
        'calibracaoInvertida': calibracaoInvertida,
        'amostras': amostras,
        'dataAdicionada': dataAdicionada.toIso8601String(),
        'esp32Id': esp32Id,
        'esp32Nome': esp32Nome,
        'imagemPerfil': imagemPerfil,
      };

  factory Planta.fromJson(Map<String, dynamic> json) => Planta(
        id: json['id'] as String,
        nome: json['nome'] as String,
        umidadeIdeal: json['umidadeIdeal'] as int,
        fatorPlanta: (json['fatorPlanta'] as num).toDouble(),
        margem: (json['margem'] as num?)?.toInt() ?? 80,
        regaInicio: (json['regaInicio'] as num?)?.toInt() ?? 60,
        regaFim: (json['regaFim'] as num?)?.toInt() ?? 75,
        tempoMaxRega: (json['tempoMaxRega'] as num?)?.toInt() ?? 0,
        intervaloRega: (json['intervaloRega'] as num?)?.toInt() ?? 0,
        limiteAR: (json['limiteAR'] as num?)?.toInt() ?? 2400,
        umidoAlvo: (json['umidoAlvo'] as num?)?.toInt() ?? 1200,
        mlAtivo: json['mlAtivo'] as bool? ?? false,
        mlRainAtivo: json['mlRainAtivo'] as bool? ?? false,
        modoSensivel: json['modoSensivel'] as bool? ?? false,
        sensNivel: (json['sensNivel'] as num?)?.toInt() ?? 50,
        releAtivoAlto: json['releAtivoAlto'] as bool? ?? false,
        regaTravada: json['regaTravada'] as bool? ?? false,
        leitAuto: json['leitAuto'] as bool? ?? true,
        intervaloSolo: (json['intervaloSolo'] as num?)?.toInt() ?? 200,
        intervaloArTemp: (json['intervaloArTemp'] as num?)?.toInt() ?? 2000,
        intervaloVazao: (json['intervaloVazao'] as num?)?.toInt() ?? 200,
        calibracaoInvertida: json['calibracaoInvertida'] as bool? ?? false,
        amostras: (json['amostras'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(k, (v as num).toInt())) ??
            const {},
        dataAdicionada: DateTime.parse(json['dataAdicionada'] as String),
        esp32Id: json['esp32Id'] as String?,
        esp32Nome: json['esp32Nome'] as String?,
        imagemPerfil: json['imagemPerfil'] as String?,
      );
}

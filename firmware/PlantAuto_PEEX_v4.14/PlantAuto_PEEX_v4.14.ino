/*
  PlantAuto PEEX - Firmware ESP32 BLE v4.14
  Comunicação via Bluetooth (NUS) com o app Flutter PlantAuto PEEX.

  NOVIDADES DA v4.14:
    - ESPERA DE BOOT (1 MINUTO): ao ligar, o ESP32 fica 1 minuto "descansando":
      não rega, não coleta amostras de ML, não decide nada — só anuncia o
      Bluetooth e espera o app conectar. Se o celular conectar nesse tempo, a
      espera acaba NA HORA e tudo volta ao normal. Se ninguém conectar, depois
      de 60s o firmware segue sozinho. O LCD mostra a contagem regressiva.
      Serve para dar tempo de organizar as coisas depois de um blecaute.

  NOVIDADES DA v4.13:
    - MODO SENSOR SENSÍVEL (@MODO_SENSIVEL + @SENSIBILIDADE): para sensores de
      umidade do solo MUITO sensíveis (que tremem ou saturam a leitura), o app
      pode ligar um modo especial. Com ele LIGADO, um nível de sensibilidade
      (1 a 100) ajusta a escala da leitura: 50 = igual ao normal, menor = leitura
      mais estável/suave, maior = reage mais forte. Com o modo DESLIGADO o
      firmware se comporta exatamente como na v4.12. Tudo fica salvo no NVS.

  NOVIDADES DA v4.12:
    - LOG DE PROBLEMAS: o firmware detecta sozinho (a cada 3s) e salva no NVS
      problemas como: relé ligado SEM água saindo (@ERRORS p/ o app ler),
      sensor de solo preso/instável ("maluco") e DHT22 não detectado. O log
      entra no relatório.
    - VERIFICAR CLIMA (@ML_RAIN): se o ar está úmido (>=60%) e a temperatura
      baixa (<=30°C), a chuva é provável. Com o solo seco, em vez de regar na
      hora o firmware espera 30 min (15 min à noite/madrugada) para ver se
      chove. Se nada acontecer e o solo continuar seco, rega; se chover,
      cancela.

  NOVIDADES DA v4.11:
    - LEITURA POR TEMPO (@LEITURA): o app define de quanto em quanto tempo
      cada sensor é lido (50 ms a 3 s). Com "Automático" ligado o firmware
      usa os intervalos ideais (solo 200 ms, ar/temperatura ~2 s, vazão
      200 ms). Substitui a antiga "Sensibilidade dos sensores".

  NOVIDADES DA v4.10:
    - ACEITA QUALQUER TIPO DE SENSOR DE SOLO: auto-range automático. O
      firmware aprende a faixa de ADC que o sensor entrega (mín. = mais úmido,
      máx. = mais seco) e mapeia 0-100% sozinho, SEM precisar calibrar. Se
      houver calibração manual válida, ela continua sendo usada; só cai no
      auto-range quando a calibração é degenerada (seco == úmido).

  NOVIDADES DA v4.9:
    - TRAVA DE SEGURANÇA (@LOCK): trava a rega de forma permanente (fica
      salvo no NVS). Com a trava ativa o ESP32 NUNCA liga a rega — nem
      manual (@BOMBA_ON), nem automática. Se a trava for ligada no meio de
      uma rega, a rega para na hora. O estado é reportado no @STATUS e no
      @LOCK:<0|1>.


  NOVIDADES DA v4.8:
    - TELEMETRIA EM TEMPO REAL: enquanto conectado, o ESP32 envia os dados
      (@DATA) a cada 200 ms (antes eram 5 segundos). O sensor de vazão também
      é calculado a cada 200 ms (agora com base no tempo real, correto para
      qualquer intervalo). O DHT22 continua limitado pelo hardware a ~1 leitura
      a cada 2 s (o valor mais recente é repetido na telemetria).

  NOVIDADES DA v4.7:
    - RELÉ NO GPIO13: o pino do relé foi movido de D27 para D13 para
      acompanhar a ligação física usada na bancada. Nenhuma outra mudança
      de comportamento em relação à v4.6.

  NOVIDADES DA v4.6:
    - LIMITES DIRETOS DE REGA: agora o ESP32 usa dois valores simples e
      diretos (configuráveis pelo app, @CONFIG com 10 campos):
        * regaInicio: LIGA a válvula quando a umidade do solo fica ABAIXO
          de X% (padrão 60%).
        * regaFim: DESLIGA quando a umidade do solo fica ACIMA de Y%
          (padrão 75%).
      Isso acaba com o problema do "nunca rega": antes a rega só iniciava
      quando umidade < (ideal - margem), e com a margem padrão alta o valor
      ficava negativo (nunca disparava). Agora os limites são diretos.
    - RESET TOTAL DE FÁBRICA NO BOTÃO BOOT: segure BOOT (GPIO0) por 3
      segundos e o ESP32 volta EXATAMENTE ao estado recém-compilado:
      apaga todos os dados salvos (histórico, calibração, configuração,
      litros), restaura TODOS os padrões de fábrica (nome BLE "PEEX",
      umidade ideal 70%, margem 80, rega abaixo de 60% / acima de 75%,
      sensibilidade máxima, relé nível LOW) e reinicia.

  NOVIDADES DA v4.5:
    - ASSINATURA PEEX (@SIGN): o ESP32 responde "@SIGN:PEEX" quando o app
      pergunta, autenticando o dispositivo como oficial PEEX (o nome BLE já
      traz o prefixo "PEEX-"; a assinatura confirma por comando).
    - RELÉ CORRIGIDO: o relé agora é controlado por um nível configurável
      (padrão low-level trigger) que pode ser trocado SEM recompilar pelo
      comando @RELE_ATIVO:<0|1> (0 = LOW, 1 = HIGH) ou editando o define
      RELE_ATIVO_NIVEL. No boot o relé já sai forçado para DESLIGADO e, a cada
      segundo, o firmware reforça o estado desligado quando não está regando —
      acabando com o problema do relé "sempre ligado".
    - RESET TOTAL PELO BOTÃO BOOT: segure o botão BOOT (GPIO0) por 3 segundos
      para apagar TODOS os dados salvos (histórico, calibração, configuração,
      litros) e reiniciar de fábrica. O LCD mostra "Resetando..." durante o
      processo.
    - CORREÇÃO: gravação do histórico agora identifica corretamente a última
      linha (bug do v4.1 que fazia cada leitura estável ser gravada de novo).

  NOVIDADES DA v4.3 (CALIBRAÇÃO DO SENSOR DE SOLO):
    - CALIBRAÇÃO POR TOQUE: comandos @CAL:DRY e @CAL:WET capturam a leitura
      ATUAL do ADC como referência de solo SECO ou solo ÚMIDO — sem precisar
      saber os valores. Ideal para quem não sabe quanto o sensor lê.
    - O mapeamento agora DETECTA A ORIENTAÇÃO do sensor automaticamente:
      aceita tanto sensor que lê ALTO no seco (mais comum) quanto sensor que
      lê BAIXO no seco. Basta calibrar SECO e ÚMIDO que a porcentagem fica
      certa, sem recompilar.
    - ADC bruto enviado na telemetria (@DATA ...campo 8) e comando @ADC para
      o app mostrar a leitura ao vivo e facilitar a calibração.

  NOVIDADES DA v4.2:
    - APRENDIZADO DE MÁQUINA (rega inteligente): o ESP32 coleta amostras da
      umidade do solo durante a secagem e faz uma REGRESSÃO LINEAR (mínimos
      quadrados) para aprender a velocidade de secagem e PREVER quando o solo
      vai atingir o limite de rega. Se a previsão indica que secará dentro de
      até 10 minutos, a rega começa ANTES da hora (irrigação preditiva).
      Também aprende a EFICIÊNCIA da rega (% de subida do solo por minuto) em
      cada rega e usa esse valor para definir a duração da próxima rega,
      adaptando-se à planta ao longo do tempo. Ligado/desligado pelo app
      (comando @ML) e persistido no NVS. A eficiência aprendida também é
      salva (sobrevive a religamentos).
    - SENSIBILIDADE DOS SENSORES AJUSTÁVEL (comando @SENS): cada sensor tem
      um "nível de ruído" (deadband) configurável de 0 até o máximo que o
      ESP32 consegue medir. 0 = máxima sensibilidade (reage a qualquer
      variação); valores maiores ignoram variações pequenas.
      * Solo: 0 a 4095 (ADC 12 bits do ESP32).
      * Umidade do ar (DHT22): 0 a 100%.
      * Temperatura (DHT22): 0 a 100°C.
      * Vazão (YF-S201): 0 a 30 L/min.

  NOVIDADES DA v4.1:
    - Histórico SEM leitura repetida: se a leitura é igual à última gravada,
      NÃO se grava de novo — apenas atualiza a DURAÇÃO (campo "dur") da linha.
      Ex.: se o valor repetiu 2x no período de gravação, vira UMA única linha
      que vale pelos 2 períodos. Cada linha agora termina com a duração em
      segundos até a próxima variação, então o app mostra exatamente quanto
      tempo cada valor permaneceu.
    - Resultado: o mesmo espaço (MAX_HISTORICO linhas) cobre MUITO mais tempo
      (dias/semanas), pois leituras estáveis deixam de encher a memória.
    - LCD com a identificação da horta: linha 1 fixa "Horta EETEPA" e a linha 2
      rodando entre Solo / Ar / Temp / Vazão (a cada 1s) + animação "Regando".
    - @CONFIG com 8 campos: <nome>|<ideal>|<fator>|<margem>|<tempoMax>|
      <intervalo>|<limiteAR>|<umidoAlvo>. Permite ajustar o tempo máximo de
      rega em minutos (0 = automático pelo fator), o intervalo mínimo entre
      regas em minutos (0 = sem intervalo) e a CALIBRAÇÃO do sensor de solo
      (ADC do seco e do úmido) direto pelo app, sem recompilar.

  NOVIDADES DA v4:
    - Sensor de VAZÃO YF-S201 (SEA): mede litros/min e o consumo de água
      (litros por rega, por dia e acumulado), permitindo saber quanto a
      planta realmente consome.
    - Gravação no NVS a cada 15 MINUTOS (+ ao ligar/desligar a rega e ao
      desconectar), sempre em buffer FIFO (grava e apaga como câmera),
      mantendo a memória com folga. O NVS é uma partição SEPARADA do código
      (programa fica nas partições app) — os dados NÃO ocupam o espaço do
      firmware nem bloqueiam futuras atualizações.
    - Margem de rega CONFIGURÁVEL por planta (@CONFIG com 4 campos).
    - Rega automática sem o app conectado: o ESP32 decide sozinho e salva
      tudo no NVS.

  Identificação:
    - O ESP32 anuncia o nome BLE "PEEX" (renomeável com @CONFIG -> "PEEX-<planta>").
    - No app, o filtro "Somente PEEX" mostra apenas dispositivos PEEX.

  Componentes (LIGAÇÃO ELETRÔNICA v4):
    - Sensor de umidade do solo (analógico)           -> D34 (GPIO34, ADC1_CH6)
    - Sensor de temperatura e umidade do ar DHT22     -> D23 (GPIO23)
    - Sensor de vazão YF-S201 (pulso, pull-up)        -> D22 (GPIO22)
    - Relé da válvula solenoide (low-level trigger)   -> D27 (GPIO27)
    - LCD 16x2 com adaptador I2C                      -> SDA D21 (GPIO21), SCL D4 (GPIO4)
    - LED interno do ESP32 (GPIO2)                    -> indicador de conexão (acende ao conectar)

  SOBRE O SENSOR ANALÓGICO:
    No ESP32 clássico o ADC tem DOIS canais: ADC1 (GPIO32 a GPIO39) e ADC2
    (GPIO0/2/4/12-15/25-27). O ADC2 CONFLITA com o rádio (WiFi/BLE). Por isso
    o sensor de solo usa o D34 (ADC1). Se precisar trocar, use D32, D33, D35,
    D36, D37, D38 ou D39.

  SOBRE O RELÉ:
    No ESP32 clássico os pinos D34, D35, D36 e D39 são APENAS de ENTRADA.
    Este módulo de relé é de acionamento por nível BAIXO (low-level trigger);
    o relé só aciona quando o pino está em LOW (RELE_ATIVO_NIVEL = LOW).
    Se o seu relé acionar com HIGH (sintoma: fica SEMPRE ligado quando deveria
    estar desligado), troque o define RELE_ATIVO_NIVEL para HIGH ou use o
    comando @RELE_ATIVO:1 (fica salvo no NVS, sem recompilar).
    Na v4.5 o firmware SEMPRE garante o relé desligado quando não está regando
    (no boot e a cada segundo), usando o nível contrário ao de ligar.

  SOBRE O SENSOR DE VAZÃO (YF-S201):
    - Alimente com 5V. A saída é um pulso (open-collector) a cada passagem
      de água; o firmware usa pull-up interno.
    - Cada 450 pulsos = 1 litro de água (PULSOS_POR_LITRO).
    - Vazão (L/min) = (pulsos em 1s x 60) / 450.

  Comandos recebidos pelo app:
    @TIME:<epochSec>          -> sincroniza o relógio (recebido ao conectar)
    @CONFIG:<nome>|<ideal>|<fator>|<margem>|<tempoMax>|<intervalo>|<limiteAR>|<umidoAlvo>|<regaInicio>|<regaFim> -> configura a planta (10 campos)
    @ML:<0|1>                 -> liga/desliga a rega inteligente (aprendizado de máquina)
    @SENS:<solo>|<ar>|<temp>|<vazao> -> sensibilidade dos sensores (deadband; 0 = máxima)
    @MODO_SENSIVEL:<0|1>   -> liga/desliga o modo sensor sensível (fica salvo)
    @SENSIBILIDADE:<1-100> -> nível de sensibilidade do solo (50 = igual ao normal)
    @ADC                      -> responde a leitura bruta do sensor de solo
    @CAL:DRY                  -> captura a leitura atual como solo SECO
    @CAL:WET                  -> captura a leitura atual como solo ÚMIDO
    @UMIDADE                  -> responde umidade do solo (%)
    @FLUXO                    -> responde vazão (L/min) e consumo acumulado
    @STATUS                   -> responde telemetria completa
    @HISTORY                  -> envia o histórico armazenado
    @BOMBA_ON / @BOMBA_OFF    -> liga/desliga a válvula (teste/manual)
    @AUTO_ON / @AUTO_OFF      -> liga/desliga a rega automática
    @SIGN                     -> responde "@SIGN:PEEX" (assinatura PEEX oficial)
    @VERSION                  -> responde "@VERSION:4.14" (versão do firmware)
    @LOCK:<0|1>               -> trava/libera a rega (1 = nunca ligar, fica salvo)
    @LEITURA:<auto>|<solo>|<ar>|<vazao> -> intervalo de leitura de cada sensor (ms)
    @RELE_ATIVO:<0|1>         -> define se o relé aciona com LOW (0) ou HIGH (1); fica salvo no NVS

  REGA AUTOMÁTICA (v4.6):
    O ESP32 irriga sozinho (padrão LIGADO, estado salvo no NVS): quando a
    umidade do solo fica ABAIXO de regaInicio (padrão 60%) ele liga a
    válvula e desliga quando chega ACIMA de regaFim (padrão 75%) ou o tempo
    máximo (fatorPlanta x 1 minuto, ou tempoMaxRega se configurado). Também
    respeita o intervaloRega (minutos mínimos entre duas regas) e a
    calibração do sensor (limiteAR/umidoAlvo). No v4.5 o início da rega usava
    (umidadeIdeal - margem) que, com margem padrão alta, ficava negativo e
    NUNCA regava sozinho — corrigido com os limites diretos.

  Display LCD 16x2 (v4.1):
    Linha 1: Horta EETEPA       (fixa, identificação da horta)
    Linha 2: iniciando. .. ...  (nos 3 primeiros segundos do boot)
    Linha 2: Solo:45% -> Ar:60% -> Temp:25C -> Vazao:2.50L/m (rotação 1s)
    Linha 2: Regando. .. ...    (enquanto rega - animação de pontos)

  Memória (NVS):
    Partição separada do programa. Armazena histórico FIFO (máx.
    MAX_HISTORICO leituras, apagando as mais antigas — sempre com folga),
    a config da planta, litros acumulados e o estado da rega automática.
    Na v4.1 as leituras repetidas NÃO são gravadas (só a duração é atualizada),
    então as MAX_HISTORICO linhas cobrem um período muito maior.
    Formato de cada linha: epoch,solo,ar,temp,irr,vazao,litros,dur
    onde "dur" = segundos que o valor durou até a próxima variação.

  Dependências (Arduino IDE):
    - "DHT sensor library" (DHTesp) de beegee_tokyo
    - "LiquidCrystal I2C" de Frank de Brabander
*/

#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>
#include <BLE2902.h>
#include <Preferences.h>
#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include <DHTesp.h>

#define SERVICE_UUID     "6e400001-b5a3-f393-e0a9-e50e24dcca9e"
#define CHAR_WRITE_UUID  "6e400002-b5a3-f393-e0a9-e50e24dcca9e"
#define CHAR_NOTIFY_UUID "6e400003-b5a3-f393-e0a9-e50e24dcca9e"

// ---------------- Pinos (ligação eletrônica v4) ----------------
#define PINO_SENSOR  34  // umidade do solo (ADC1_CH6, pino só de entrada; NÃO usar ADC2/D13 com BLE)
#define PINO_DHT     23  // DHT22
#define PINO_FLUXO   22  // sensor de vazão YF-S201 (pulso, pull-up interno)
#define PINO_RELE    13  // relé da válvula (GPIO13: alinhado à ligação física atual)
#define PINO_SDA     21  // LCD I2C SDA (NÃO usar GPIO2: é o LED interno do ESP32)
#define PINO_SCL     4   // LCD I2C SCL
#define PINO_LED     2   // LED interno do ESP32 (indicador de conexão)
#define PINO_BOOT    0   // botão BOOT (reset total: segure 3s)

// Sensor de vazão YF-S201: cada 450 pulsos = 1 litro
#define PULSOS_POR_LITRO 450.0

// Nível que LIGA o relé (v4.5: configurável em tempo de execução).
// Padrão do projeto: módulo de relé "low-level trigger" (liga com LOW).
// Se o seu relé ligar com HIGH (sintoma: fica sempre ligado), troque o
// define abaixo para HIGH ou envie @RELE_ATIVO:1 (fica salvo no NVS).
#define RELE_ATIVO_NIVEL LOW
static bool releAtivoNivel = RELE_ATIVO_NIVEL; // nível que LIGA o relé

// Nível que ACENDE o LED interno. Maioria das placas acende com HIGH;
// se acender invertido (aceso com LOW), troque para LOW.
#define LED_ATIVO_NIVEL HIGH

// Nome BLE padrão: "PEEX" (o app usa o filtro "Somente PEEX")
#define NOME_BLE_PADRAO "PEEX"

// Calibracao do sensor de solo (ADC 12 bits do ESP32: 0-4095).
// Configurável pelo app (@CONFIG), sem precisar recompilar.
int limiteAR    = 2400; // solo totalmente seco (leitura alta)
int umidoAlvo   = 1200; // solo bem umido (leitura baixa)
int margem      = 80;   // histerese da rega (configurável via @CONFIG)

// Config da planta
static String plantaNome = "";
static int umidadeIdeal = 70;
static float fatorPlanta = 1.0;
static float tempoMaxRega = 0;  // minutos; 0 = usa fatorPlanta x 1 min
static int intervaloRega = 0;   // minutos entre regas; 0 = sem intervalo

// Limites DIRETOS da rega (v4.6): o ESP32 LIGA a válvula quando a umidade
// do solo fica ABAIXO de regaInicio e DESLIGA quando fica ACIMA de regaFim.
// Configuráveis pelo app (@CONFIG, campos 9 e 10) e salvos no NVS.
static int regaInicio = 60; // regar quando o solo ficar abaixo de 60%
static int regaFim = 75;    // parar quando o solo chegar a 75%

// ---------------- Leitura por tempo dos sensores (v4.11) ----------------
// Substitui a "sensibilidade" (removida): o app define de quanto em quanto
// tempo cada sensor é lido (50 ms a 3 s). Com "automático" ligado, o
// firmware usa os intervalos ideais de cada sensor (solo 200 ms, DHT ~2 s,
// vazão 200 ms).
int sensSolo  = 0;   // mantido só p/ compatibilidade (deadband); não usado pela UI
int sensAr    = 0;
int sensTemp  = 0;
int sensVazao = 0;

static bool leitAuto = true;       // automático: usa os intervalos ideais
static int intervaloSolo = 200;    // ms
static int intervaloArTemp = 2000; // ms (DHT22 não lê mais rápido com segurança)
static int intervaloVazao = 200;   // ms

// ---------------- Modo sensor sensível (v4.13) ----------------
// Para sensores de umidade do solo MUITO sensíveis (leitura tremida/saturada).
// DESLIGADO = comportamento idêntico à v4.12. LIGADO aplica um fator na
// escala da porcentagem: 50 = igual ao normal, menor = mais estável,
// maior = reage mais forte. Tudo salvo no NVS.
static bool modoSensivel = false; // chave liga/desliga (0 = desligado)
static int  sensNivel    = 50;    // nível de sensibilidade (1-100; 50 = normal)

int intervaloEfetivoSolo()   { return leitAuto ? 200  : intervaloSolo; }
int intervaloEfetivoArTemp() { return leitAuto ? 2000 : intervaloArTemp; }
int intervaloEfetivoVazao()  { return leitAuto ? 200  : intervaloVazao; }

// ---------------- Log de problemas (v4.12) ----------------
// O firmware detecta sozinho situações anormais (relé ligado sem água,
// sensor de solo instável/preso, DHT22 não detectado) e guarda no NVS.
// O app lê com @ERRORS e o relatório mostra.
const int MAX_ERROS = 40;
static String ultimoErroCodigo = "";
static unsigned long ultimoErroMs = 0;

// ---------------- Verificar clima (v4.12) ----------------
// Se o ar está úmido E a temperatura baixa, a chuva é provável: em vez de
// regar na hora, o firmware espera 30 min (ou 15 min à noite/madrugada). Se
// nada acontecer e o solo continuar seco, aí rega. Se chover, cancela.
static bool mlRainAtivo = false;
static bool aguardandoChuva = false;
static unsigned long inicioEsperaChuva = 0;
static unsigned long esperaChuvaMs = 0;
static unsigned long ultimaVerificacaoClima = 0;
#define RAIN_UMID_ALTA 60.0f    // umidade do ar >= 60% = chance de chuva
#define RAIN_TEMP_FRIA 30.0f    // temperatura <= 30°C = "frio"
#define RAIN_ESPERA_DIA 1800000UL   // 30 minutos de dia
#define RAIN_ESPERA_NOITE 900000UL  // 15 minutos à noite/madrugada

// "Noite/madrugada": antes das 6h ou depois das 20h
bool horaNoite() {
  time_t t = agoraEpoch();
  struct tm tm;
  localtime_r(&t, &tm);
  int h = tm.tm_hour;
  return (h < 6 || h >= 20);
}

// Diagnóstico: contagem de saltos grandes do sensor de solo
static int saltosSolo = 0;

// ---------------- Aprendizado de máquina (v4.2) ----------------
static bool mlAtivo = false;
static float mlEficiencia = -1.0f; // %/min aprendida nas últimas regas
static int mlEficN = 0;
static int mlSoloInicio = 0;       // umidade quando a rega começou
static unsigned long mlRegaInicio = 0;
static bool mlAprendendoRega = false;

#define ML_MAX_AMOSTRAS 60
#define ML_MIN_AMOSTRAS 10
#define ML_HORIZONTE 600  // segundos (10 min) de previsão da secagem
static float mlTempos[ML_MAX_AMOSTRAS];
static int mlSolos[ML_MAX_AMOSTRAS];
static int mlQtd = 0;

// Histórico: grava e apaga (FIFO) mantendo sempre abaixo de 80% do NVS
const int MAX_HISTORICO = 100;

static BLECharacteristic *charNotify;
static Preferences prefs;
static LiquidCrystal_I2C *lcd = nullptr;

static bool conectado = false;
static bool bombaLigada = false;
static bool autoRega = true; // o sistema rega sozinho (app só administra/coleta)
static bool regaTravada = false; // v4.9: trava a rega (nem manual, nem automática)
static bool avisarDesconexao = false;

// Reset de fábrica pelo botão BOOT (v4.5/v4.6)
static bool bootBtnSegurando = false;
static unsigned long bootBtnInicio = 0;

// Relógio interno (sincronizado pelo app)
static long offsetSec = 0;
static bool horaOk = false;
static long bootEpoch = 0; // época do boot (para não unir leituras de ligações antigas)

// Controle da rega
static unsigned long irrInicio = 0;
static unsigned long ultimaRegaFim = 0;
static int irrigacoesHoje = 0;
static String dataHoje = "";

// DHT
DHTesp dht;
static float ultimaTemp = NAN;
static float ultimaUmidAr = NAN;

// ---------------- Sensor de vazão (YF-S201) ----------------
static volatile unsigned long pulsosFluxo = 0;
static unsigned long pulsosUltimaLeitura = 0;
static float vazaoLmin = 0;    // litros por minuto (taxa atual)
static float litrosRega = 0;   // litros consumidos na rega atual
static float litrosHoje = 0;   // litros consumidos hoje
static float litrosTotal = 0;  // litros acumulados (persistido no NVS)

IRAM_ATTR void contarPulso() {
  pulsosFluxo++;
}

static float vazaoFiltrada = 0;
static unsigned long pulsosTempoUltimo = 0;
void atualizarFluxo() {
  unsigned long agora = millis();
  float dt = (agora - pulsosTempoUltimo) / 1000.0f; // segundos decorridos
  pulsosTempoUltimo = agora;
  unsigned long delta = pulsosFluxo - pulsosUltimaLeitura;
  pulsosUltimaLeitura = pulsosFluxo;
  float nova = (dt > 0.001f) ? (delta * 60.0f) / (PULSOS_POR_LITRO * dt) : 0.0f;
  // Filtro de sensibilidade (v4.2): deadband na vazão exibida
  if (sensVazao == 0 || fabsf(nova - vazaoFiltrada) >= sensVazao) {
    vazaoFiltrada = nova;
  }
  vazaoLmin = vazaoFiltrada;
  if (bombaLigada) {
    litrosRega += delta / PULSOS_POR_LITRO;
  }
}

// ---------------- Aprendizado de máquina (v4.2) ----------------
void mlResetAmostras() { mlQtd = 0; }

void mlAmostrar(float t, int solo) {
  if (mlQtd == ML_MAX_AMOSTRAS) {
    memmove(&mlTempos[0], &mlTempos[1], (ML_MAX_AMOSTRAS - 1) * sizeof(float));
    memmove(&mlSolos[0], &mlSolos[1], (ML_MAX_AMOSTRAS - 1) * sizeof(int));
    mlQtd = ML_MAX_AMOSTRAS - 1;
  }
  mlTempos[mlQtd] = t;
  mlSolos[mlQtd] = solo;
  mlQtd++;
}

// Regressão linear (mínimos quadrados) dos últimos pontos:
// x = tempo (segundos), y = umidade do solo (%). Retorna inclinação e intercepto.
bool mlRegressao(float &slope, float &intercept) {
  if (mlQtd < ML_MIN_AMOSTRAS) return false;
  float sumX = 0, sumY = 0, sumXY = 0, sumXX = 0;
  for (int i = 0; i < mlQtd; i++) {
    sumX += mlTempos[i];
    sumY += mlSolos[i];
    sumXY += mlTempos[i] * mlSolos[i];
    sumXX += mlTempos[i] * mlTempos[i];
  }
  float n = mlQtd;
  float denom = n * sumXX - sumX * sumX;
  if (fabsf(denom) < 1e-6f) return false;
  slope = (n * sumXY - sumX * sumY) / denom;
  intercept = (sumY - slope * sumX) / n;
  return true;
}

// Preve em quantos segundos o solo atinge o limite de rega (0 = não prevê).
long mlPreverSecagem() {
  float m, b;
  if (!mlRegressao(m, b)) return 0;
  if (m >= -0.01f) return 0; // não está secando
  float alvo = regaInicio; // v4.6: limite direto de início da rega
  long agora = millis() / 1000;
  float t = (alvo - b) / m; // m negativo -> tempo futuro em que y == alvo
  long dt = (long)(t - agora);
  if (dt <= 0 || dt > ML_HORIZONTE) return 0;
  return dt;
}

// Aprende a eficiência da rega (% de subida do solo por minuto).
void mlAprenderRega() {
  if (!mlAprendendoRega || !mlAtivo) {
    mlAprendendoRega = false;
    return;
  }
  mlAprendendoRega = false;
  unsigned long durMs = millis() - mlRegaInicio;
  int soloFim = calcularUmidadeSolo();
  int delta = soloFim - mlSoloInicio;
  float durMin = durMs / 60000.0f;
  if (delta > 2 && durMin > 0.2f) {
    float ef = delta / durMin; // %/min
    if (mlEficN == 0) {
      mlEficiencia = ef;
    } else {
      mlEficiencia = 0.7f * mlEficiencia + 0.3f * ef; // média móvel
    }
    mlEficN++;
    prefs.putFloat("mlEff", mlEficiencia);
  }
}

// ---------------- Relógio ----------------
long agoraEpoch() {
  return offsetSec + (millis() / 1000);
}

String dataAtual() {
  time_t t = agoraEpoch();
  struct tm tm;
  localtime_r(&t, &tm);
  char buf[12];
  snprintf(buf, sizeof(buf), "%04d-%02d-%02d",
           tm.tm_year + 1900, tm.tm_mon + 1, tm.tm_mday);
  return String(buf);
}

// ---------------- Sensores ----------------
static int ultimoRawSolo = -1;
static int suavizadoSolo = -1; // média móvel da umidade (para reset na calibração)
static unsigned long ultimoCalcSolo = 0; // v4.11: intervalo de leitura do solo

// v4.11: respeita o intervalo de leitura configurado (ou automático).
int lerSoloCache() {
  unsigned long agora = millis();
  if (ultimoRawSolo >= 0 && (agora - ultimoCalcSolo) < (unsigned long)intervaloEfetivoSolo()) {
    return ultimoRawSolo;
  }
  ultimoCalcSolo = agora;
  return lerSolo();
}

// v4.10 - AUTO-RANGE: faixa de ADC observada do sensor. Com isso o firmware
// aceita QUALQUER tipo de sensor de umidade sem calibração: ele aprende os
// valores mínimo (mais "molhado") e máximo (mais "seco") que o sensor já
// entregou e mapeia 0-100% automaticamente.
static int autoAdcMin = -1;
static int autoAdcMax = -1;

void atualizarAutoRange(int raw) {
  if (autoAdcMin < 0) {
    autoAdcMin = raw;
    autoAdcMax = raw;
    return;
  }
  if (raw < autoAdcMin - 4) autoAdcMin = raw; // pequeno delta evita ruído
  if (raw > autoAdcMax + 4) autoAdcMax = raw;
}

int lerSolo() {
  long soma = 0;
  for (int i = 0; i < 20; i++) { // média de 20 amostras (reduz ruído)
    soma += analogRead(PINO_SENSOR);
    delay(1);
  }
  int raw = soma / 20;
  // v4.12: detecta leituras instáveis (saltos grandes seguidos = sensor "maluco")
  static int rawAnterior = -1;
  if (rawAnterior >= 0 && abs(raw - rawAnterior) > 900) {
    saltosSolo++;
  } else if (saltosSolo > 0) {
    saltosSolo--;
  }
  rawAnterior = raw;
  // Filtro de sensibilidade (v4.2): variações abaixo do deadband são ignoradas
  if (ultimoRawSolo >= 0 && abs(raw - ultimoRawSolo) < sensSolo) {
    raw = ultimoRawSolo;
  }
  ultimoRawSolo = raw;
  return raw;
}

int calcularUmidadeSolo() {
  int leitura = lerSoloCache();
  atualizarAutoRange(leitura);
  // v4.3: mapeamento robusto que detecta a ORIENTAÇÃO do sensor.
  //   - Sensor normal: seco lê ALTO, úmido lê BAIXO  -> umidoAlvo < limiteAR
  //   - Sensor invertido: seco lê BAIXO, úmido lê ALTO -> umidoAlvo > limiteAR
  int seco = limiteAR;   // referência do solo seco
  int umido = umidoAlvo; // referência do solo úmido
  // v4.10 - AUTO-RANGE: se a calibração manual não existe ou é degenerada
  // (seco == úmido), usa a faixa observada do sensor. Assim qualquer sensor
  // já começa lendo 0-100% sem apertar botão. A orientação segue a da
  // calibração manual; sem calibração, assume "seco = ADC alto" (o mais comum)
  // e é corrigida assim que o app enviar uma calibração.
  bool calibracaoValida = (abs(limiteAR - umidoAlvo) > 50);
  if (!calibracaoValida && autoAdcMax > autoAdcMin) {
    if (umido > seco) {
      // Invertido: seco = ADC baixo, úmido = ADC alto
      seco = autoAdcMin;
      umido = autoAdcMax;
    } else {
      // Normal: seco = ADC alto, úmido = ADC baixo
      seco = autoAdcMax;
      umido = autoAdcMin;
    }
  }
  int pct;
  if (umido > seco) {
    // Sensor invertido: seco = baixo, úmido = alto
    if (leitura <= seco) pct = 0;
    else if (leitura >= umido) pct = 100;
    else pct = (int)((leitura - seco) * 100.0f / (umido - seco));
  } else {
    // Sensor normal: seco = alto, úmido = baixo
    if (seco == umido) { umido = seco - 1; }
    if (leitura >= seco) pct = 0;
    else if (leitura <= umido) pct = 100;
    else pct = (int)((seco - leitura) * 100.0f / (seco - umido));
  }
  // Suavização (média móvel): evita leituras pulando de um valor para outro
  if (suavizadoSolo < 0) suavizadoSolo = pct;
  suavizadoSolo = (suavizadoSolo * 3 + pct) / 4;
  // v4.13 - MODO SENSOR SENSÍVEL: aplica o nível de sensibilidade na escala
  // da porcentagem. 50 = igual ao normal; menor = leitura mais estável
  // (sensor muito sensível para de tremer); maior = reação mais forte.
  if (modoSensivel) {
    float fator = sensNivel / 50.0f;
    int desvio = suavizadoSolo - 50;
    int ajustado = (int)(50 + desvio * fator);
    if (ajustado < 0) ajustado = 0;
    if (ajustado > 100) ajustado = 100;
    return ajustado;
  }
  return suavizadoSolo;
}

// Leitura do DHT22 com o intervalo configurado (mínimo real ~2 s, mas o app
// pode pedir 1 s; leituras muito rápidas só mantêm o último valor válido)
void atualizarDHT() {
  static unsigned long ultimaLeitura = 0;
  if (millis() - ultimaLeitura >= (unsigned long)intervaloEfetivoArTemp()) {
    ultimaLeitura = millis();
    TempAndHumidity th = dht.getTempAndHumidity();
    // Filtro de sensibilidade (v4.2): só atualiza se variar >= deadband
    if (!isnan(th.temperature)) {
      if (sensTemp == 0 || isnan(ultimaTemp) ||
          fabsf(th.temperature - ultimaTemp) >= sensTemp) {
        ultimaTemp = th.temperature;
      }
    }
    if (!isnan(th.humidity)) {
      if (sensAr == 0 || isnan(ultimaUmidAr) ||
          fabsf(th.humidity - ultimaUmidAr) >= sensAr) {
        ultimaUmidAr = th.humidity;
      }
    }
  }
}

float lerTemperatura() { return ultimaTemp; }
float lerUmidadeAr() { return ultimaUmidAr; }

// ---------------- LCD 16x2 (v4.1) ----------------
static unsigned long bootInicio = 0; // instante do boot (animação "iniciando")

// ---------------- Espera de boot (v4.14) ----------------
// Ao ligar, o ESP32 espera 1 minuto sem fazer nada (só anuncia o Bluetooth).
// Se o app conectar nesse tempo, a espera é cancelada na hora (onConnect).
// Depois de 60s sem ninguém conectar, o firmware volta a trabalhar sozinho.
static const unsigned long ESPERA_BOOT_MS = 60000UL; // 1 minuto
static bool aguardandoBoot = true;

uint8_t detectarEnderecoLCD() {
  for (uint8_t addr = 0x03; addr <= 0x77; addr++) {
    Wire.beginTransmission(addr);
    if (Wire.endTransmission() == 0) {
      Serial.printf("LCD I2C encontrado no endereco 0x%02X\r\n", addr);
      return addr;
    }
  }
  Serial.println("LCD I2C nao encontrado (usando 0x27)");
  return 0x27;
}

void iniciarLCD() {
  Wire.begin(PINO_SDA, PINO_SCL);
  lcd = new LiquidCrystal_I2C(detectarEnderecoLCD(), 16, 2);
  lcd->init();
  lcd->backlight();
  lcd->clear();
  // Linha 1 é FIXA: identificação da horta (16 colunas)
  lcd->setCursor(0, 0);
  lcd->print("Horta EETEPA");
  lcd->setCursor(0, 1);
  lcd->print("iniciando...");
}

// Monta a animação de pontos: "iniciando." / "iniciando.." / "iniciando..."
void montarAnimacao(char destino[17], const char* texto, unsigned long agora) {
  int pontos = ((agora / 400) % 3) + 1;
  char anim[4] = {'.', '.', '.', '\0'};
  anim[pontos] = '\0';
  snprintf(destino, 17, "%s%s", texto, anim);
}

void atualizarLCD(unsigned long agora) {
  if (lcd == nullptr) return;

  int solo = calcularUmidadeSolo();
  int ar = isnan(ultimaUmidAr) ? -1 : (int)ultimaUmidAr;
  int temp = isnan(ultimaTemp) ? -999 : (int)ultimaTemp;

  char linha2[17];

  if (agora - bootInicio < 3000) {
    // Nos 3 primeiros segundos do boot, mostra "iniciando..." (animação)
    montarAnimacao(linha2, "iniciando", agora);
  } else if (aguardandoBoot) {
    // v4.14: espera de boot — contagem regressiva até liberar sozinho
    unsigned long decorrido = agora - bootInicio;
    int resta = (decorrido >= ESPERA_BOOT_MS)
        ? 0
        : (int)((ESPERA_BOOT_MS - decorrido + 999) / 1000);
    snprintf(linha2, sizeof(linha2), "Espera app:%3ds ", resta);
  } else if (bombaLigada) {
    // Rega: animação "Regando." / "Regando.." / "Regando..."
    montarAnimacao(linha2, "Regando", agora);
  } else {
    // Rotação a cada 1s: Solo -> Ar -> Temp -> Vazao
    static unsigned long ultimaTroca = 0;
    static int estado = 0;
    if (agora - ultimaTroca >= 1000) {
      ultimaTroca = agora;
      estado = (estado + 1) % 4;
    }
    switch (estado) {
      case 0:
        snprintf(linha2, sizeof(linha2), "Solo:%d%%        ", solo);
        break;
      case 1:
        if (ar >= 0) {
          snprintf(linha2, sizeof(linha2), "Ar:%d%%          ", ar);
        } else {
          snprintf(linha2, sizeof(linha2), "Ar: --          ");
        }
        break;
      case 2:
        if (temp > -100) {
          snprintf(linha2, sizeof(linha2), "Temp:%dC         ", temp);
        } else {
          snprintf(linha2, sizeof(linha2), "Temp: --         ");
        }
        break;
      default:
        snprintf(linha2, sizeof(linha2), "Vazao:%.2fL/m    ", vazaoLmin);
        break;
    }
  }

  // escreve apenas se a linha 2 mudou (evita cintilacao)
  static char ultLinha2[17] = "";
  if (strcmp(ultLinha2, linha2) != 0) {
    lcd->setCursor(0, 1);
    lcd->print(linha2);
    strcpy(ultLinha2, linha2);
  }
}

// ---------------- Memória (NVS - FIFO) ----------------
// Retorna o campo "idx" de uma linha separada por vírgulas
String campo(const String& s, int idx) {
  int inicio = 0;
  int i = 0;
  while (true) {
    int fim = s.indexOf(',', inicio);
    if (i == idx) {
      return (fim < 0) ? s.substring(inicio) : s.substring(inicio, fim);
    }
    if (fim < 0) return "";
    inicio = fim + 1;
    i++;
  }
}

// v4.1: NÃO grava leitura repetida. Se a leitura é igual à última gravada,
// apenas atualiza a DURAÇÃO ("dur", em segundos) daquela linha. Assim cada
// linha vale pelo período em que o valor não mudou — liberando espaço no NVS
// e permitindo ao app mostrar quanto tempo até a próxima variação.
void salvarHistorico() {
  long agora = agoraEpoch();
  char corpo[40];
  snprintf(corpo, sizeof(corpo), "%d,%d,%d,%d,%.2f,%.2f",
           calcularUmidadeSolo(), (int)lerUmidadeAr(),
           (int)lerTemperatura(), irrigacoesHoje, vazaoLmin, litrosHoje);

  String hist = prefs.getString("hist", "");
  int ultNovaLinha = hist.lastIndexOf('\n');
  // O histórico sempre termina com '\n'. A ÚLTIMA LINHA fica entre o penúltimo
  // e o último '\n'. Sem o ajuste abaixo, substring(ultNovaLinha+1) devolve
  // vazio e o firmware nunca reconhece a leitura repetida — gravando de novo
  // a cada 15 min (v4.5: corrigido).
  if (ultNovaLinha == (int)hist.length() - 1 && hist.length() > 1) {
    ultNovaLinha = hist.lastIndexOf('\n', hist.length() - 2);
  }

  long epochUlt = 0;
  String corpoAnt = "";
  bool haUltima = false;
  if (ultNovaLinha >= 0) {
    String ultLinha = hist.substring(ultNovaLinha + 1);
    ultLinha.trim();
    if (ultLinha.length() > 0) {
      epochUlt = campo(ultLinha, 0).toInt();
      if (epochUlt > 0) {
        haUltima = true;
        char buf[40];
        snprintf(buf, sizeof(buf), "%d,%d,%d,%d,%.2f,%.2f",
                 campo(ultLinha, 1).toInt(), campo(ultLinha, 2).toInt(),
                 campo(ultLinha, 3).toInt(), campo(ultLinha, 4).toInt(),
                 campo(ultLinha, 5).toFloat(), campo(ultLinha, 6).toFloat());
        corpoAnt = String(buf);
      }
    }
  }

  // Só une leituras desta mesma ligação (não mistura com ligações antigas)
  bool aposBoot = epochUlt >= bootEpoch;
  bool mesmaLeitura = haUltima && aposBoot && (corpoAnt == String(corpo));

  if (mesmaLeitura) {
    // Leitura repetida: não grava de novo — só atualiza a DURAÇÃO da linha
    long dur = agora - epochUlt;
    if (dur < 0) dur = 0;
    if (dur > 604800) dur = 604800; // trava em 7 dias por segurança
    char linha[56];
    snprintf(linha, sizeof(linha), "%ld,%s,%ld", epochUlt, corpo, dur);
    hist = hist.substring(0, ultNovaLinha + 1) + String(linha) + "\n";
    prefs.putString("hist", hist);
    return;
  }

  // Leitura mudou: fecha a duração da linha anterior e abre uma nova (dur = 0)
  if (haUltima && aposBoot) {
    long dur = agora - epochUlt;
    if (dur < 0) dur = 0;
    if (dur > 604800) dur = 604800;
    char linha[56];
    snprintf(linha, sizeof(linha), "%ld,%s,%ld", epochUlt, corpoAnt.c_str(), dur);
    hist = hist.substring(0, ultNovaLinha + 1) + String(linha) + "\n";
  }
  char nova[56];
  snprintf(nova, sizeof(nova), "%ld,%s,0", agora, corpo);
  hist += String(nova) + "\n";

  // Mantém apenas MAX_HISTORICO linhas (apaga as mais antigas)
  int primeiroNovaLinha = 0;
  int linhas = 0;
  for (int i = 0; i < hist.length(); i++) {
    if (hist[i] == '\n') {
      linhas++;
      if (linhas > MAX_HISTORICO) {
        primeiroNovaLinha = i + 1;
      }
    }
  }
  if (primeiroNovaLinha > 0) {
    hist = hist.substring(primeiroNovaLinha);
  }
  prefs.putString("hist", hist);
}

String lerHistorico() {
  return prefs.getString("hist", "");
}

// ---------------- Log de problemas (v4.12) ----------------
// Registra um problema no NVS (FIFO). Mesmo tipo de erro no máx. 1x/2min
// para não encher o log com o mesmo aviso repetido.
void registrarErro(const String& codigo, const String& msg) {
  if (codigo == ultimoErroCodigo && (millis() - ultimoErroMs) < 120000) return;
  ultimoErroCodigo = codigo;
  ultimoErroMs = millis();
  long agora = agoraEpoch();
  String errs = prefs.getString("errs", "");
  errs += String(agora) + "," + codigo + "," + msg + "\n";
  int p = 0, linhas = 0;
  for (int i = 0; i < errs.length(); i++) {
    if (errs[i] == '\n') {
      linhas++;
      if (linhas > MAX_ERROS) p = i + 1;
    }
  }
  if (p > 0) errs = errs.substring(p);
  prefs.putString("errs", errs);
  Serial.printf("PROBLEMA [%s]: %s\r\n", codigo.c_str(), msg.c_str());
}

String lerErros() {
  return prefs.getString("errs", "");
}

// ---------------- Verificar clima (v4.12) ----------------
// Checa a cada 30s se o tempo indica chuva (ar úmido + temperatura baixa).
// Se sim e o solo está seco, entra em "espera de chuva": 30 min de dia,
// 15 min à noite/madrugada. Ao fim da espera, se o solo continua seco,
// rega (nada aconteceu). Se o solo ficou úmido, foi chuva — cancela.
void verificarClimaEAgua() {
  if (!mlRainAtivo || regaTravada || bombaLigada) {
    aguardandoChuva = false;
    return;
  }
  unsigned long agora = millis();
  if (agora - ultimaVerificacaoClima < 30000) return;
  ultimaVerificacaoClima = agora;

  int solo = calcularUmidadeSolo();
  bool seco = solo < regaInicio;
  bool provavelChuva = !isnan(ultimaUmidAr) && !isnan(ultimaTemp) &&
                       ultimaUmidAr >= RAIN_UMID_ALTA &&
                       ultimaTemp <= RAIN_TEMP_FRIA;

  if (aguardandoChuva) {
    if (!seco) {
      aguardandoChuva = false; // choveu, o solo ficou úmido
      enviar("@RAIN:CHOVEU");
    } else if (agora - inicioEsperaChuva >= esperaChuvaMs) {
      aguardandoChuva = false;
      enviar("@RAIN:REGANDO");
      ligarRele(); // nada aconteceu e o solo continua seco -> rega
    }
  } else if (provavelChuva && seco) {
    aguardandoChuva = true;
    inicioEsperaChuva = agora;
    esperaChuvaMs = horaNoite() ? RAIN_ESPERA_NOITE : RAIN_ESPERA_DIA;
    enviar("@RAIN:ESPERANDO");
  }
}

// ---------------- Notificação ----------------
void enviar(const String& texto) {
  if (charNotify != nullptr && conectado) {
    charNotify->setValue((uint8_t*)texto.c_str(), texto.length());
    charNotify->notify();
  }
}

void enviarTelemetria() {
  // v4.6: NUNCA envia valor inválido para o ar/temperatura (o cast de NaN
  // para int vira um número absurdo que quebra os gráficos do app). Quando
  // o DHT22 falha, envia -1 (ar) e -999 (temperatura) para o app ignorar.
  int ar = isnan(ultimaUmidAr) ? -1 : (int)ultimaUmidAr;
  int temp = isnan(ultimaTemp) ? -999 : (int)ultimaTemp;
  char buf[96];
  snprintf(buf, sizeof(buf), "@DATA:%ld,%d,%d,%d,%d,%.2f,%.2f,%d",
           (long)agoraEpoch(), calcularUmidadeSolo(),
           ar, temp, irrigacoesHoje,
           vazaoLmin, litrosHoje, ultimoRawSolo);
  enviar(String(buf));
}

void ligarRele() {
  if (bombaLigada) return;
  if (regaTravada) { // v4.9: trava de segurança — nunca liga a rega
    enviar("@BOMBA:BLOQUEADA");
    Serial.println("Rega bloqueada (trava ativa)");
    return;
  }
  digitalWrite(PINO_RELE, releAtivoNivel);
  bombaLigada = true;
  irrInicio = millis();
  litrosRega = 0; // zera a contagem de litros desta rega
  irrigacoesHoje++;
  // ML (v4.2): marca o início da rega para aprender a eficiência
  mlSoloInicio = calcularUmidadeSolo();
  mlRegaInicio = millis();
  mlAprendendoRega = true;
  mlResetAmostras(); // zera o histórico de secagem (rega nova)
  enviar("@BOMBA:LIGADA");
  Serial.println("Rega iniciada");
}

void desligarRele() {
  if (!bombaLigada) return;
  digitalWrite(PINO_RELE, !releAtivoNivel);
  bombaLigada = false;
  ultimaRegaFim = millis(); // para o intervalo mínimo entre regas
  mlAprenderRega(); // ML (v4.2): aprende a eficiência desta rega
  // Consolida o consumo desta rega
  litrosHoje += litrosRega;
  litrosTotal += litrosRega;
  prefs.putFloat("lHoje", litrosHoje);
  prefs.putFloat("lTotal", litrosTotal);
  salvarHistorico(); // registra o fim da rega
  enviar("@BOMBA:DESLIGADA");
  Serial.printf("Rega finalizada (+%.2f L, hoje %.2f L)\r\n", litrosRega, litrosHoje);
}

// Renomeia o BLE mantendo o prefixo "PEEX" para identificação no app
void renomearBLE(String nome) {
  String adv = nome.length() > 0 ? ("PEEX-" + nome) : String(NOME_BLE_PADRAO);
  if (adv.length() > 20) adv = adv.substring(0, 20);
  BLEDevice::getAdvertising()->stop();
  esp_ble_gap_set_device_name(adv.c_str());
  BLEDevice::getAdvertising()->start();
  Serial.println("Nome BLE: " + adv);
}

// ---------------- Callbacks ----------------
class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* server) {
    conectado = true;
    if (aguardandoBoot) {
      // v4.14: o app chegou dentro da espera de boot — libera na hora
      aguardandoBoot = false;
      Serial.println("App conectou durante a espera de boot: liberado!");
    }
    digitalWrite(PINO_LED, LED_ATIVO_NIVEL); // LED acende ao conectar
    Serial.println("Cliente conectado");
  }
  void onDisconnect(BLEServer* server) {
    conectado = false;
    digitalWrite(PINO_LED, !LED_ATIVO_NIVEL); // LED apaga ao desconectar
    avisarDesconexao = true;
    Serial.println("Cliente desconectado");
  }
};

class CharCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* characteristic) {
    String valor = characteristic->getValue();
    if (valor.length() == 0) return;

    String comando = String(valor.c_str());
    comando.trim();
    Serial.print("Comando: ");
    Serial.println(comando);

    if (comando.startsWith("@TIME:")) {
      String epochStr = comando.substring(6);
      long epoch = atol(epochStr.c_str());
      offsetSec = epoch - (millis() / 1000);
      horaOk = true;
      dataHoje = dataAtual();
      prefs.putLong("offset", offsetSec);
      prefs.putString("data", dataHoje);
      irrigacoesHoje = 0; // reseta regas do dia ao sincronizar o relógio
      prefs.putInt("irr", irrigacoesHoje);
      enviar("@TIME:OK");
    } else if (comando.startsWith("@CONFIG:")) {
      String cfg = comando.substring(8);
      int p1 = cfg.indexOf('|');
      int p2 = cfg.indexOf('|', p1 + 1);
      int p3 = cfg.indexOf('|', p2 + 1);
      int p4 = cfg.indexOf('|', p3 + 1);
      int p5 = cfg.indexOf('|', p4 + 1);
      int p6 = cfg.indexOf('|', p5 + 1);
      int p7 = cfg.indexOf('|', p6 + 1);
      int p8 = cfg.indexOf('|', p7 + 1);
      int p9 = cfg.indexOf('|', p8 + 1);
      if (p1 > 0 && p2 > p1) {
        plantaNome = cfg.substring(0, p1);
        umidadeIdeal = cfg.substring(p1 + 1, p2).toInt();
        fatorPlanta = cfg.substring(p2 + 1, p3 > p2 ? p3 : cfg.length()).toFloat();
        if (p3 > p2) margem = cfg.substring(p3 + 1, p4 > p3 ? p4 : cfg.length()).toInt();
        if (p4 > p3) tempoMaxRega = cfg.substring(p4 + 1, p5 > p4 ? p5 : cfg.length()).toFloat();
        if (p5 > p4) intervaloRega = cfg.substring(p5 + 1, p6 > p5 ? p6 : cfg.length()).toInt();
        if (p6 > p5) limiteAR = cfg.substring(p6 + 1, p7 > p6 ? p7 : cfg.length()).toInt();
        if (p7 > p6) umidoAlvo = cfg.substring(p7 + 1, p8 > p7 ? p8 : cfg.length()).toInt();
        // v4.6: limites diretos da rega (campos 9 e 10). Se não vierem (app
        // antigo), mantém o valor atual/padrão.
        if (p8 > p7) regaInicio = cfg.substring(p8 + 1, p9 > p8 ? p9 : cfg.length()).toInt();
        if (p9 > p8) regaFim = cfg.substring(p9 + 1).toInt();
        // Limites de segurança
        if (margem < 5) margem = 5;
        if (margem > 95) margem = 95;
        if (tempoMaxRega < 0) tempoMaxRega = 0;
        if (tempoMaxRega > 60) tempoMaxRega = 60;
        if (intervaloRega < 0) intervaloRega = 0;
        if (intervaloRega > 120) intervaloRega = 120;
        if (limiteAR < 0) limiteAR = 0;
        if (limiteAR > 4095) limiteAR = 4095;
        if (umidoAlvo < 0) umidoAlvo = 0;
        if (umidoAlvo > 4095) umidoAlvo = 4095;
        // v4.6: garante limites diretos coerentes (regar antes de desligar)
        if (regaInicio < 5) regaInicio = 5;
        if (regaInicio > 90) regaInicio = 90;
        if (regaFim < 10) regaFim = 10;
        if (regaFim > 100) regaFim = 100;
        if (regaFim <= regaInicio) regaFim = regaInicio + 5;
        if (regaFim > 100) { regaFim = 100; regaInicio = 90; }
        prefs.putString("nome", plantaNome);
        prefs.putInt("um_ideal", umidadeIdeal);
        prefs.putFloat("fator", fatorPlanta);
        prefs.putInt("margem", margem);
        prefs.putFloat("tmax", tempoMaxRega);
        prefs.putInt("irega", intervaloRega);
        prefs.putInt("lar", limiteAR);
        prefs.putInt("ualvo", umidoAlvo);
        prefs.putInt("rInicio", regaInicio);
        prefs.putInt("rFim", regaFim);
        renomearBLE(plantaNome);
        enviar("@CONFIG:OK " + plantaNome);
      }
    } else if (comando == "@FLUXO") {
      char buf[48];
      snprintf(buf, sizeof(buf), "@FLUXO:%.2f,%.2f,%.2f",
               vazaoLmin, litrosHoje, litrosTotal);
      enviar(String(buf));
    } else if (comando == "@UMIDADE") {
      char buf[16];
      snprintf(buf, sizeof(buf), "@UMIDADE:%d%%", calcularUmidadeSolo());
      enviar(String(buf));
    } else if (comando == "@ADC") {
      char buf[16];
      snprintf(buf, sizeof(buf), "@ADC:%d", lerSolo());
      enviar(String(buf));
    } else if (comando.startsWith("@CAL:")) {
      String qual = comando.substring(5);
      qual.trim();
      int atual = lerSolo();
      if (qual == "DRY" || qual == "SECO") {
        limiteAR = atual; // referência exata do solo seco atual
        if (limiteAR < 0) limiteAR = 0;
        if (limiteAR > 4095) limiteAR = 4095;
        prefs.putInt("lar", limiteAR);
        suavizadoSolo = -1; // reset da média móvel para ver na hora
        char buf[24];
        snprintf(buf, sizeof(buf), "@CAL:DRY:%d", limiteAR);
        enviar(String(buf));
        Serial.printf("Calibrado SOLO SECO = %d\r\n", limiteAR);
      } else if (qual == "WET" || qual == "UMIDO") {
        umidoAlvo = atual; // referência exata do solo úmido atual
        if (umidoAlvo < 0) umidoAlvo = 0;
        if (umidoAlvo > 4095) umidoAlvo = 4095;
        prefs.putInt("ualvo", umidoAlvo);
        suavizadoSolo = -1; // reset da média móvel para ver na hora
        char buf[24];
        snprintf(buf, sizeof(buf), "@CAL:WET:%d", umidoAlvo);
        enviar(String(buf));
        Serial.printf("Calibrado SOLO UMIDO = %d\r\n", umidoAlvo);
      } else {
        enviar("@ERRO:CAL_DESCONHECIDO");
      }
    } else if (comando == "@STATUS") {
      enviarTelemetria();
      enviar("@LOCK:" + String(regaTravada ? 1 : 0));
      enviar("@LEITURA:" + String(leitAuto ? 1 : 0) + "|" +
             String(intervaloSolo) + "|" + String(intervaloArTemp) + "|" +
             String(intervaloVazao));
      enviar("@ML_RAIN:" + String(mlRainAtivo ? 1 : 0));
      enviar("@MODO_SENSIVEL:" + String(modoSensivel ? 1 : 0) + "|" +
             String(sensNivel));
    } else if (comando == "@ERRORS") {
      enviar(lerErros());
      enviar("@ERR_END");
    } else if (comando == "@ERRLIMPAR") {
      prefs.putString("errs", "");
      enviar("@ERR:OK");
    } else if (comando == "@HISTORY") {
      enviar(lerHistorico());
      enviar("@HIST_END");
    } else if (comando == "@BOMBA_ON") {
      ligarRele();
    } else if (comando == "@BOMBA_OFF") {
      desligarRele();
    } else if (comando == "@AUTO_ON") {
      autoRega = true;
      prefs.putBool("auto", autoRega);
      enviar("@AUTO:ON");
    } else if (comando == "@AUTO_OFF") {
      autoRega = false;
      prefs.putBool("auto", autoRega);
      desligarRele();
      enviar("@AUTO:OFF");
    } else if (comando.startsWith("@ML:")) {
      String v = comando.substring(4);
      v.trim();
      mlAtivo = (v == "1" || v == "ON" || v == "on" || v == "true");
      prefs.putBool("ml", mlAtivo);
      if (!mlAtivo) mlResetAmostras();
      enviar(mlAtivo ? "@ML:ON" : "@ML:OFF");
      Serial.printf("Rega inteligente (ML): %s\r\n", mlAtivo ? "LIGADA" : "desligada");
    } else if (comando.startsWith("@ML_RAIN:")) {
      // v4.12: Verificar clima. 1 = espera chuva (30 min dia / 15 min noite)
      String v = comando.substring(9);
      v.trim();
      mlRainAtivo = (v == "1" || v == "ON" || v == "on" || v == "true");
      prefs.putBool("mlRain", mlRainAtivo);
      if (!mlRainAtivo) aguardandoChuva = false;
      enviar(mlRainAtivo ? "@ML_RAIN:ON" : "@ML_RAIN:OFF");
      Serial.printf("Verificar clima: %s\r\n", mlRainAtivo ? "LIGADO" : "desligado");
    } else if (comando.startsWith("@SENS:")) {
      String cfg = comando.substring(6);
      int p1 = cfg.indexOf('|');
      int p2 = cfg.indexOf('|', p1 + 1);
      int p3 = cfg.indexOf('|', p2 + 1);
      int solo = cfg.substring(0, p1 > 0 ? p1 : cfg.length()).toInt();
      int ar = cfg.substring(p1 + 1, p2 > p1 ? p2 : cfg.length()).toInt();
      int temp = cfg.substring(p2 + 1, p3 > p2 ? p3 : cfg.length()).toInt();
      int vaz = cfg.substring(p3 + 1).toInt();
      if (solo < 0) solo = 0;
      if (solo > 4095) solo = 4095;
      if (ar < 0) ar = 0;
      if (ar > 100) ar = 100;
      if (temp < 0) temp = 0;
      if (temp > 100) temp = 100;
      if (vaz < 0) vaz = 0;
      if (vaz > 30) vaz = 30;
      sensSolo = solo;
      sensAr = ar;
      sensTemp = temp;
      sensVazao = vaz;
      prefs.putInt("sensSolo", sensSolo);
      prefs.putInt("sensAr", sensAr);
      prefs.putInt("sensTemp", sensTemp);
      prefs.putInt("sensVazao", sensVazao);
      enviar("@SENS:OK");
      Serial.printf("Sensibilidade: solo=%d ar=%d temp=%d vazao=%d\r\n",
                    sensSolo, sensAr, sensTemp, sensVazao);
    } else if (comando.startsWith("@MODO_SENSIVEL:")) {
      // v4.13: modo sensor sensível. 1 = ligado; 0 = desligado (v4.12).
      String v = comando.substring(15);
      v.trim();
      modoSensivel = (v == "1" || v == "ON" || v == "on" || v == "true");
      prefs.putBool("sensivel", modoSensivel);
      enviar(modoSensivel ? "@MODO_SENSIVEL:ON" : "@MODO_SENSIVEL:OFF");
      Serial.printf("Modo sensor sensível: %s\r\n", modoSensivel ? "LIGADO" : "desligado");
    } else if (comando.startsWith("@SENSIBILIDADE:")) {
      // v4.13: nível de sensibilidade do solo (1-100; 50 = igual ao normal).
      String v = comando.substring(14);
      v.trim();
      sensNivel = v.toInt();
      if (sensNivel < 1) sensNivel = 1;
      if (sensNivel > 100) sensNivel = 100;
      prefs.putInt("sensNivel", sensNivel);
      enviar("@SENSIBILIDADE:OK " + String(sensNivel));
      Serial.printf("Nível de sensibilidade do solo: %d\r\n", sensNivel);
    } else if (comando == "@SIGN") {
      // Assinatura PEEX (v4.5): autentica o dispositivo como oficial
      enviar("@SIGN:PEEX");
    } else if (comando == "@VERSION") {
      // Versão do firmware (v4.14): o app mostra para confirmar a versão gravada
      enviar("@VERSION:4.14");
    } else if (comando.startsWith("@LOCK:")) {
      // v4.9: trava de segurança da rega. 1 = nunca ligar; 0 = liberado.
      String v = comando.substring(6);
      v.trim();
      regaTravada = (v == "1" || v == "ON" || v == "on" || v == "true");
      prefs.putBool("travada", regaTravada);
      // Segurança: se está regando e a trava é ligada, para na hora
      if (regaTravada && bombaLigada) desligarRele();
      enviar("@LOCK:" + String(regaTravada ? 1 : 0));
      Serial.printf("Trava de rega: %s\r\n", regaTravada ? "ATIVADA" : "desativada");
    } else if (comando.startsWith("@LEITURA:")) {
      // v4.11: leitura por tempo. Formato: @LEITURA:<auto>|<solo>|<arTemp>|<vazao>
      // auto=1 usa os intervalos ideais; auto=0 usa os valores em ms (50-3000).
      String cfg = comando.substring(9);
      int p1 = cfg.indexOf('|');
      int p2 = cfg.indexOf('|', p1 + 1);
      int p3 = cfg.indexOf('|', p2 + 1);
      leitAuto = cfg.substring(0, p1 > 0 ? p1 : cfg.length()).toInt() == 1;
      int solo = cfg.substring(p1 + 1, p2 > p1 ? p2 : cfg.length()).toInt();
      int art = cfg.substring(p2 + 1, p3 > p2 ? p3 : cfg.length()).toInt();
      int vaz = cfg.substring(p3 + 1).toInt();
      if (solo < 50) solo = 50;
      if (solo > 3000) solo = 3000;
      if (art < 1000) art = 1000; // DHT22 não lê com segurança abaixo de ~1s
      if (art > 3000) art = 3000;
      if (vaz < 50) vaz = 50;
      if (vaz > 3000) vaz = 3000;
      intervaloSolo = solo;
      intervaloArTemp = art;
      intervaloVazao = vaz;
      prefs.putBool("leitAuto", leitAuto);
      prefs.putInt("intSolo", intervaloSolo);
      prefs.putInt("intAr", intervaloArTemp);
      prefs.putInt("intVaz", intervaloVazao);
      enviar("@LEITURA:OK");
      Serial.printf("Leitura: auto=%d solo=%dms ar=%dms vazao=%dms\r\n",
                    leitAuto ? 1 : 0, intervaloSolo, intervaloArTemp, intervaloVazao);
    } else if (comando.startsWith("@RELE_ATIVO:")) {
      // Nível que LIGA o relé (v4.5): 0 = LOW, 1 = HIGH. Fica salvo no NVS.
      String v = comando.substring(12);
      v.trim();
      int nivel = v.toInt();
      if (nivel != 0 && nivel != 1) {
        enviar("@ERRO:RELE_ATIVO_INVALIDO");
      } else {
        releAtivoNivel = (nivel == 1) ? HIGH : LOW;
        prefs.putBool("releNivel", releAtivoNivel);
        // Garante o estado correto do relé na hora
        if (!bombaLigada) digitalWrite(PINO_RELE, !releAtivoNivel);
        enviar(releAtivoNivel == HIGH ? "@RELE_ATIVO:HIGH" : "@RELE_ATIVO:LOW");
        Serial.printf("Rele aciona com %s\r\n",
                      releAtivoNivel == HIGH ? "HIGH" : "LOW");
      }
    } else {
      enviar("@ERRO:COMANDO_DESCONHECIDO");
    }
  }
};

// ---------------- Reset total de fábrica pelo botão BOOT (v4.5/v4.6) ----------------
// Segure o botão BOOT (GPIO0) por 3 segundos: o ESP32 volta EXATAMENTE ao
// estado de fábrica, como se o código tivesse acabado de ser compilado:
// apaga TODOS os dados salvos (histórico, calibração, configuração, litros,
// relé) e restaura TODOS os padrões (nome BLE "PEEX", umidade ideal 70%,
// margem 80, rega abaixo de 60% / acima de 75%, sensibilidade máxima,
// relé nível LOW, rega automática LIGADA, modo sensor sensível desligado).
// O LCD mostra "Resetando..." enquanto apaga.
void resetFabrica() {
  // 1) Restaura TODOS os padrões em memória (estado recém-compilado)
  plantaNome = "";
  umidadeIdeal = 70;
  fatorPlanta = 1.0;
  margem = 80;
  tempoMaxRega = 0;
  intervaloRega = 0;
  regaInicio = 60;  // rega abaixo de 60%
  regaFim = 75;     // desliga acima de 75%
  limiteAR = 2400;  // calibração típica: seco lê alto
  umidoAlvo = 1200; // úmido lê baixo
  mlAtivo = false;
  mlRainAtivo = false;
  aguardandoChuva = false;
  modoSensivel = false;
  sensNivel = 50;
  sensSolo = 0;
  sensAr = 0;
  sensTemp = 0;
  sensVazao = 0;
  mlEficiencia = -1.0f;
  mlEficN = 0;
  litrosHoje = 0;
  litrosTotal = 0;
  dataHoje = "";
  irrigacoesHoje = 0;
  autoRega = true;
  offsetSec = 0;
  horaOk = false;
  releAtivoNivel = RELE_ATIVO_NIVEL; // padrão de fábrica do relé

  // 2) Apaga TODOS os dados salvos no NVS (histórico, config, calibração...)
  prefs.clear();

  // 3) Relé garantido desligado e nome BLE de volta ao padrão "PEEX"
  digitalWrite(PINO_RELE, !releAtivoNivel);
  renomearBLE("");

  // 4) Reinicia com os padrões restaurados (como se tivesse acabado de compilar)
  Serial.println("RESET DE FABRICA: todos os dados apagados, padrões restaurados.");
  delay(2000); // deixa a mensagem "Resetando..." visível na tela
  ESP.restart();
}

void verificarBotaoReset() {
  bool pressionado = (digitalRead(PINO_BOOT) == LOW);
  if (pressionado) {
    if (!bootBtnSegurando) {
      bootBtnSegurando = true;
      bootBtnInicio = millis();
    } else if (millis() - bootBtnInicio >= 3000) {
      Serial.println("RESET DE FABRICA: botão BOOT segurado 3s");
      if (lcd != nullptr) {
        lcd->clear();
        lcd->setCursor(0, 0);
        lcd->print("Resetando...");
      }
      resetFabrica();
    }
  } else {
    bootBtnSegurando = false;
  }
}

// ---------------- Setup ----------------
void setup() {
  Serial.begin(115200);
  // Relé sempre DESLIGADO já no boot (evita acionar ao energizar a placa).
  // v4.5: usa o nível salvo no NVS (RELE_ATIVO_NIVEL por padrão).
  pinMode(PINO_RELE, OUTPUT);
  digitalWrite(PINO_RELE, !releAtivoNivel);
  // LED interno apagado até conectar o app
  pinMode(PINO_LED, OUTPUT);
  digitalWrite(PINO_LED, !LED_ATIVO_NIVEL);

  dht.setup(PINO_DHT, DHTesp::DHT22);
  // Sensor de vazão: pulso (open-collector) com pull-up interno
  pinMode(PINO_FLUXO, INPUT_PULLUP);
  attachInterrupt(digitalPinToInterrupt(PINO_FLUXO), contarPulso, RISING);
  iniciarLCD();

  prefs.begin("plantauto", false);

  // Restaura estado salvo
  offsetSec = prefs.getLong("offset", 0);
  if (offsetSec != 0) horaOk = true;

  // Época deste boot (depois de restaurar o relógio): evita unir leituras de
  // ligações anteriores no histórico.
  bootEpoch = agoraEpoch();
  bootInicio = millis(); // animação "iniciando..." no LCD

  plantaNome = prefs.getString("nome", "");
  umidadeIdeal = prefs.getInt("um_ideal", 70);
  fatorPlanta = prefs.getFloat("fator", 1.0);
  margem = prefs.getInt("margem", 80);
  tempoMaxRega = prefs.getFloat("tmax", 0);
  intervaloRega = prefs.getInt("irega", 0);
  limiteAR = prefs.getInt("lar", 2400);
  umidoAlvo = prefs.getInt("ualvo", 1200);
  regaInicio = prefs.getInt("rInicio", 60); // v4.6: limite direto (rega < X%)
  regaFim = prefs.getInt("rFim", 75);       // v4.6: limite direto (desliga > Y%)
  mlAtivo = prefs.getBool("ml", false);
  sensSolo = prefs.getInt("sensSolo", 0);
  sensAr = prefs.getInt("sensAr", 0);
  sensTemp = prefs.getInt("sensTemp", 0);
  sensVazao = prefs.getInt("sensVazao", 0);
  mlEficiencia = prefs.getFloat("mlEff", -1.0);
  mlEficN = (mlEficiencia > 0) ? 1 : 0;
  litrosHoje = prefs.getFloat("lHoje", 0);
  litrosTotal = prefs.getFloat("lTotal", 0);
  dataHoje = prefs.getString("data", "");
  irrigacoesHoje = prefs.getInt("irr", 0);
  autoRega = prefs.getBool("auto", true); // padrão: rega automática ligada
  regaTravada = prefs.getBool("travada", false); // v4.9: trava de segurança

  // v4.11: intervalos de leitura por sensor (salvos pelo app via @LEITURA)
  leitAuto = prefs.getBool("leitAuto", true);
  intervaloSolo = prefs.getInt("intSolo", 200);
  intervaloArTemp = prefs.getInt("intAr", 2000);
  intervaloVazao = prefs.getInt("intVaz", 200);
  if (intervaloSolo < 50 || intervaloSolo > 3000) intervaloSolo = 200;
  if (intervaloArTemp < 1000 || intervaloArTemp > 3000) intervaloArTemp = 2000;
  if (intervaloVazao < 50 || intervaloVazao > 3000) intervaloVazao = 200;
  mlRainAtivo = prefs.getBool("mlRain", false); // v4.12: verificar clima
  modoSensivel = prefs.getBool("sensivel", false); // v4.13: modo sensor sensível
  sensNivel = prefs.getInt("sensNivel", 50);       // v4.13: nível de sensibilidade
  if (sensNivel < 1) sensNivel = 1;
  if (sensNivel > 100) sensNivel = 100;
  releAtivoNivel = prefs.getBool("releNivel", RELE_ATIVO_NIVEL);
  // Garante o estado desligado logo após carregar a configuração
  digitalWrite(PINO_RELE, !releAtivoNivel);

  // Botão BOOT (v4.5): segure 3s para apagar todos os dados (reset de fábrica)
  pinMode(PINO_BOOT, INPUT_PULLUP);

  // Se mudou o dia, zera o contador de regas e o consumo do dia
  if (dataHoje != dataAtual()) {
    irrigacoesHoje = 0;
    litrosHoje = 0;
    dataHoje = dataAtual();
    prefs.putString("data", dataHoje);
    prefs.putInt("irr", 0);
    prefs.putFloat("lHoje", 0);
  }

  // Nome BLE: "PEEX" ou "PEEX-<planta>" (sempre identificável)
  String nomeBLE = plantaNome.length() > 0
                       ? ("PEEX-" + plantaNome)
                       : String(NOME_BLE_PADRAO);
  if (nomeBLE.length() > 20) nomeBLE = nomeBLE.substring(0, 20);

  BLEDevice::init(nomeBLE.c_str());
  BLEServer* server = BLEDevice::createServer();
  server->setCallbacks(new ServerCallbacks());

  BLEService* servico = server->createService(SERVICE_UUID);

  charNotify = servico->createCharacteristic(
    CHAR_NOTIFY_UUID,
    BLECharacteristic::PROPERTY_NOTIFY
  );
  charNotify->addDescriptor(new BLE2902());

  BLECharacteristic* charWrite = servico->createCharacteristic(
    CHAR_WRITE_UUID,
    BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_WRITE_NR
  );
  charWrite->setCallbacks(new CharCallbacks());

  servico->start();

  BLEAdvertising* advertising = BLEDevice::getAdvertising();
  advertising->addServiceUUID(SERVICE_UUID);
  BLEDevice::startAdvertising();

  Serial.println("PlantAuto PEEX v4.14 pronto (espera de boot: 1 min). Nome BLE: " + nomeBLE);
  Serial.printf("Rega automatica: %s | Inteligente (ML): %s\r\n",
                autoRega ? "LIGADA" : "desligada",
                mlAtivo ? "LIGADA" : "desligada");
  Serial.printf("Limites de rega: liga abaixo de %d%%, desliga acima de %d%%\r\n",
                regaInicio, regaFim);
}

// ---------------- Loop ----------------
void loop() {
  verificarBotaoReset(); // v4.5: reset total com o botão BOOT (segure 3s)

  // v4.14: fim da espera de boot — passou 1 minuto sem ninguém conectar,
  // o firmware volta a trabalhar sozinho (rega, ML, clima etc.)
  if (aguardandoBoot && (millis() - bootInicio) >= ESPERA_BOOT_MS) {
    aguardandoBoot = false;
    Serial.println("Espera de boot (1 min) encerrada sem conexao.");
  }

  if (avisarDesconexao) {
    avisarDesconexao = false;
    desligarRele();
    salvarHistorico(); // salva a última leitura ao desconectar
    BLEDevice::startAdvertising();
  }

  // v4.14: PULSO DE SEGURANÇA DO ADVERTISING. Corrige o bug de "não conecta
  // durante a rega": o ruído da bomba/rele (ou um app fechado à força) pode
  // derrubar o anúncio BLE e ele não voltava sozinho. Agora, sempre que
  // ninguém estiver conectado, o anúncio é religado a cada 3s — o ESP32 fica
  // PERMANENTEMENTE visível e conectável, esteja regando ou não.
  static unsigned long ultimoPulsoAdv = 0;
  if (!conectado && (millis() - ultimoPulsoAdv >= 3000)) {
    ultimoPulsoAdv = millis();
    BLEDevice::startAdvertising();
  }

  // Nova data: zera o contador de regas e o consumo do dia
  String d = dataAtual();
  if (d != dataHoje) {
    dataHoje = d;
    irrigacoesHoje = 0;
    litrosHoje = 0;
    prefs.putString("data", dataHoje);
    prefs.putInt("irr", irrigacoesHoje);
    prefs.putFloat("lHoje", 0);
  }

  // Sensor de vazão: calcula L/min a cada 200 ms (e acumula litros da rega)
  static unsigned long ultimoCalcFluxo = 0;
  if (millis() - ultimoCalcFluxo >= (unsigned long)intervaloEfetivoVazao()) {
    ultimoCalcFluxo = millis();
    atualizarFluxo();
  }

  // Segurança do relé (v4.5): a cada segundo, reforça o estado DESLIGADO
  // quando não está regando — acaba com o "relé sempre ligado" mesmo que o
  // nível de acionamento esteja invertido ou o pino mude sozinho.
  static unsigned long ultimaSegurancaRele = 0;
  if (!bombaLigada && (millis() - ultimaSegurancaRele >= 1000)) {
    ultimaSegurancaRele = millis();
    digitalWrite(PINO_RELE, !releAtivoNivel);
  }

  // Diagnóstico de problemas (v4.12): a cada 3s procura situações anormais.
  static unsigned long ultimoDiag = 0;
  static unsigned long inicioDHTfalha = 0;
  static unsigned long inicioSoloPreso = 0;
  static bool sinalizouSemAgua = false;
  if (millis() - ultimoDiag >= 3000) {
    ultimoDiag = millis();

    // 1) Relé ligado, mas sem vazão por > 20s = solenoide aberta sem água.
    //    Só detecta se o sensor de vazão existe (já contou algum pulso).
    if (pulsosFluxo > 0) {
      if (bombaLigada && (millis() - irrInicio) > 20000 &&
          vazaoLmin < 0.5f && !sinalizouSemAgua) {
        sinalizouSemAgua = true;
        registrarErro("SEM_AGUA", "Relé ligado, mas sem água saindo");
      } else if (!bombaLigada) {
        sinalizouSemAgua = false;
      }
    }

    // 2) DHT22 sem leitura por mais de 90s = sensor não detectado.
    if (isnan(ultimaUmidAr) && isnan(ultimaTemp)) {
      if (inicioDHTfalha == 0) inicioDHTfalha = millis();
      else if (millis() - inicioDHTfalha > 90000) {
        inicioDHTfalha = millis();
        registrarErro("SENSOR_DHT", "Sensor de ar/temperatura não detectado");
      }
    } else {
      inicioDHTfalha = 0;
    }

    // 3) Sensor de solo preso em 0 ou 4095 por > 2 min (solto/queimado) ou
    //    com leituras instáveis (muitos saltos grandes seguidos).
    int rawSolo = ultimoRawSolo;
    if (rawSolo == 0 || rawSolo == 4095) {
      if (inicioSoloPreso == 0) inicioSoloPreso = millis();
      else if (millis() - inicioSoloPreso > 120000) {
        inicioSoloPreso = millis();
        registrarErro("SENSOR_SOLO",
                      rawSolo == 4095
                          ? "Sensor de solo preso em 4095 (conexão solta?)"
                          : "Sensor de solo preso em 0 (sem leitura)");
      }
    } else {
      inicioSoloPreso = 0;
    }
    if (saltosSolo >= 5) {
      saltosSolo = 0;
      registrarErro("SENSOR_SOLO", "Sensor de solo com leituras instáveis");
    }
  }

  // Atualiza leituras do DHT (a cada 2s) e do LCD (rotação + animações)
  atualizarDHT();
  static unsigned long ultimaAnimacao = 0;
  if (millis() - ultimaAnimacao >= 400) {
    ultimaAnimacao = millis();
    atualizarLCD(millis());
  }

  // Telemetria periódica em tempo real (200 ms mínimo) enquanto conectado
  static unsigned long ultimaTelemetria = 0;
  if (conectado && (millis() - ultimaTelemetria >= 200)) {
    ultimaTelemetria = millis();
    enviarTelemetria();
  }

  // Persistência no NVS: grava a cada 15 MINUTOS (independente do app), e
  // apaga o mais antigo quando enche (FIFO) — como uma câmera, sempre com folga.
  static unsigned long ultimaGravacao = 0;
  if (millis() - ultimaGravacao >= 900000) {
    ultimaGravacao = millis();
    salvarHistorico();
  }

  // Rega automática (v4.14: só depois da espera de boot de 1 min — e antes
  // eram só 5s, evitando acionar o relé na hora de energizar)
  if (!aguardandoBoot && millis() >= 5000) {
    // v4.12: Verificar clima (espera chuva em vez de regar na hora)
    verificarClimaEAgua();

    // Coleta amostras para o aprendizado (a cada 5s, sem regar)
    static unsigned long ultimaAmostraML = 0;
    if (mlAtivo && !bombaLigada && (millis() - ultimaAmostraML >= 5000)) {
      ultimaAmostraML = millis();
      mlAmostrar(millis() / 1000.0f, calcularUmidadeSolo());
    }

    // Aguardando chuva (v4.12): não rega ainda — a espera decide em 15/30 min
    if (autoRega && !bombaLigada && !aguardandoChuva) {
      int solo = calcularUmidadeSolo();
      // Respeita o intervalo mínimo entre regas (intervaloRega em minutos)
      bool intervaloOk = (intervaloRega <= 0) ||
                         ((millis() - ultimaRegaFim) >=
                          (unsigned long)intervaloRega * 60000UL);
      // v4.6: rega quando o solo fica ABAIXO de regaInicio (limite direto)
      bool secou = solo < regaInicio;
      // Rega inteligente (ML): prevê que vai secar dentro de até 10 min
      bool previu = false;
      if (mlAtivo && solo <= umidadeIdeal) {
        previu = mlPreverSecagem() > 0;
      }
      if ((secou || previu) && intervaloOk) {
        ligarRele();
      }
    }
    if (autoRega && bombaLigada) {
      int solo = calcularUmidadeSolo();
      // v4.6: desliga quando o solo chega ACIMA de regaFim (limite direto)
      if (solo >= regaFim) {
        desligarRele();
      } else {
        unsigned long maxMs;
        if (mlAtivo && mlEficiencia > 0.05f) {
          // Duração aprendida (ML): quanto falta p/ o solo subir até o alvo
          int falta = regaFim - solo;
          if (falta <= 0) {
            maxMs = 5000;
          } else {
            maxMs = (unsigned long)((falta / mlEficiencia) * 60000.0f);
          }
          if (maxMs < 30000) maxMs = 30000;       // mínimo 30s
          if (maxMs > 3600000) maxMs = 3600000;   // máximo 60 min
        } else {
          // Tempo máximo: tempoMaxRega (min) se configurado, senão fator x 1 min
          maxMs = tempoMaxRega > 0
              ? (unsigned long)(tempoMaxRega * 60000.0f)
              : (unsigned long)(fatorPlanta * 60000.0f);
        }
        if ((millis() - irrInicio) >= maxMs) {
          desligarRele(); // tempo máximo de segurança
        }
      }
    }
  }

  delay(200);
}

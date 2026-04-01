//Construido por Edcley no dia 31 para teste de codico base  o codico será testado e verificado diariamente em hortelã
// para o projeto Peex.

const int pinoSensor = A0;
const int pinoMotor  = 13; // Relé
const int pinoBotao  = 7;  // Função de teste 
const int leds[]     = {12, 11, 10}; 

// Variaveis de Calibração
const int limiteAR      = 600;  
const int limiteSECO    = 450;  
const int limiteMEDIO   = 300;  
const int margem        = 20;

unsigned long tempoRegaSegundos = 450; 
unsigned long tempoInicio = 0;
bool enchendo = false;
bool modoTeste = false;
int estadoLedAtual = -1;

void setup() {
  Serial.begin(9600);
  pinMode(pinoMotor, OUTPUT);
  
  pinMode(pinoBotao, INPUT_PULLUP); 
  
  for(int i=0; i<3; i++) pinMode(leds[i], OUTPUT);
  
  digitalWrite(pinoMotor, LOW); 
  Serial.println("Sistema Pronto - Botao no Pino 7");
}

void loop() {
  // Talveis com isso fique mas estável 
  long soma = 0;
  for(int i=0; i<10; i++) { soma += analogRead(pinoSensor); delay(2); }
  int leitura = soma / 10;

  unsigned long milisAtual = millis();

  // (LEDS)
  int novoEstado;
  if (leitura >= limiteAR)      novoEstado = -1; 
  else if (leitura >= limiteSECO) novoEstado = 0;  
  else if (leitura >= limiteMEDIO) novoEstado = 1;  
  else                           novoEstado = 2;  

  if (novoEstado != estadoLedAtual) {
    for(int i=0; i<3; i++) digitalWrite(leds[i], LOW);
    if (novoEstado != -1) digitalWrite(leds[novoEstado], HIGH);
    estadoLedAtual = novoEstado;
  }

  // Isso da prioridade ao botão de teste (caso não estever regando)
  if (digitalRead(pinoBotao) == LOW) { 
    digitalWrite(pinoMotor, HIGH);
    modoTeste = true;
    enchendo = false; // Cancela qualquer rega automática para dar prioridade ao botão
  } 
  // Quando soltar o botão desliga o Relé
  else if (modoTeste && digitalRead(pinoBotao) == HIGH) {
    desligarTudo();
  }

  // Altopilot
  if (!modoTeste) {
    // logica da terra seca
    if (!enchendo && leitura < limiteAR && leitura >= (limiteMEDIO + margem)) {
      digitalWrite(pinoMotor, HIGH);
      enchendo = true;
      tempoInicio = milisAtual;
      Serial.println("Bomba: Automatica Ativada");
    }

    // Desliga a chave geral a chegar a umidade azul
    if (enchendo && (leitura < (limiteMEDIO - margem) || leitura >= limiteAR)) {
      desligarTudo();
      Serial.println("Bomba: Automatica Finalizada");
    }

    // Desliga por tempo de seguranca
    if (enchendo && (milisAtual - tempoInicio) / 1000 >= tempoRegaSegundos) {
      desligarTudo();
      Serial.println("Bomba: Timeout de Seguranca");
    }
  }

  delay(30); 
}

void desligarTudo() {
  digitalWrite(pinoMotor, LOW);
  enchendo = false;
  modoTeste = false;
}

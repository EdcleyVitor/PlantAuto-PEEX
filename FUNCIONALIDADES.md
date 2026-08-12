# Funcionalidades - PlantAuto PEEX

Sistema de irrigação inteligente para a horta (EETEPA - Santarém/PA) formado por
um **app Flutter** + **firmware ESP32** que se comunicam via Bluetooth (BLE).

> O sistema **rega sozinho**. O ESP32 decide quando irrigar (rega automática
> ligada por padrão). O app serve para **administrar a horta** (cadastrar
> plantas, configurar umidade ideal/fator/margem), **coletar dados**
> (telemetria, vazão e consumo) e **gerar relatórios**.

---

## 1. Rega automática (o ESP32 decide)

- **Rega automática LIGADA por padrão** e salva no NVS (sobrevive a religamentos).
- **Limites diretos de rega (v4.6):** o ESP32 liga a válvula quando a umidade do
  solo fica **abaixo de `regaInicio`** (padrão 60%) e desliga quando chega
  **acima de `regaFim`** (padrão 75%). Acaba com o problema do "nunca rega".
- **Tempo máximo de rega:** por `fatorPlanta x 1 min` ou por `tempoMaxRega`
  configurado (0 = automático pelo fator; máx. 60 min).
- **Intervalo mínimo entre regas:** em minutos (0 = sem intervalo).
- **Rega funciona sem o app conectado:** o ESP32 decide sozinho e salva tudo.
- **Mensagens ao vivo:** `@BOMBA:LIGADA`, `@BOMBA:DESLIGADA`, `@BOMBA:BLOQUEADA`.

## 2. Aprendizado de máquina / rega inteligente (v4.2)

- **Regressão linear** (mínimos quadrados) sobre amostras da secagem do solo
  para **prever quando o solo vai atingir o limite de rega**.
- Se a previsão indica que secará em até **10 minutos**, a rega começa
  **antes da hora** (irrigação preditiva).
- Aprende a **eficiência da rega** (% de subida do solo por minuto) em cada
  rega e usa para definir a duração da próxima — adapta-se à planta.
- Liga/desliga pelo app (`@ML`) e eficiência persistida no NVS.

## 3. Sensores e medições

| Medição | Sensor | Pino |
|---------|--------|------|
| Umidade do solo | analógico (capacitivo/resistivo) | D34 (ADC1) |
| Temperatura do ar | DHT22 | D23 |
| Umidade do ar | DHT22 | D23 |
| Vazão (L/min) | YF-S201 | D22 |
| Consumo (L) | YF-S201 (450 pulsos = 1 L) | D22 |

- **Auto-range (v4.10):** aceita **qualquer tipo de sensor de solo** sem
  calibração — aprende a faixa de ADC (mín. = úmido, máx. = seco) e mapeia
  0-100% sozinho. A calibração manual, se válida, tem prioridade.
- **Leitura por tempo (v4.11):** o app define o intervalo de leitura de cada
  sensor (50 ms a 3 s), com modo **Automático** usando os intervalos ideais
  (solo 200 ms, ar/temp ~2 s, vazão 200 ms).
- **Telemetria em tempo real (v4.8):** `@DATA` a cada **200 ms** enquanto
  conectado (antes 5 s), com vazão calculada por tempo real.
- **Modo sensor sensível (v4.13):** para sensores de solo MUITO sensíveis
  (leitura tremida/saturada). Com ele LIGADO, um nível de sensibilidade (1-100)
  ajusta a escala: **50 = igual ao normal**, menor = mais estável/suave,
  maior = reage mais forte. Tudo salvo no NVS.

## 4. Verificação de clima (v4.12)

- Se o ar está **úmido (≥ 60%)** e a temperatura **baixa (≤ 30°C)**, a chuva é
  provável.
- Com o solo seco, em vez de regar na hora, o ESP32 **espera 30 min** (15 min à
  noite/madrugada) para ver se chove.
- Se nada acontecer e o solo continuar seco → **rega**. Se chover → **cancela**.
- Avises ao app: `@RAIN:ESPERANDO`, `@RAIN:CHOVEU`, `@RAIN:REGANDO`.

## 5. Calibração do sensor de solo (v4.3)

- **Calibração por toque:** `@CAL:DRY` captura a leitura atual como solo SECO e
  `@CAL:WET` como solo ÚMIDO — sem precisar saber os valores do ADC.
- **Detecção automática de orientação:** funciona com sensor que lê ALTO no seco
  (comum) ou BAIXO no seco.
- ADC bruto no `@DATA` (campo 8) e comando `@ADC` para leitura ao vivo no app.

## 6. Histórico e telemetria (NVS)

- **Histórico sem leitura repetida (v4.1):** leituras iguais **não são
  gravadas** — só a **duração** ("dur") da linha é atualizada. As mesmas
  `MAX_HISTORICO` (100) linhas cobrem **dias/semanas** em vez de ~25 h.
- **Buffer FIFO** (grava e apaga como câmera), sempre com folga no NVS.
- **Gravação a cada 15 min** (+ ao ligar/desligar a rega e ao desconectar).
- **Formato da linha:** `epoch,solo,ar,temp,irr,vazao,litros,dur`.
- **Consumo persistido:** litros por rega, por dia e acumulado.
- **Log de problemas (v4.12):** o firmware detecta sozinho (a cada 3 s) e salva
  no NVS: relé ligado SEM água saindo, sensor de solo instável/preso ("maluco")
  e DHT22 não detectado. O log entra no relatório do app (`@ERRORS`).

## 7. Segurança e manutenção

- **Trava de segurança (v4.9):** `@LOCK:1` trava a rega de forma **permanente**
  (salvo no NVS). Com a trava ativa o ESP32 NUNCA liga a rega — nem manual
  (`@BOMBA_ON`), nem automática. Trava no meio da rega = para na hora.
- **Reset total de fábrica:** segure o botão **BOOT (GPIO0) por 3 s** para
  apagar TODOS os dados (histórico, calibração, configuração, litros) e voltar
  aos padrões de fábrica.
- **Relé seguro (v4.5):** nível de acionamento configurável (`@RELE_ATIVO:0|1`,
  low ou high-level trigger) sem recompilar; no boot e a cada segundo o firmware
  reforça o relé **desligado** quando não está regando.
- **Assinatura PEEX (v4.5):** `@SIGN` responde `@SIGN:PEEX`, autenticando o
  dispositivo como oficial; o nome BLE já traz o prefixo "PEEX-".

## 8. Display LCD 16x2

- Linha 1 fixa: **"Horta EETEPA"**.
- Linha 2 (boot): `iniciando.` / `..` / `...` (3 s).
- Linha 2 (rotação 1 s): `Solo:45%` → `Ar:60%` → `Temp:25C` → `Vazao:2.50L/m`.
- Linha 2 (rega): `Regando.` / `..` / `...` (animação).

## 9. App Flutter (v1.0.0+17)

- **Identificação:** filtro **"Somente PEEX"** (ligado por padrão) + verificação
  de assinatura via `@SIGN`.
- **Telas da planta (hub com 3 ações):**
  - **Estatísticas:** gráficos + médias + heatmap de irrigação.
  - **Sensores:** todos os ajustes de rega (umidade ideal, margem, fator,
    tempo máximo, intervalo, calibração, leitura por tempo, modo sensor
    sensível).
  - **Relatórios:** PDF + baixar histórico.
- **Telemetria persistida (offline):** leituras (até 1500/dispositivo) e regas
  por dia salvas localmente; a tela mostra "AO VIVO" ou "LOCAL" e os gráficos
  funcionam offline.
- **Relatório em PDF:** resumo estatístico + status (regas, consumo, cobertura)
  + tabela das últimas 200 leituras (com coluna "Durou").
- **Gráficos:** umidade, temperatura, umidade do ar, **vazão (L/min)** e
  **consumo acumulado (L)**.
- **Multidispositivo:** conexão com vários ESP32 ("PEEX-<planta>").
- **Gravar / Desconectar** por planta no card.

## 10. Comandos BLE do firmware

| Comando | Ação |
|---------|------|
| `@TIME:<epoch>` | Sincroniza o relógio do ESP32 |
| `@CONFIG:<nome>\|<ideal>\|<fator>\|<margem>\|<tempoMax>\|<intervalo>\|<limiteAR>\|<umidoAlvo>\|<regaInicio>\|<regaFim>` | Configura a planta (10 campos) e renomeia o BLE para `PEEX-<nome>` |
| `@ML:<0\|1>` | Liga/desliga a rega inteligente |
| `@ML_RAIN:<0\|1>` | Liga/desliga a verificação de clima |
| `@SENS:<solo>\|<ar>\|<temp>\|<vazao>` | Sensibilidade (deadband) dos sensores |
| `@MODO_SENSIVEL:<0\|1>` | Liga/desliga o modo sensor sensível |
| `@SENSIBILIDADE:<1-100>` | Nível de sensibilidade do solo |
| `@LEITURA:<auto>\|<solo>\|<ar>\|<vazao>` | Intervalo de leitura de cada sensor (ms) |
| `@ADC` | Leitura bruta do sensor de solo |
| `@CAL:DRY` / `@CAL:WET` | Calibra solo seco/úmido pela leitura atual |
| `@UMIDADE` | Responde umidade do solo (%) |
| `@FLUXO` | Responde vazão (L/min) e consumo (hoje/total) |
| `@STATUS` | Telemetria completa + estado (trava, leitura, clima, modo sensível) |
| `@HISTORY` | Envia o histórico armazenado (`@HIST_END`) |
| `@ERRORS` | Envia o log de problemas (`@ERR_END`) |
| `@ERRLIMPAR` | Limpa o log de problemas |
| `@BOMBA_ON` / `@BOMBA_OFF` | Liga/desliga a válvula (teste/manual) |
| `@AUTO_ON` / `@AUTO_OFF` | Liga/desliga a rega automática |
| `@SIGN` | Responde `@SIGN:PEEX` (assinatura oficial) |
| `@VERSION` | Responde `@VERSION:4.13` |
| `@LOCK:<0\|1>` | Trava/libera a rega (permanente, salvo no NVS) |
| `@RELE_ATIVO:<0\|1>` | Nível do relé: 0 = LOW, 1 = HIGH (salvo no NVS) |

---

**PlantAuto PEEX** · Projeto PEEX - EETEPA · Santarém/PA

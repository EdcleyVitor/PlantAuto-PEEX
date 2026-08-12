# PlantAuto PEEX - App v1.0.0 (firmware v4.13)

Aplicativo Flutter para a irrigação inteligente via Bluetooth (BLE).
A v4.1 **libera espaço no histórico do ESP32** (leituras repetidas **não são
gravadas** — cada linha registra a **duração** até a próxima variação),
**reorganiza as telas da planta** (Estatísticas / Sensores / Relatórios) e
amplia a **configuração por planta** (tempo máximo de rega, intervalo entre
regas e calibração do sensor de solo). A v4 adicionou a **medição de água**
(sensor de vazão YF-S201), **margem de rega configurável**, **telemetria
persistida no celular** (dados offline) e **relatório em PDF**.

> 🎯 **O sistema rega sozinho.** O ESP32 decide quando irrigar (rega automática
> ligada por padrão). O app serve para **administrar a horta** (cadastrar plantas,
> configurar umidade ideal/fator/margem), **coletar dados** (telemetria, vazão e
> consumo) e **gerar relatórios**. Não há botões manuais de rega no app.

## Identificação PEEX

- O ESP32 anuncia o nome BLE **"PEEX"** (e "PEEX-<planta>" após vincular a planta).
- Na aba **Conectividade** há o filtro **"Somente PEEX"**: ative para exibir
  apenas os dispositivos do projeto, diferenciando o nosso ESP32 dos demais.

## Ligações (eletrônica v4)

| Componente                 | Pino   | GPIO |
|----------------------------|--------|------|
| Sensor de umidade do solo  | **D34**| 34   |
| DHT22 (temp. e umidade ar) | D23    | 23   |
| Sensor de vazão YF-S201    | **D22**| 22   |
| Relé da válvula            | **D27**| 27   |
| LCD 16x2 I2C - SDA         | **D21**| 21   |
| LCD 16x2 I2C - SCL         | D4     | 4    |
| LED interno (indicador)    | (fixo) | 2    |

> ⚠️ **Não use D34/D35/D36/D39 para o relé**: no ESP32 clássico esses pinos são
> somente de entrada. Para trocar o pino do relé, mude `#define PINO_RELE` no firmware.
>
> ⚠️ **Não use o GPIO2 para o LCD (SDA)**: o GPIO2 é o **LED interno do ESP32**.
> Se o SDA ficar no D2, o LED acende junto com o LCD. O SDA do LCD vai no **D21**.
>
> ⚠️ **YF-S201**: vermelho→5V, preto→GND, sinal (amarelo)→**D22** (pull-up interno).
>
> 💡 O **LED interno** (GPIO2) é o indicador de conexão: acende quando o app
> conecta e apaga ao desconectar.

## LCD 16x2 (v4.1)

- Linha 1 (fixa): `Horta EETEPA`
- Linha 2: `iniciando.` `iniciando..` `iniciando...` (nos 3 primeiros segundos)
- Linha 2 (rotação a cada 1s): `Solo:45%` → `Ar:60%` → `Temp:25C` → `Vazao:2.50L/m`
- Linha 2 (enquanto rega): `Regando.` `Regando..` `Regando...`

## Estrutura

```
lib/
  models/planta.dart                Modelo da planta (inclui margem e calibração)
  models/leitura.dart               Leitura dos sensores (inclui vazão/litros/duração)
  services/bluetooth_service.dart   Serviço BLE (NUS) + filtro PEEX + config (8 campos)
  services/settings_manager.dart    Configurações
  services/plantacao_store.dart     Lista de plantas (SharedPreferences)
  services/leitura_store.dart       Telemetria persistida (leituras + regas)
  screens/home_screen.dart          Navegação (3 abas)
  screens/conectividade_screen.dart Conexão ESP32 + dados (umidade/histórico)
  screens/plantacao_screen.dart     Lista de plantas (Gravar/Desconectar)
  screens/adicionar_planta_screen.dart  Formulário de nova planta (+ margem)
  screens/planta_detail_screen.dart Hub da planta (resumo + 3 ações + Gravar)
  screens/estatisticas_screen.dart  Gráficos + médias + histórico de irrigação
  screens/sensibilidade_screen.dart Sliders de rega e calibração do sensor
  screens/relatorios_screen.dart    Relatório PDF + solicitar histórico
  screens/configuracoes_screen.dart Configurações (tema do sistema)
```

## Firmware

O firmware do ESP32 está no arquivo `PlantAuto_PEEX_v4.13.ino` (na pasta
`firmware/` deste repositório).

Recursos:
- Sensor de umidade do solo (D34)
- Sensor DHT22 de temperatura e umidade do ar (D23)
- **Sensor de vazão YF-S201 (D22)** - vazão (L/min) e consumo em litros
- Relé da válvula solenoide (D27)
- LCD 16x2 I2C com leituras ao vivo + animação de rega
- Sincronização de relógio com o app ao conectar (`@TIME`)
- Vinculação da planta e renomeação do BLE para `PEEX-<planta>` (`@CONFIG`)
- **`@CONFIG` com 8 campos** (`nome|ideal|fator|margem|tempoMax|intervalo|limiteAR|umidoAlvo`),
  salvos no NVS: margem de rega, tempo máximo de rega em minutos (0 = automático
  pelo fator), intervalo mínimo entre regas em minutos (0 = sem intervalo) e a
  **calibração do sensor de solo** (ADC do seco e do úmido) — tudo sem recompilar
- Rega automática: o ESP32 irriga sozinho quando o solo fica seco
  (umidade ideal - margem) e desliga ao atingir (umidade ideal + margem) ou o
  tempo máximo (fator x 1 min, ou tempoMax). **Ligada por padrão** e salva no NVS
  (`@AUTO_ON`/`@AUTO_OFF` controlam, mas ela já vem ativa).
- Histórico no NVS com **8 campos por linha** (inclui vazão, litros e a
  **duração em segundos até a próxima mudança**), buffer FIFO com máx. 100
  linhas. **Na v4.1 leituras repetidas não são gravadas**: o ESP32 só atualiza a
  duração da linha atual, então as mesmas 100 linhas cobrem **muito mais tempo**
  (dias/semanas em vez de ~25 h).
- LCD 16x2 com linha fixa "Horta EETEPA" e rotação Solo/Ar/Temp/Vazão + animação
  de rega.
- Comando **`@FLUXO`** - responde `vazao,litrosHoje,litrosTotal`.

Dependências (Arduino IDE):
- "DHT sensor library" (DHTesp) de beegee_tokyo
- "LiquidCrystal I2C" de Frank de Brabander

## Novidades no app

- **Telas separadas**: a tela da planta virou um hub com 3 ações —
  **Estatísticas** (gráficos + médias + heatmap de irrigação), **Sensores**
  (todos os ajustes de rega) e **Relatórios** (PDF + baixar histórico).
- **Histórico sem repetição**: cada leitura mostra **quanto tempo durou** até a
  próxima variação (campo `dur` do firmware v4.1); o relatório em PDF ganhou a
  coluna "Durou" e a **cobertura total** do histórico.
- **Configuração de sensores**: sliders de umidade ideal, margem, nível de
  irrigação, **tempo máximo de rega**, **intervalo entre regas** e
  **calibração do sensor de solo** (ADC seco/úmido), com gravação automática no
  ESP32.
- Botões **Gravar** (reenvia a config) e **Desconectar** (desvincula) no card.
- **Telemetria persistida**: leituras (até 1500/dispositivo) e regas por dia
  ficam salvas; a tela mostra "AO VIVO" ou "LOCAL" e os gráficos funcionam
  offline.
- **Relatório em PDF**: resumo estatístico + status (regas, consumo, cobertura)
  + tabela das últimas 200 leituras, exportado pelo `printing`.
- Gráficos novos de **Vazão (L/min)** e **Consumo acumulado (L)**.

## Build do APK

```bash
flutter pub get
flutter build apk --release --no-tree-shake-icons
```

APK gerado em `build/app/outputs/flutter-apk/app-release.apk`.

## Comandos BLE

| Comando      | Ação                                    |
|--------------|-----------------------------------------|
| `@UMIDADE`   | Responde com a umidade do solo (%)      |
| `@BOMBA_ON`  | Liga a bomba de água                    |
| `@BOMBA_OFF` | Desliga a bomba de água                 |
| `@STATUS`    | Envia a telemetria completa             |
| `@HISTORY`   | Envia o histórico armazenado (8 campos, inclui duração) + `@HIST_END` |
| `@FLUXO`     | Responde `vazao,litrosHoje,litrosTotal` |
| `@AUTO_ON`   | Liga a rega automática                  |
| `@AUTO_OFF`  | Desliga a rega automática               |
| `@TIME:epoch`| Sincroniza o relógio do ESP32           |
| `@CONFIG:nome\|ideal\|fator\|margem\|tempoMax\|intervalo\|limiteAR\|umidoAlvo` | Configura a planta (8 campos) e renomeia o BLE |

---
**PlantAuto PEEX** · Projeto PEEX - EETEPA · Santarém/PA

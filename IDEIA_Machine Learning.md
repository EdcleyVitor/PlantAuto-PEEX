# 📱 PlantAuto PEEX - Aplicativo Inteligente (Machine Learning)

Aplicativo desenvolvido para identificação de plantas e configuração inteligente de irrigação no sistema PlantAuto PEEX.

---

## 📌 Sobre o Aplicativo

O aplicativo tem como objetivo identificar plantas e definir automaticamente os parâmetros ideais de irrigação, integrando-se com o sistema físico baseado em ESP32.

O sistema utiliza APIs públicas gratuitas e lógica própria para transformar dados em decisões inteligentes.

---

## 🧠 Funcionamento do Sistema

O funcionamento do aplicativo é dividido em etapas:

### 🔎 1. Pesquisa de Plantas (Wikipedia API)

O usuário realiza uma busca por plantas utilizando a API da Wikipedia, permitindo acesso a:

* Nome da planta
* Informações gerais
* Imagens
* Descrição

Essa etapa facilita a identificação correta da planta.

---

### 🌿 2. Seleção da Planta

O usuário escolhe a planta desejada com base nas informações apresentadas.

---

### 🔗 3. Coleta de Dados (Perenual API)

Após a seleção, o sistema consulta a API Perenual para obter dados relevantes como:

* Nível de irrigação (`watering`)
* Tipo da planta
* Condições ideais de cultivo

⚠️ Observação: a API fornece dados em formato qualitativo (ex: "frequent", "average", "minimum").

---

### ⚙️ 4. Conversão Inteligente de Dados

Os dados da API são convertidos em valores numéricos para uso no sistema:

```cpp
if (watering == "minimum") fatorPlanta = 0.5;
if (watering == "average") fatorPlanta = 1.0;
if (watering == "frequent") fatorPlanta = 1.5;
```

---

### 📡 5. Leitura do Sensor (ESP32)

O ESP32 mede a umidade do solo e converte para porcentagem:

```cpp
umidade = map(valorSensor, seco, molhado, 0, 100);
```

---

### 🧮 6. Cálculo Inteligente de Irrigação

O sistema calcula automaticamente quanto irrigar:

```cpp
tempo = (umidadeIdeal - umidadeAtual) * fatorPlanta * constante;
```

---

### 🤖 7. Integração com Machine Learning

O sistema pode evoluir para aprendizado automático com base em histórico:

* Tempo de irrigação aplicado
* Resultado no solo
* Ajuste automático de parâmetros

---

## 🧩 Arquitetura do Sistema

Usuário
↓
App (Wikipedia + Perenual API)
↓
Sistema de Conversão
↓
ESP32 (Sensor + Controle)
↓
Irrigação Automática

---

## ⚙️ Tecnologias Utilizadas

* API da Wikipedia (busca e interface)
* Perenual API (dados de plantas)
* ESP32 (controle físico)
* Sensores de umidade
* Comunicação via Wi-Fi (HTTP/MQTT)

---

## 🔒 Limitações da API

* Plano gratuito com limite de requisições diárias
* Dados qualitativos (não fornece valores exatos)
* Dependência de conexão com internet

---

## 💡 Estratégia Inteligente

Para maior eficiência, o sistema utiliza:

* Cache local de dados
* Conversão de dados qualitativos para quantitativos
* Uso combinado de sensores e APIs

---

## 🚀 Futuras Melhorias

* Identificação automática de plantas por imagem
* Aprendizado contínuo (Machine Learning real)
* Dashboard com gráficos em tempo real
* Sistema de zonas de irrigação
* Integração com energia solar

---

## 👨‍💻 Desenvolvedor

**Edcley Vítor**
Projeto PEEX - UFOPA
Programador e responsável pela lógica do sistema

---

## 📍 Local

Santarém - Pará
EETEPA

---

## 📊 Status do Projeto

🛠️ Em desenvolvimento

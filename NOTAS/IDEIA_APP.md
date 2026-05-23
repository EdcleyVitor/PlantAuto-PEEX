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

O usuário realiza uma busca por plantas utilizando a API da Wikipedia **apenas para fins de interface e identificação visual**, permitindo acesso a:

* Nome da planta
* Informações gerais
* Imagens
* Descrição

⚠️ Importante: **a Wikipedia NÃO é usada para decisões de irrigação ou cálculos do sistema**.

Essa etapa serve exclusivamente para ajudar o usuário a identificar corretamente a planta.

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
App (Wikipedia → busca visual)
↓
Perenual API (dados técnicos de irrigação)
↓
Sistema de Conversão (lógica própria)
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

O sistema segue uma separação clara de responsabilidades:

* Wikipedia → interface (nome, imagem, descrição)
* Perenual API → dados técnicos (irrigação)
* Sistema próprio → conversão e cálculos
* ESP32 → execução física

Além disso, utiliza:

* Cache local de dados
* Conversão de dados qualitativos para quantitativos
* Uso combinado de sensores e lógica computacional

---

## 🗄️ Sistema de Banco de Dados e Histórico

O sistema contará com um banco de dados em SQL para armazenamento de informações, evitando requisições desnecessárias às APIs e permitindo aprendizado contínuo.

### 📊 O que será armazenado:

* Tipos de plantas cadastradas
* Parâmetros de irrigação (umidade ideal, fator, tempo)
* Dados coletados dos sensores
* Histórico de irrigações realizadas
* Resultados obtidos (antes/depois da irrigação)

### 🎯 Objetivo do banco de dados:

* Reduzir uso de APIs externas
* Aumentar velocidade do sistema
* Permitir ajustes automáticos (Machine Learning futuro)
* Criar histórico inteligente de cultivo

---

## 🌱 Estrutura Física dos Canteiros

Os canteiros da horta possuem as seguintes dimensões:

* Comprimento: 18 tijolos
* Largura: 4 tijolos
* Espaçamento: 2 divisões com aproximadamente 1,5 cm de cimento entre eles

Essas medidas serão consideradas para:

* Distribuição de sensores
* Controle por zonas de irrigação
* Cálculo da quantidade de água necessária

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

🛠️ Em desenvolvimento

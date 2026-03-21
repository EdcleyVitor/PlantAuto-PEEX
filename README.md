# 🌱 PlantAuto PEEX

Sistema inteligente de irrigação automática desenvolvido com ESP32, integração com APIs públicas e arquitetura preparada para Machine Learning.

---

## 📌 Visão Geral

O **PlantAuto PEEX** é um projeto de automação agrícola escolar que combina:

* Sensores físicos (umidade do solo)
* Microcontrolador ESP32
* APIs públicas de plantas
* Lógica de cálculo inteligente
* Estrutura para aprendizado futuro (Machine Learning)

O objetivo é criar um sistema capaz de irrigar plantas de forma eficiente, adaptando-se às necessidades específicas de cada cultivo.

---

## 🧠 Arquitetura do Projeto

O sistema é dividido em módulos:

### 📱 Frontend (Interface)

Responsável por:

* Busca de plantas
* Exibição de dados
* Controle do sistema

👉 O HTML atual é um **protótipo funcional** usado para testar APIs e lógica.

---

### 🌐 APIs Externas

#### Wikipedia

* Usada apenas para:

  * Nome
  * Imagem
  * Descrição

❗ NÃO usada para decisões técnicas

#### Perenual API

* Fornece:

  * Nível de irrigação (watering)

---

### ⚙️ Sistema de Lógica

Responsável por:

* Converter dados da API
* Calcular irrigação
* Tomar decisões

#### Conversão de dados:

* minimum → 0.5
* average → 1.0
* frequent → 1.5

---

### 🔌 ESP32 (Hardware)

Responsável por:

* Ler sensores de umidade
* Executar irrigação
* Receber dados do sistema

---

## 🧮 Cálculo de Irrigação

O sistema utiliza a fórmula:

```
tempo = (umidadeIdeal - umidadeAtual) × fatorPlanta × constante
```

Onde:

* umidadeAtual → sensor
* fatorPlanta → API
* constante → ajuste empírico

---

## 🗄️ Banco de Dados (Planejado)

Será utilizado SQL para armazenar:

* Plantas
* Parâmetros
* Leituras de sensores
* Histórico de irrigação

### 🎯 Objetivo:

* Reduzir chamadas de API
* Aumentar performance
* Permitir Machine Learning

---

## 🔁 Sistema de Histórico

O sistema irá registrar:

* Umidade antes/depois
* Tempo de irrigação
* Resultado obtido

👉 Base para aprendizado futuro

---

## 🤖 Machine Learning (Futuro)

O sistema poderá:

* Ajustar automaticamente parâmetros
* Aprender comportamento do solo
* Otimizar irrigação

---

## 🌱 Estrutura Física

Canteiros:

* 18 tijolos de comprimento
* 4 tijolos de largura
* Divisões com 1,5 cm de cimento

Aplicação:

* Zonas de irrigação
* Distribuição de sensores

---

## ⚠️ Estado Atual do Projeto

### ✅ Concluído

* Estrutura conceitual
* Integração com API (teste)
* Cálculo de irrigação
* Protótipo frontend

### 🚧 Em desenvolvimento

* Backend
* Integração com ESP32
* Banco de dados

### ❌ Ainda não implementado

* Sensor real conectado
* Sistema online completo
* Machine Learning

---

## 📁 Estrutura do Projeto (Planejada)

```
/frontend
/backend
/esp32
/database
/docs
```

---

## ⚠️ Observações Importantes

* O HTML atual é apenas um teste de API
* A chave da API deve ser movida para backend
* O sistema final não dependerá totalmente de APIs

---

## 👨‍💻 Desenvolvedor

**Edcley Vítor**
Projeto PEEX
Programador e responsável pela arquitetura do sistema

---

## 📍 Local

Santarém - Pará
EETEPA

---

## 🚀 Visão do Projeto

Criar um sistema inteligente capaz de unir:

* Automação
* IoT
* Inteligência Artificial
* Sustentabilidade

---

## 📊 Status

🛠️ Em desenvolvimento (fase de protótipo avançado)

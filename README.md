# 🌱 PlantAuto PEEX

Sistema inteligente de irrigação automática desenvolvido com ESP32, integração com APIs públicas e arquitetura preparada para Machine Learning.

---

## 📌 Visão Geral

O **PlantAuto PEEX** é um projeto de automação agrícola escolar que tem como principal objetivo desenvolver um sistema capaz de irrigar plantas de forma automática e inteligente.

Diferente de sistemas simples, este projeto combina sensores físicos, análise de dados e integração com APIs para tomar decisões mais precisas. A proposta é reduzir o desperdício de água e melhorar o crescimento das plantas por meio de tecnologia.

O sistema foi idealizado para aplicação na horta da escola, mas pode ser expandido para outros cenários agrícolas.

---

## 🧠 Arquitetura do Projeto

O sistema é dividido em módulos independentes, permitindo organização, escalabilidade e facilidade de manutenção.

Essa separação garante que cada parte do sistema tenha uma função específica, evitando sobrecarga e facilitando futuras melhorias.

---

### 📱 Frontend (Interface)

O frontend é responsável pela interação com o usuário. Ele permite que o usuário pesquise plantas, visualize informações e acompanhe o funcionamento do sistema.

Atualmente, o sistema possui um protótipo em HTML que realiza:

* Busca de plantas
* Exibição de dados
* Simulação do sistema de irrigação

Esse protótipo serve como base para testes de APIs e lógica, e será evoluído para uma interface mais completa no futuro.

---

### 🌐 APIs Externas

As APIs são utilizadas para complementar o sistema com dados externos.

#### Wikipedia

A Wikipedia é utilizada apenas para fins informativos e visuais. Ela fornece:

* Nome da planta
* Descrição
* Imagens

Esses dados ajudam o usuário a identificar corretamente a planta, mas não são utilizados para cálculos ou decisões do sistema.

#### Perenual API

A Perenual API fornece dados técnicos sobre plantas, especialmente relacionados à irrigação.

Ela retorna informações como:

* Nível de irrigação (watering)

Esses dados são utilizados como base para os cálculos do sistema.

---

### ⚙️ Sistema de Lógica

O sistema de lógica é o “cérebro” do projeto. Ele transforma dados em decisões.

Como as APIs retornam dados qualitativos (como "frequent" ou "minimum"), o sistema realiza uma conversão para valores numéricos.

Exemplo:

* minimum → 0.5
* average → 1.0
* frequent → 1.5

Essa conversão permite que o sistema utilize cálculos matemáticos para definir a quantidade de água necessária.

---

### 🔌 ESP32 (Hardware)

O ESP32 é o responsável pela execução física do sistema.

Ele realiza as seguintes funções:

* Leitura do sensor de umidade do solo
* Processamento dos dados recebidos
* Ativação da bomba de água

O ESP32 funciona como o executor das decisões tomadas pelo sistema.

---

## 🧮 Cálculo de Irrigação

O sistema utiliza uma fórmula para determinar quanto tempo a irrigação deve ser ativada.

```
tempo = (umidadeIdeal - umidadeAtual) × fatorPlanta × constante
```

### Explicação:

* **umidadeAtual:** valor obtido pelo sensor
* **umidadeIdeal:** valor definido como ideal para a planta
* **fatorPlanta:** definido com base na API
* **constante:** valor ajustado com testes reais

Essa abordagem permite que o sistema não apenas ligue ou desligue a irrigação, mas ajuste o tempo de forma inteligente.

---

## 🗄️ Banco de Dados (Planejado)

O sistema utilizará um banco de dados SQL para armazenar informações importantes.

### Dados armazenados:

* Plantas cadastradas
* Parâmetros de irrigação
* Leituras dos sensores
* Histórico de irrigação

### Importância:

O banco de dados permite que o sistema funcione de forma mais eficiente, reduzindo a necessidade de chamadas constantes às APIs e armazenando conhecimento adquirido.

---

## 🔁 Sistema de Histórico

O sistema registrará todas as ações realizadas, criando um histórico detalhado.

Exemplo de dados armazenados:

* Umidade antes da irrigação
* Tempo de irrigação aplicado
* Umidade após irrigação

Esses dados são essenciais para análise e evolução do sistema.

---

## 🤖 Machine Learning (Futuro)

Com base no histórico, o sistema poderá evoluir para um modelo de aprendizado automático.

Isso permitirá:

* Ajustar automaticamente os parâmetros
* Melhorar a eficiência da irrigação
* Adaptar-se a diferentes condições do solo

Essa etapa transformará o sistema em uma solução inteligente e autônoma.

---

## 🌱 Estrutura Física

Os canteiros possuem dimensões específicas que influenciam diretamente o sistema.

* 18 tijolos de comprimento
* 4 tijolos de largura
* Divisões com 1 cm de cimento

Essas medidas são importantes para definir:

* Posicionamento dos sensores
* Distribuição da água
* Divisão por zonas

*Tijolo dimeçoes
23 cm comprimento
14 de altura
largura nao nessesaria
  
*Aproximadamente Comprimeto
18 . 23 = 414 cm
17 Espaço entre eles que seria o cimento
414 + 17 = 431 cm de largura  4 metros e 31 cm

*Aproximadamente largura
4 . 23 = 92 cm
3 Espaço entre eles que seria o cimento
92 + 3 = 95 cm de largura 0 metros e 95 cm

*Aproximadamente Altura
são duas fileiras de tijolo oou seja
14 . 2 = 28 de altura 

---

## ⚠️ Estado Atual do Projeto

O projeto encontra-se em fase de desenvolvimento.

### Concluído:

* Planejamento do sistema
* Protótipo funcional
* Integração com API
* Lógica de cálculo

### Em desenvolvimento:

* Backend
* Integração com hardware
* Banco de dados

### Futuro:

* Machine Learning
* Sistema completo online

---


## ⚠️ Observações Importantes

* O sistema não deve depender exclusivamente de APIs
* A chave da API deve ser protegida no backend
* O sensor é a principal fonte de dados confiáveis

---


## 📍 Local

Santarém - Pará
EETEPA

---

## 🚀 Visão do Projeto

Criar um sistema que una tecnologia e agricultura, promovendo sustentabilidade e inovação no ambiente escolar.

---

## 📊 Status

🛠️ Em desenvolvimento (fase de protótipo avançado)

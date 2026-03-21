# 📱 PlantAuto PEEX - Aplicativo Inteligente

Aplicativo desenvolvido para identificação de plantas e configuração inteligente de irrigação no sistema PlantAuto PEEX.

---

## 📌 Sobre o Aplicativo

O aplicativo tem como objetivo auxiliar na identificação de plantas e na definição automática dos parâmetros ideais de irrigação, integrando-se com o sistema físico baseado em ESP32.

O sistema utiliza uma abordagem híbrida, combinando dados públicos e uma base própria otimizada para automação.

---

## 🧠 Funcionamento do Sistema

O funcionamento do aplicativo é dividido em etapas:

### 🔎 1. Pesquisa de Plantas (API pública)

O usuário realiza uma busca por plantas utilizando a API da Wikipedia, permitindo acesso a:

- Nome da planta  
- Informações gerais  
- Imagens  
- Descrição  

Essa etapa facilita a identificação correta da planta pelo usuário.

---

### 🌿 2. Seleção da Planta

Após a pesquisa, o usuário escolhe a planta desejada com base nas informações apresentadas.

---

### ⚙️ 3. Pós-processamento Inteligente

Após a seleção, o sistema realiza um pós-processamento utilizando um banco de dados próprio contendo informações relevantes para irrigação, como:

- Umidade mínima ideal  
- Tempo de irrigação  
- Frequência recomendada  

Esses dados são estruturados especificamente para automação.

---

### 🔗 4. Integração com o Sistema Físico

O aplicativo envia os dados processados para o ESP32, que executa as ações de irrigação com base nas condições do solo.

---

## 🧩 Arquitetura do Sistema

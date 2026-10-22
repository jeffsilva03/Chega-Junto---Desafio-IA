# Chega Junto

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Python](https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white)
![FastAPI](https://img.shields.io/badge/FastAPI-009688?style=for-the-badge&logo=fastapi&logoColor=white)
![MySQL](https://img.shields.io/badge/MySQL-4479A1?style=for-the-badge&logo=mysql&logoColor=white)
![Status](https://img.shields.io/badge/Status-MVP%20Funcional-brightgreen?style=for-the-badge)

**Aplicativo de preparação para consultas e exames, com organização de informações, lembretes, checklist e apoio de inteligência artificial para ajudar o paciente a chegar mais preparado ao atendimento.**

</div>

---

## Sobre o projeto

O **Chega Junto** é um projeto desenvolvido para o **Desafio Salte com a IA**, com foco em dificuldades vivenciadas antes de consultas e exames: esquecimento de documentos, dúvidas sobre orientações, barreiras para comparecer e dificuldade para organizar o que será relatado ao profissional de saúde.

A solução reúne um aplicativo Flutter para Android e Web, uma API FastAPI com persistência em MySQL e um Portal Web de Agendamentos. O paciente pode acompanhar seus atendimentos, verificar o preparo necessário, registrar informações por texto ou áudio e revisar um resumo estruturado com perguntas que deseja levar à consulta.

A inteligência artificial auxilia na **organização do relato informado pelo próprio usuário**, inclusive por meio de perguntas complementares. O conteúdo permanece editável e depende da revisão humana. **A IA não realiza diagnóstico, prescrição, interpretação de exames ou triagem**, e nenhuma informação é enviada automaticamente a profissionais, unidades de saúde ou sistemas do SUS.

O projeto é um **MVP acadêmico demonstrativo e não oficial**, operando com dados fictícios. Não possui integração real com o SUS, gov.br ou prontuários eletrônicos.

## Objetivos

* Facilitar a **preparação para consultas e exames**
* Centralizar **agendamentos, documentos, orientações e lembretes**
* Ajudar o paciente a **confirmar presença e identificar dificuldades de comparecimento**
* Permitir **registro pré-consulta por texto ou áudio**
* Utilizar **IA para organizar relatos e formular perguntas neutras**
* Garantir **revisão, edição e decisão do usuário sobre o conteúdo**
* Oferecer uma experiência **acessível, simples e multiplataforma**
* Demonstrar um fluxo integrado entre **aplicativo, API, banco de dados e portal**

## Funcionalidades do sistema

| Funcionalidade | Descrição |
| -------------- | --------- |
| Cadastro e autenticação | Cadastro e login de pacientes fictícios com autenticação JWT no modo API |
| Agenda | Consulta de atendimentos, datas, horários, unidades e detalhes |
| Checklist de preparo | Acompanhamento de documentos e orientações necessários ao atendimento |
| Confirmação de presença | Registro de intenção de comparecimento e de barreiras informadas pelo usuário |
| Lembretes | Criação de lembretes demonstrativos relacionados aos atendimentos |
| Perfil e informações pessoais | Edição de dados de identificação, contato e endereço fictícios |
| Medicamentos, alergias e histórico | Registro e consulta de informações demonstrativas de saúde |
| Relato pré-consulta | Preparação do que o paciente deseja comunicar, com entrada por texto ou áudio |
| Transcrição de áudio | Gravação com permissão do dispositivo, transcrição e revisão antes do uso |
| Complemento guiado por IA | Até três perguntas adaptativas para esclarecer pontos do relato, com opção de pular |
| Resumo organizado por IA | Organização do relato em seções, sem diagnóstico e com edição humana |
| Perguntas para a consulta | Sugestões neutras que podem ser selecionadas, editadas ou complementadas pelo usuário |
| Revisão final | Conferência e conclusão da preparação, com atualização de progresso |
| Notificações e acessibilidade | Preferências, alto contraste, escala de texto, temas e leitura por voz local |
| Portal de agendamentos | Operador autenticado pode localizar pacientes fictícios e gerenciar consultas e checklist |

## Estrutura dos componentes

| Componente | Descrição |
| ---------- | --------- |
| Flutter App | Interface Android e Web, navegação, formulários e jornada de preparação |
| Controllers e Repositories | Controle dos estados, regras de interface e acesso aos dados mockados ou à API |
| FastAPI | Endpoints REST, autenticação, validação e comunicação com os demais serviços |
| Services | Regras de negócio, autorização por titularidade, revisão de relatos e operações de IA |
| SQLAlchemy e Repositories | Persistência, consultas e isolamento dos dados no MySQL |
| Alembic | Versionamento das alterações da estrutura do banco de dados |
| OpenAI Provider | Transcrição, organização de relatos e perguntas complementares, quando habilitado |
| Portal Web | Interface em HTML, CSS e JavaScript para operação de agendamentos demonstrativos |
| Autenticação | JWT de paciente e credenciais de operador separadas, com senhas protegidas por Argon2id |
| Testes e documentação | Suítes automatizadas, contratos de API, relatórios de validação e registros do MVP |

## Conceitos aplicados

```txt
1. Desenvolvimento multiplataforma — Flutter para Android e Web
2. APIs REST                    — comunicação entre interfaces e backend
3. Arquitetura em camadas       — routers, schemas, services e repositories
4. Persistência relacional      — MySQL, SQLAlchemy e migrações com Alembic
5. Autenticação e autorização   — JWT, Argon2id e isolamento por usuário
6. Inteligência artificial      — transcrição, organização e perguntas guiadas
7. IA responsável               — limites clínicos e revisão humana obrigatória
8. Acessibilidade e UX          — contraste, tipografia, voz e linguagem simples
9. Segurança de dados           — TLS, CORS, validação de entrada e segredos no backend
10. Testes e validação          — testes automatizados e cenários com personas fictícias
11. Publicação de aplicações    — Firebase Hosting, Render e banco gerenciado
```

## Tecnologias

* **Flutter e Dart** — desenvolvimento do aplicativo Android e Web
* **GoRouter, HTTP e Record** — navegação, integração REST e captura de áudio no Flutter
* **Flutter TTS** — leitura por voz local para apoio à acessibilidade
* **Python 3.12+** — linguagem do backend
* **FastAPI, Uvicorn e Pydantic** — API HTTP, servidor e validação de dados
* **SQLAlchemy, PyMySQL e Alembic** — persistência e migrações do banco
* **MySQL (Aiven)** — banco de dados relacional gerenciado com conexão TLS
* **OpenAI API e SDK Python** — transcrição, organização do relato e complemento guiado
* **JWT e Argon2id** — autenticação, tokens e proteção de senhas
* **HTML, CSS e JavaScript** — Portal Web de Agendamentos e landing page
* **pytest, Ruff, Flutter Test e Node Test** — testes automatizados e análise de código
* **Render e Firebase Hosting** — hospedagem da API e publicação das interfaces Web

Aplicação composta por frontend, backend e portal. As interfaces demonstrativas estão disponíveis em [chega-junto-desafio-ia.web.app](https://chega-junto-desafio-ia.web.app) (paciente) e [chega-junto-agendamentos.web.app](https://chega-junto-agendamentos.web.app) (operador). A API demonstrativa é hospedada em [chega-junto-api.onrender.com](https://chega-junto-api.onrender.com). O acesso a recursos protegidos exige autenticação.

## Estrutura do projeto

```txt
Chega-Junto---Desafio-IA/
├── Design Telas ChegaJunto/
├── Identidade Visual/
├── Landing Page/
│   ├── assets/
│   ├── index.html
│   ├── script.js
│   └── style.css
├── chega_junto_app/
│   ├── android/
│   ├── assets/
│   ├── lib/
│   │   ├── app/
│   │   ├── core/
│   │   ├── data/
│   │   ├── features/
│   │   └── main.dart
│   ├── integration_test/
│   ├── test/
│   ├── web/
│   ├── pubspec.yaml
│   └── README.md
├── chega_junto_backend/
│   ├── app/
│   │   ├── api/
│   │   ├── core/
│   │   ├── database/
│   │   ├── models/
│   │   ├── repositories/
│   │   ├── schemas/
│   │   ├── services/
│   │   └── main.py
│   ├── docs/
│   ├── migrations/
│   ├── scripts/
│   ├── tests/
│   ├── .env.example
│   ├── pyproject.toml
│   ├── uv.lock
│   └── README.md
├── chega_junto_portal/
│   ├── assets/
│   ├── css/
│   ├── js/
│   ├── scripts/
│   ├── tests/
│   ├── index.html
│   ├── package.json
│   ├── serve.py
│   └── README.md
├── chega_junto_codex_context/
│   ├── docs/
│   ├── AGENTS.md
│   └── README.md
├── docs/
│   ├── qa/
│   ├── RELATORIO_IA_REAL_V8.md
│   └── RELATORIO_PREPARACAO_CONVERSACIONAL_V9.md
├── .gitignore
└── README.md
```

## Como usar

### Pré-requisitos

* Git, **Flutter SDK** compatível com Dart 3.11 e ambiente Android ou navegador Chrome
* **Python 3.12 a 3.14** e gerenciador de dependências **uv**
* Banco **MySQL 8** acessível, com usuário e certificado CA para TLS
* Variáveis locais de autenticação e conexão configuradas somente no backend
* Node.js para executar os testes do portal (opcional para uso do aplicativo)
* Chave da OpenAI e parâmetros do provedor **somente se desejar habilitar a IA real**

### Execução

```powershell
# Clone o repositório
git clone https://github.com/jeffsilva03/Chega-Junto---Desafio-IA.git

# Acesse o backend
cd Chega-Junto---Desafio-IA/chega_junto_backend

# Instale as dependências
uv sync --locked --dev

# Crie o arquivo de configuração apenas se ainda não existir
if (-not (Test-Path .env)) { Copy-Item .env.example .env }

# Edite o .env com as configurações locais de MySQL/TLS,
# CORS_ALLOWED_ORIGINS e uma AUTH_SECRET_KEY privada (mín. 32 bytes)

# Em um banco NOVO, após conferir o destino, aplique as migrations
uv run alembic upgrade head

# Inicie a API
uv run uvicorn app.main:app --host 127.0.0.1 --port 8000
```

Em **outro terminal**, execute o aplicativo Flutter com acesso à API local:

```powershell
# A partir da raiz do repositório
cd chega_junto_app

# Instale as dependências
flutter pub get

# Inicie no Chrome, com a origem Web permitida no CORS do backend
flutter run -d chrome --web-hostname=127.0.0.1 --web-port=5173 --dart-define=DATA_SOURCE=api --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

Para executar sem banco de dados ou API, o aplicativo também dispõe de **modo mock**, com informações fictícias e comportamento demonstrativo:

```powershell
cd chega_junto_app
flutter pub get
flutter run -d chrome --dart-define=DATA_SOURCE=mock
```

Os comandos utilizam **PowerShell no Windows**. Execute cada bloco na pasta indicada. O arquivo `.env` deve conter somente valores do seu ambiente e permanecer fora do Git. Não utilize o banco demonstrativo compartilhado para executar migrations, seeds ou testes destrutivos sem autorização.

A rota `http://127.0.0.1:8000/health` permite verificar a API, e `http://127.0.0.1:8000/docs` disponibiliza a documentação interativa dos endpoints habilitados. Recursos de pacientes exigem token Bearer JWT. No modo API, cadastre uma conta **fictícia** pelo aplicativo.

O **Portal de Agendamentos** possui operação autenticada e um simulador separado, exclusivamente local. Para executar e configurar cada modalidade, consulte [chega_junto_portal/README.md](chega_junto_portal/README.md). Para detalhes de variáveis, banco de dados e IA, consulte [chega_junto_backend/README.md](chega_junto_backend/README.md).

Os testes automatizados podem ser executados sem chamar a OpenAI real:

```powershell
# Backend (na pasta chega_junto_backend)
uv run pytest -q
uv run ruff check app scripts migrations tests

# Flutter (na pasta chega_junto_app)
flutter analyze
flutter test

# Portal (na pasta chega_junto_portal)
npm test
```

## Exemplos de uso

**Agenda e preparação para o atendimento:**

```txt
Consulte a data, o horário e a unidade da próxima consulta
Confira quais documentos e orientações estão pendentes
Marque os itens do checklist e registre a confirmação de presença
```

**Preparação do relato com inteligência artificial:**

```txt
Escreva o que deseja contar ao profissional de saúde
Ou grave um áudio e revise a transcrição antes de utilizá-la
Responda ou pule perguntas complementares e revise o resumo gerado
Selecione as perguntas que deseja levar à consulta
```

**Portal demonstrativo de agendamentos:**

```txt
Entre no portal com uma conta fictícia de operador
Localize um paciente fictício e crie um atendimento
Configure o checklist e consulte o agendamento no aplicativo
Edite ou cancele a consulta e atualize a agenda do paciente
```

## Limitações conhecidas

| Limitação | Descrição |
| --------- | --------- |
| Sistema não oficial | Não possui vínculo institucional nem integração com SUS, gov.br ou prontuários reais |
| Uso demonstrativo | Projetado para dados fictícios; não deve receber informações clínicas reais ou sensíveis |
| IA não clínica | Não diagnostica, prescreve, interpreta exames, classifica urgências ou substitui profissionais |
| Revisão humana | Resumos, transcrições e perguntas exigem conferência do usuário; não há envio automático ao SUS |
| IA e cotas | Recursos reais dependem de habilitação no backend, chave de API, disponibilidade e limites de uso |
| Áudio | Gravações dependem de permissão e suporte do dispositivo/navegador; há limites de duração e tamanho |
| Integração de presença | A confirmação é registrada na demonstração, sem comunicar a unidade de saúde |
| Notificações | Lembretes demonstrativos não equivalem a notificações push ou alarmes do sistema operacional |
| Sessão | Tokens do aplicativo ficam em memória; recarregar a página pode exigir novo login |
| iOS | O acesso pelo iPhone é via Flutter Web/Safari; não existe aplicativo iOS nativo distribuído |
| Portal simulador | O modo de simulação sem operador é restrito ao computador local e não deve ser publicado |
| Hospedagem | API e interfaces dependem dos provedores externos e de suas condições de disponibilidade |

> Essas limitações fazem parte do escopo do MVP acadêmico. Evoluções futuras podem incluir integração institucional autorizada, melhorias de acessibilidade e de comunicação, e validação com usuários reais em ambiente apropriado, respeitando privacidade, segurança e os limites do uso de IA na saúde.

---

<div align="center">

Desenvolvido por **Jefferson Silva, Yago Dias e Mateus Alcântara** para o **Desafio Salte com a IA**.

**Chega Junto — mais preparo, clareza e autonomia antes do atendimento.**

</div>

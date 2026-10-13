# Chega Junto

Projeto para o Desafio Salte com a IA. Reúne o aplicativo Flutter, backend FastAPI/MySQL, Portal Web, documentação oficial, protótipos aprovados, identidade visual e código-fonte da landing page. O checkpoint `V7` publica o Portal de Agendamentos autenticado, conectado ao Render/Aiven e ao aplicativo Flutter Web da V6. V1–V6 permanecem preservadas.

Flutter Web publicado em **https://chega-junto-desafio-ia.web.app**: Firebase Hosting Spark → FastAPI no Render → MySQL no Aiven. O Portal Simulador permanece local. Validação manual realizada com sucesso no Safari de um iPhone físico utilizando a URL pública HTTPS. Consulte o [relatório da publicação Web V6](docs/RELATORIO_DEPLOY_FLUTTER_WEB_V6.md).

## Organização

- `chega_junto_app/`: aplicativo Flutter para Android e Web, testes, assets e decisões de implementação.
- `chega_junto_backend/`: FastAPI, autenticação JWT, SQLAlchemy e MySQL/Aiven com TLS.
- `chega_junto_portal/`: Portal Web autenticado de agendamentos, com modo simulador local, em HTML/CSS/JavaScript.
- `docs/RELATORIO_PORTAL_SIMULADOR_V4.md`: implementação e validações automatizadas/manuais da V4.
- `chega_junto_codex_context/`: contexto e regras oficiais do projeto.
- `Design Telas ChegaJunto/`: protótipos de referência, incluindo telas ainda não implementadas.
- `Identidade Visual/`: referência da identidade do projeto.
- `Landing Page/`: código-fonte da landing page existente.

## Portal de Agendamentos

Portal de Agendamentos publicado em **https://chega-junto-agendamentos.web.app**, com autenticação própria de operador, namespace `/api/v1/operator` e segundo site Firebase. Migration, criação segura do operador, deploys, autenticação/isolamento e fluxo público de criação/checklist/edição/cancelamento aprovados. Recebimento de consulta no Safari de iPhone físico confirmado pelo usuário. Confira o [relatório V7](docs/RELATORIO_PORTAL_PUBLICO_V7.md). O simulador local abaixo continua separado e não será liberado na internet.

**AMBIENTE DEMONSTRATIVO — SISTEMA NÃO OFICIAL.** Ferramenta acadêmica local para buscar usuários fictícios e criar, visualizar, editar e cancelar agendamentos na mesma API usada pelo aplicativo. Não representa integração real com SUS ou gov.br. Não acessa prontuário ou dados clínicos e não está autorizado para exposição pública.

Veja [execução local de Backend, Portal, Flutter Web, Emulator e iPhone Web](chega_junto_portal/README.md), [contrato APP/SIMULATOR](chega_junto_backend/docs/API_CONTRACT_V4.md) e [relatório completo](docs/RELATORIO_PORTAL_SIMULADOR_V4.md).

## Aplicativo

O aplicativo possui 21 telas e um estado de processamento: Boas-vindas, Login, Home, Agenda, Detalhes da consulta, Checklist, Confirmação de presença, Perfil, Dados pessoais, Medicamentos e alergias, Histórico, Detalhes do histórico, Notificações, Configurações de notificações, Acessibilidade, Ajuda, Relato pré-consulta, Gravação de áudio simulada, Resumo organizado pela IA mockada, Perguntas para a consulta e Revisão final. Também permite criar lembretes demonstrativos. Os dados são fictícios, com referência em outubro de 2026. O modo mock mantém dados na sessão; o modo API persiste os dados no Aiven com isolamento por usuário.

Tema escuro, alto contraste, escala de texto e leitura por voz local estão disponíveis. O modo API possui cadastro/login reais, JWT e backend FastAPI/MySQL. IA real e integração com serviços de saúde não fazem parte desta fase. O fluxo de relato/IA utiliza serviços mockados, com revisão, edição e seleção de perguntas durante a sessão, sem envio externo.

Checkpoint oficial **V2**, de 8 de outubro de 2026: MVP funcional principal concluído e aprovado. São 76 testes aprovados, análise sem problemas e builds Web/Android concluídos. A jornada completa foi executada manualmente no emulador Android, incluindo Home em 100% e retorno a 75% após editar o relato. Veja o [relatório oficial V2](chega_junto_app/docs/RELATORIO_V2_MVP_FUNCIONAL_2026-10-08.md). Este parágrafo descreve a validação histórica V2. O checkpoint anterior V3 (`f7226bd4a45be38b25e159118ccc61b7a0b8f26d`) preserva a integração com autenticação/API; a entrega atual V4 está descrita no relatório do portal.

```powershell
cd chega_junto_app
flutter pub get
flutter run -d chrome
# Para Android, consulte o identificador disponível:
flutter devices
flutter run -d <identificador-do-dispositivo>
```

Validação:

```powershell
dart format .
flutter analyze
flutter test
```

Veja `chega_junto_app/README.md` para mais detalhes. Antes de alterar o produto, leia `chega_junto_codex_context/AGENTS.md` e os documentos oficiais.

## Versionamento

A raiz do repositório abrange todas as pastas acima. A tag `V1` identifica esta primeira versão salva. Builds, caches, capturas de validação, metadados Git aninhados, configurações locais de hospedagem e credenciais ficam fora do versionamento. A landing page pode ser aberta a partir de `Landing Page/index.html`; sua pasta `dist/` contém cópias geradas e não é versionada neste repositório.

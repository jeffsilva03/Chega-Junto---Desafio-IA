# Chega Junto

Projeto para o Desafio Salte com a IA. Reúne o aplicativo Flutter, a documentação oficial, os protótipos aprovados, a identidade visual e o código-fonte da landing page. A tag `V1` preserva a versão inicial.

## Organização

- `chega_junto_app/`: aplicativo Flutter para Android e Web, testes, assets e decisões de implementação.
- `chega_junto_codex_context/`: contexto e regras oficiais do projeto.
- `Design Telas ChegaJunto/`: protótipos de referência, incluindo telas ainda não implementadas.
- `Identidade Visual/`: referência da identidade do projeto.
- `Landing Page/`: código-fonte da landing page existente.

## Aplicativo

O aplicativo possui 21 telas e um estado de processamento: Boas-vindas, Login, Home, Agenda, Detalhes da consulta, Checklist, Confirmação de presença, Perfil, Dados pessoais, Medicamentos e alergias, Histórico, Detalhes do histórico, Notificações, Configurações de notificações, Acessibilidade, Ajuda, Relato pré-consulta, Gravação de áudio simulada, Resumo organizado pela IA mockada, Perguntas para a consulta e Revisão final. Também permite criar lembretes demonstrativos. Os dados são fictícios, com referência em outubro de 2026. O estado dura apenas a sessão.

Tema escuro, alto contraste, escala de texto e leitura por voz local estão disponíveis. Não há backend, autenticação real, IA real nem integração com serviços de saúde. O fluxo de relato/IA utiliza serviços mockados, com revisão, edição e seleção de perguntas durante a sessão, sem envio externo.

Checkpoint oficial **V2**, de 8 de outubro de 2026: MVP funcional principal concluído e aprovado. São 76 testes aprovados, análise sem problemas e builds Web/Android concluídos. A jornada completa foi executada manualmente no emulador Android, incluindo Home em 100% e retorno a 75% após editar o relato. Veja o [relatório oficial V2](chega_junto_app/docs/RELATORIO_V2_MVP_FUNCIONAL_2026-10-08.md). A tag `V1` permanece preservada.

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

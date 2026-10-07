# Chega Junto — V1

Versão inicial do projeto para o Desafio Salte com a IA. Reúne o aplicativo Flutter, a documentação oficial, os protótipos aprovados, a identidade visual e o código-fonte da landing page.

## Organização

- `chega_junto_app/`: aplicativo Flutter para Android e Web, testes, assets e decisões de implementação.
- `chega_junto_codex_context/`: contexto e regras oficiais do projeto.
- `Design Telas ChegaJunto/`: protótipos de referência, incluindo telas ainda não implementadas.
- `Identidade Visual/`: referência da identidade do projeto.
- `Landing Page/`: código-fonte da landing page existente.

## Aplicativo

O aplicativo possui Boas-vindas, Login, Home, Agenda, Detalhes da consulta, Checklist, Confirmação de presença, Perfil e criação de lembretes demonstrativos. Os dados são fictícios, com referência em outubro de 2026. O estado dura apenas a sessão.

Não há backend, autenticação real, IA real nem integração com serviços de saúde. Os destinos internos do Perfil e o restante da jornada aguardam implementação aprovada.

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

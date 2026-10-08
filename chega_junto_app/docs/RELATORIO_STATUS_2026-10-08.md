# Relatório de status — Chega Junto

**Data:** 8 de outubro de 2026.
**Marco atual:** checkpoint oficial **V2 — MVP funcional principal concluído**.
**Branch:** `main`. **Tag:** `V2` no commit deste checkpoint; `V1` preservada.
**Plataformas:** Android principal, Flutter Web complementar.

## Produto disponível

São **21 telas**, além do estado de processamento e do card Novo Lembrete: Splash, Login, Home, Agenda, Detalhes da consulta, Checklist, Confirmação de presença, Perfil, Dados pessoais, Medicamentos e alergias, Histórico, Detalhes do histórico, Notificações, Configurações de notificações, Acessibilidade, Ajuda, Relato pré-consulta, Áudio demonstrativo, Resumo organizado, Perguntas e Revisão final.

Todas as telas internas mantêm **Início | Agenda | Preparo | Perfil**. Preparo abre o checklist existente. Não há aba IA. Splash e Login preservam o fluxo de entrada aprovado.

```text
Splash → Login → Home → Agenda → Detalhes → Checklist → Confirmação
→ Relato → Áudio demonstrativo → Processamento → Resumo → Perguntas
→ Revisão final → Preparação concluída → Home 100%
```

O relato original é preservado durante a sessão. A transcrição somente entra por ação explícita do usuário. Resumo e perguntas continuam editáveis/removíveis; somente perguntas selecionadas aparecem na revisão. A organização mockada utiliza literalmente os parágrafos informados, sem inferência clínica. A revisão utiliza exclusivamente dados existentes.

A próxima consulta compartilhada é **9 de outubro de 2026, sexta-feira, 08:00, Consulta clínica / Clínica geral, Dra. Ana Beatriz Souza, UBS Centro**. A data fictícia de referência da demonstração é 7 de outubro de 2026. O histórico contém eventos passados distintos; diagnósticos ali exibidos são registros preexistentes.

Quatro macroetapas: documentos/preparo, presença, relato e revisão final. O mock inicia em **75% / 3 de 4**. Concluir a revisão com as demais concluídas atualiza para **100% / 4 de 4**, inclusive na Home. Alterar relato, resumo ou perguntas reabre a revisão e retorna a 75% nesse cenário. Documentos/presença pendentes não são concluídos por essa ação. Checklist possui progresso próprio sobre itens obrigatórios.

## Arquitetura e acessibilidade

A estrutura `app/`, `core/`, `data/` e `features/` mantém UI, modelos, serviços e repositórios separados. Controladores `ChangeNotifier` da sessão compartilham preparação, perfil, relato e voz; não há biblioteca adicional de estado. `AiAssistantService`, `AudioDraftService` e contratos de repositório permitem futuras substituições. Estado dura somente a sessão, sem persistência durável.

Temas claro/escuro/sistema, alto contraste, escala de texto, redução de animações, descrições, linguagem simples em telas de apoio, feedback tátil e leitura por voz local estão disponíveis. A reprodução depende de voz local em português e ainda não teve validação audível completa no Android. Testes cobrem semântica, toque e layouts com fonte ampliada; não constituem auditoria integral de acessibilidade.

Dependências permanecem `go_router 17.5.0`, `flutter_tts 4.2.5`, `cupertino_icons 1.0.9`, localização e ferramentas do SDK, além de `flutter_lints 6.0.0`. Fonte Nunito Sans local. Nenhuma nova dependência ou serviço pago foi adicionado no checkpoint.

## Validação V2

| Verificação | Resultado |
| --- | --- |
| `dart format .` | 91 arquivos verificados |
| `flutter analyze` | Sem problemas |
| `flutter test` | **76 testes aprovados** |
| `flutter build web` | Build JavaScript concluído |
| `flutter build apk --debug` | Build Android concluído |
| Android nativo | Jornada completa executada manualmente no emulador Android 16/API 36 |

A execução manual confirmou Home em 100%, retorno a 75% após alterar relato, preservação de texto/seleção, navegação, checklist/presença compartilhados, teclado e rolagem. Tema escuro, alto contraste e fonte grande foram inspecionados. Nenhum overflow foi encontrado nas telas conferidas. Capturas nativas locais em `.local/v2-android/`, ignoradas pelo Git.

A matriz automatizada inclui 320×568 com escalas 1,5 e 2,1, 390×844 e 1366×900, temas claro/escuro com e sem alto contraste, estado concluído e teclado. A suíte de integração Android existente foi atualizada na implementação da Revisão final; neste checkpoint, a jornada nativa foi manual, sem nova execução dessa suíte.

Foram corrigidos quatro problemas pontuais: FAQ desatualizada sobre IA, texto de recuperação de rota inválida, marca pouco legível no tema escuro e mensagem de envio incorporada à ilustração da Splash. Rotas e atalhos foram revisados; a recuperação de URL inválida foi preservada e testada. Não houve redesenho, refatoração ampla ou nova funcionalidade.

## Avisos e limites

- Três avisos de compatibilidade WebAssembly do `flutter_tts` permanecem no dry run. Build JavaScript aprovado; Wasm não é alvo deste MVP. Aviso de fonte CupertinoIcons ausente não retornou.
- Doctor: Flutter 3.41.4/Dart 3.11.1, licenças Android parcialmente pendentes e Visual Studio incompleto. Android compilou e executou; Windows Desktop está fora do escopo.
- Há 11 dependências com versões mais recentes fora das restrições atuais, conforme resolução anterior. Não foi feita atualização ampla.
- A instalação inicial no emulador encontrou código de versão maior e pouco espaço; o APK x64 com código de build local maior permitiu instalar sem apagar dados. A versão do projeto não foi alterada.
- Não houve validação em aparelho físico ou auditoria completa de TalkBack/voz. O runner complementar de widgets no Chrome não concluiu no checkpoint anterior; isso não é contado como aprovação atual. O build Web passou.

Sem IA real, backend, MySQL, autenticação real, gravação/transcrição reais, uploads ou integração com serviços de saúde. Login, documentos, suporte, cartão SUS e áudio têm comportamentos demonstrativos. Lembretes/notificações não programam alarmes/push. Presença não avisa unidade nem cancela/remarca consultas. Concluir não compartilha dados: **o usuário decide o que compartilhar**.

## Versionamento e documentação

Repositório: https://github.com/jeffsilva03/Chega-Junto---Desafio-IA. Mensagem do checkpoint: `feat: conclui fluxo principal do mvp`, na branch `main`. A tag anotada `V2` identifica o commit que contém este relatório; consulte o SHA com `git rev-parse 'V2^{}'`.

A tag `V1` permanece em `05cb43ece8f864f7d748d6e12f99e2b51f3795d3` (objeto anotado `2046752354033eb6cda3b6d468e4f59f0fd8dffd`). Referências e Landing Page não foram modificadas. O novo PNG de Revisão final fornecido pelo usuário é incluído no versionamento sem alteração. Builds, capturas, caches e segredos continuam ignorados.

- [Relatório oficial V2, com escopo, arquitetura, validações e limitações](RELATORIO_V2_MVP_FUNCIONAL_2026-10-08.md).
- [Registro da implementação da Revisão final](RELATORIO_REVISAO_FINAL_2026-10-08.md).
- [Entrega de relato e IA simulada](RELATORIO_RELATO_IA_2026-10-08.md).
- [Decisões de implementação e checkpoints](IMPLEMENTATION_DECISIONS.md).

**Desenvolvimento encerrado neste marco. Novas funcionalidades dependem de nova autorização.**

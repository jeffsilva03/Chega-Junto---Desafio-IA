# Chega Junto — MVP Flutter

Aplicativo local para apoiar a preparação antes de consultas e exames. Plataforma principal: Android. Flutter Web é complementar.

## Executar

```powershell
flutter pub get
flutter run -d chrome
flutter run -d emulator-5554
```

Abra esta pasta como projeto no Android Studio. O identificador do emulador pode variar; consulte `flutter devices`.

## Validar

```powershell
dart format .
flutter analyze
flutter test
```

Capturas locais opcionais dos testes de widgets:

```powershell
flutter test --dart-define=CAPTURE_QA=true
```

As capturas ficam em `.local/qa/`, fora do Git.

## Escopo implementado

- Boas-vindas (referência `splash.png`), login demonstrativo e Home.
- Agenda com busca, filtros, agrupamento por data e lembretes locais.
- Detalhes dos três atendimentos fictícios; checklist do próximo atendimento.
- Estado compartilhado: checklist e progresso geral permanecem consistentes ao navegar.
- Confirmação de presença com três respostas, salvamento local e orientações para procurar a unidade.
- Menu inferior fixo em todas as telas internas, incluindo Detalhes, Checklist e Confirmação. Splash e Login mantêm o fluxo de entrada aprovado.
- Perfil conforme `perfil.png`, com cartão SUS fictício e saída pela engrenagem.
- Dados pessoais editáveis: identificação, endereço e contato de emergência na mesma tela.
- Medicamentos e alergias: adicionar, editar e remover registros, com salvamento explícito.
- Histórico com filtros, detalhes por registro e prévias textuais de documentos demonstrativos.
- Notificações com filtros, leitura e configurações aplicadas à lista local.
- Acessibilidade: tamanho do texto, tema claro/escuro/sistema, alto contraste, leitura em voz alta, descrições de imagens, linguagem simples nas telas de apoio, feedback tátil e redução de animações.
- Ajuda com busca, respostas, tutoriais e suporte demonstrativo.
- Novo Lembrete conforme `novoLembrete.png`: card flutuante com título e opções 1 dia antes, 2 horas antes e No horário, relativas à próxima consulta.

Relato pré-consulta, áudio simulado, processamento demonstrativo, resumo editável, perguntas selecionáveis e Revisão final estão implementados. O fluxo pode ser aberto pela Home, pelos Detalhes da consulta ou pelo Preparo. Continuar nas perguntas abre a Revisão final; Concluir preparação salva o estado da sessão e conclui a quarta macroetapa, refletindo 100% na Home quando as demais estão concluídas. Editar relato, resumo ou perguntas reabre a revisão. Nada é enviado; o usuário decide o que compartilhar. O cartão SUS não possui tela de detalhes própria. Não há integração com serviços de saúde.

## Dados e limites

Use um e-mail fictício e senha fictícia com pelo menos quatro caracteres, ou o botão de Google simulado. Nenhuma credencial é enviada, validada por servidor ou persistida. A recuperação de acesso é uma demonstração e não envia e-mail.

Os dados e endereços são fictícios. A data de referência da demonstração é 7 de outubro de 2026, com próxima consulta em 9 de outubro às 08:00. Os lembretes, respostas de presença, checklist, dados do perfil, medicamentos, alergias, avisos lidos, relato, resumo revisado, perguntas e preferências duram apenas a sessão; reiniciar o aplicativo restaura os mocks. Adicionar lembrete não programa uma notificação do sistema. Salvar presença não avisa a unidade nem altera a consulta.

Não há backend, banco remoto, IA real, autenticação real, mapas externos ou serviços pagos. Orientações exibidas são conteúdo fictício previamente definido, não recomendações geradas por IA.

## Organização

```text
lib/
  app/          aplicação, sessão, rotas e tema
  core/         estado compartilhado, utilitários e componentes
  data/         modelos, contratos e repositórios mockados
  features/     páginas e widgets específicos de cada funcionalidade
assets/         recursos locais e licença da fonte
test/           navegação, responsividade, progresso e estado compartilhado
```

`PreparationRepository` e `ProfileRepository` permitem futura troca por APIs. `PreparationController` e `ProfileController` mantêm os dados compartilhados; salvar o nome atualiza Perfil e Home. `ReportController` mantém o rascunho fora das rotas e recebe `AiAssistantService` e `AudioDraftService`, substituíveis por implementações futuras via backend. Os mocks apenas reorganizam literalmente o texto e demonstram a transcrição, sem acessar o microfone. `SpeechController` depende de `SpeechEngine`, com implementações Android e Web substituíveis por fake nos testes. UI e modelos não dependem de um backend específico.

A leitura Android usa `flutter_tts` e o mecanismo instalado no aparelho. Na Web utiliza Web Speech API via Dart/JavaScript, selecionando somente vozes locais. Em ambas é necessária uma voz local em português. Sem ela, o aplicativo informa a indisponibilidade; não utiliza serviços remotos como alternativa. Nenhum conteúdo é enviado para uma API de voz. As preferências de notificação controlam a central interna e não programam notificações Android.

## Referências e identidade

As pastas externas de documentação, protótipos e Landing Page são fontes de referência e não devem ser editadas pelo aplicativo. A marca e a ilustração são renderizadas a partir de regiões de cópias dos PNGs aprovados; todos os controles e textos das telas são widgets Flutter. Um filtro de transparência aplicado somente ao logo remove o fundo branco visível sem modificar os originais.

Fonte local: Nunito Sans, licença SIL Open Font License em `assets/fonts/OFL.txt`. A família é uma aproximação visual, pois não foi fornecido o arquivo tipográfico dos protótipos. A fotografia do login deriva do PNG de baixa resolução disponível; um original em alta resolução permitirá refinamento futuro.

Dependências de execução: `go_router 17.5.0`, para navegação centralizada e URLs Web; [`flutter_tts 4.2.5`](https://pub.dev/packages/flutter_tts), licença MIT, para leitura pelo mecanismo de voz Android; e `cupertino_icons 1.0.9`, licença MIT, para fornecer a fonte de ícones referenciada internamente pelo SDK. São gratuitas. A inclusão da fonte corrige o aviso de família ausente sem alterar o design das telas. `flutter_localizations` pertence ao SDK; `flutter_lints` e `flutter_test` são usados na validação. `integration_test`, também do SDK, foi acrescentado apenas como dependência de desenvolvimento para executar o fluxo e obter screenshots no emulador Android; não integra o aplicativo de produção. Não há bibliotecas de estado ou carregamento remoto de fontes.

Checkpoint oficial **V2**, de 8 de outubro de 2026: as 21 telas e o fluxo principal estão concluídos e aprovados estruturalmente. Foram aprovados 76 testes, análise e builds Web/Android. A jornada completa passou manualmente no emulador Android 16/API 36, incluindo 100% na Home e invalidação para 75% após editar o relato. O build Web JavaScript mantém três avisos do dry run WebAssembly de `flutter_tts`; Wasm não é alvo deste MVP. Consulte [o relatório oficial da V2](docs/RELATORIO_V2_MVP_FUNCIONAL_2026-10-08.md) e [o status atual](docs/RELATORIO_STATUS_2026-10-08.md). Nenhuma nova funcionalidade está autorizada.

## Git

O repositório abrange a pasta principal do projeto, incluindo este aplicativo e as referências, conforme decisão posterior do projeto. Builds, caches, capturas locais, configurações de máquina e segredos são ignorados. `pubspec.lock` deve ser versionado. A tag `V1` identifica a primeira versão salva e permanece intacta. A tag `V2` identifica o checkpoint do MVP funcional principal.

## Validar o fluxo de relato no Android

```powershell
flutter drive --driver=test_driver/report_flow_driver.dart --target=integration_test/report_flow_test.dart -d emulator-5554
flutter build web
flutter build apk --debug
```

Capturas nativas ficam em `.local/android-qa/`, ignoradas pelo Git. O teste utiliza exclusivamente dados fictícios e a organização mockada. O APK gerado por `flutter drive` inicia o teste; execute `flutter build apk --debug` após ele para gerar novamente o APK normal de demonstração.

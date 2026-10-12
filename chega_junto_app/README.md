# Chega Junto — Flutter

Aplicativo para apoiar a preparação antes de consultas e exames, com modos **mock** (sem backend) e **api** (FastAPI local ou Render HTTPS → Aiven MySQL). Plataformas: Android e Flutter Web. A interface da V2 foi preservada. Consulte [o relatório da integração V3](docs/RELATORIO_INTEGRACAO_API_V3.md) para a base de integração e [o relatório V5](../docs/RELATORIO_DEPLOY_RENDER_V5.md) para o backend publicado, validações e pendências operacionais.

## Cadastro e autenticação — Fase 4

No modo **api**, “Criar conta” abre Cadastro com nome, e-mail, senha e confirmação, reutilizando fotografia, marca, formulário e estilos do Login. Use somente dados fictícios e e-mail de teste. Senha de 8–128 caracteres; confirmação fica somente na UI. O cadastro entra automaticamente na Home; o Login envia e-mail/senha ao FastAPI e usa JWT Bearer. Google fica desabilitado e recuperação de senha informa que ainda não está disponível.

`AuthRepository` possui MockAuthRepository e ApiAuthRepository. A sessão (`DemoSession`, nome histórico mantido) resolve estado inicial, identidade autenticada e saída. `AuthTokenStore` usa memória no Android e Web: fechar/reiniciar ou recarregar a página exige login novamente. Não há senha, token, segredo JWT ou credencial Aiven em assets/dart-defines/arquivos locais do Flutter. JWT expira em 60 minutos; não há refresh nesta fase.

No Perfil, engrenagem → **Sair da conta** remove token, cancela pedidos/autosave/TTS e descarta controllers/repositories/caches de perfil, saúde, preparo, relato, notificações e preferências. 401 de produto faz o mesmo e mostra “Sua sessão expirou. Entre novamente.” Requisições de uma sessão antiga não usam o token da próxima conta. 401 de Login mostra credenciais inválidas; não há fallback para mock.

Conta nova começa sem consultas, saúde, histórico, relatos, lembretes ou notificações. Perfil contém nome/e-mail, demais dados opcionais vazios (“Não informado”), SUS sem número e nenhuma unidade agendada. Editar dados pessoais permite manter campos opcionais vazios. Preferências recebem defaults oficiais.

No modo **mock**, Login/Google/recuperação/cadastro são demonstrativos, sem HTTP, token ou backend. Nenhuma conta é criada no Aiven. Leia o [relatório de autenticação backend](../chega_junto_backend/docs/RELATORIO_AUTENTICACAO_V3.md).

## Executar

```powershell
flutter pub get
flutter run -d chrome --dart-define=DATA_SOURCE=mock
```

Abra esta pasta como projeto no Android Studio. O identificador do emulador pode variar; consulte `flutter devices`.

O padrão é `mock`. O modo é escolhido ao iniciar; API indisponível não provoca fallback. No modo API, `API_BASE_URL` é obrigatório e contém somente a origem HTTP/HTTPS do FastAPI, nunca credenciais de banco.

Backend, em outro terminal a partir da raiz do projeto:

```powershell
cd chega_junto_backend
uv run uvicorn app.main:app --host 127.0.0.1 --port 8000
```

Flutter, a partir desta pasta:

```powershell
# Web no PC: incluir http://127.0.0.1:5173 no CORS_ALLOWED_ORIGINS do .env local do backend
flutter run -d chrome --web-hostname 127.0.0.1 --web-port 5173 --dart-define=DATA_SOURCE=api --dart-define=API_BASE_URL=http://127.0.0.1:8000
# Android Emulator: escolher o device retornado por flutter devices
flutter run -d emulator-5554 --dart-define=DATA_SOURCE=api --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

Para iPhone/Web na mesma rede, usar estes comandos nas respectivas pastas:

```powershell
# chega_junto_backend
uv run uvicorn app.main:app --host 0.0.0.0 --port 8000
# chega_junto_app, outro terminal
flutter run -d web-server --release --web-hostname 0.0.0.0 --web-port 8080 --dart-define=DATA_SOURCE=api --dart-define=API_BASE_URL=http://IP_DO_PC:8000
```

Substituir `IP_DO_PC` pelo IPv4 do PC na rede local, acrescentar `http://IP_DO_PC:8080` à lista JSON `CORS_ALLOWED_ORIGINS` somente no `.env` local do backend e reiniciar o servidor. No Safari, abrir `http://IP_DO_PC:8080`. Não usar wildcard, não versionar IP particular nem credenciais. Nenhuma alteração automática de firewall é necessária à implementação; a rede precisa permitir acesso às portas utilizadas.

No Safari: Já tenho conta → Criar conta → preencher dados totalmente fictícios → confirmar cadastro → conferir Home/Perfil vazios → engrenagem do Perfil → Sair da conta → entrar com o mesmo e-mail/senha → conferir identidade. Recarregar a página também exige login. Para validar persistência de perfil, editar um campo fictício, salvar, sair/entrar e conferir; depois restaurar o valor original. Não usar dados de saúde reais.

Validação manual posterior da Fase 4, confirmada pelo usuário: Flutter Web aberto no Safari de um iPhone físico, com conexão ao FastAPI local e Aiven. Cadastro e login reais funcionaram, permitindo entrar no fluxo autenticado. O primeiro acesso exibiu uma versão/cache antiga do navegador; após recarregar/reabrir a versão atual, o cadastro funcionou normalmente, sem mudança funcional adicional no código. Esse teste complementa o smoke anterior na Web local; não foram fornecidos logs, tempos ou modelo do aparelho.

## Validar

```powershell
dart format .
flutter analyze
flutter test --dart-define=DATA_SOURCE=mock
flutter build web --dart-define=DATA_SOURCE=api --dart-define=API_BASE_URL=http://127.0.0.1:8000
flutter build apk --debug --dart-define=DATA_SOURCE=api --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

Capturas locais opcionais dos testes de widgets:

```powershell
flutter test --dart-define=CAPTURE_QA=true
```

As capturas ficam em `.local/qa/`, fora do Git.

## Escopo implementado

- Boas-vindas (referência `splash.png`), Login/Cadastro (demo ou API real) e Home.
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

Relato pré-consulta, áudio simulado, processamento demonstrativo, resumo editável, perguntas selecionáveis e Revisão final estão implementados. O fluxo pode ser aberto pela Home, pelos Detalhes da próxima consulta ou pelo Preparo. Continuar nas perguntas abre a Revisão final; Concluir preparação conclui a quarta macroetapa, refletindo 100% na Home quando as demais estão concluídas. Editar relato, resumo ou perguntas reabre a revisão. Em modo API, os salvamentos confirmados são persistidos e o progresso vem do backend; nada é enviado a profissionais, UBS ou SUS. O cartão SUS não possui tela de detalhes própria. Não há integração com serviços de saúde.

## Dados e limites

No mock, use e-mail/CPF fictício e senha fictícia de pelo menos quatro caracteres, ou Google simulado; nenhuma credencial sai do app. No API, cadastre uma conta fictícia com senha de 8–128 caracteres; senha é enviada ao backend FastAPI configurado (local ou Render HTTPS), que persiste hash Argon2id. Token permanece em memória no Flutter. Recuperação não envia e-mail em nenhum modo. O MVP não está liberado para dados reais sensíveis ou publicação em produção.

Os dados e endereços são fictícios. No modo mock, a referência é 7 de outubro de 2026, com próxima consulta em 9 de outubro às 08:00; alterações duram apenas a sessão. No modo API, dados e data de referência vêm do servidor e alterações confirmadas persistem no banco demo. Fechar antes da confirmação, falhas de rede e conflitos podem deixar rascunhos apenas em memória. Em 409, preserve o texto, recarregue e escolha explicitamente como continuar. Em timeout de lembrete, confira a Agenda antes de repetir. Adicionar lembrete não programa notificação do sistema. Salvar presença não avisa a unidade.

O modo mock funciona sem backend; o modo API requer FastAPI configurado, local ou Render HTTPS, e usa cadastro/autenticação reais desde a Fase 4. Na V5, o backend foi publicado para demonstração no Render. Não há IA real ou mapas externos. Orientações exibidas são conteúdo fictício previamente definido, não recomendações geradas por IA. Segredos Aiven e futuras chaves de serviços pertencem somente ao backend; `.env` e `ca.pem` permanecem ignorados pelo Git.

## Backend HTTPS no Render — V5

Backend demonstrativo disponível em https://chega-junto-api.onrender.com. Cadastro, login, perfil e persistência foram validados pelo Flutter Web; o usuário também confirmou login no Android. A origem Web exata autorizada para este smoke é `http://127.0.0.1:5173`. Execute no diretório deste aplicativo:

```powershell
flutter run -d chrome --web-hostname 127.0.0.1 --web-port 5173 --dart-define=DATA_SOURCE=api --dart-define=API_BASE_URL=https://chega-junto-api.onrender.com
flutter build web --dart-define=DATA_SOURCE=api --dart-define=API_BASE_URL=https://chega-junto-api.onrender.com
flutter build apk --debug --dart-define=DATA_SOURCE=api --dart-define=API_BASE_URL=https://chega-junto-api.onrender.com
```

O destino continua configurável por `--dart-define`; mock e API local permanecem disponíveis. Não adicionar URL fixa, credenciais do banco ou CA ao Dart. O Portal permanece local e o simulador deve ficar indisponível no Render. Consulte o [relatório V5](../docs/RELATORIO_DEPLOY_RENDER_V5.md) para configuração, resultados, limitações do plano Free e a substituição de credenciais pendente, informada ao usuário.

## Flutter Web publicado

URL principal: **https://chega-junto-desafio-ia.web.app**. Alternativa: https://chega-junto-desafio-ia.firebaseapp.com. Arquitetura: Flutter Web no Firebase Hosting Spark → HTTPS → FastAPI em https://chega-junto-api.onrender.com → TLS → Aiven MySQL. O Portal Simulador permanece local. A publicação é Web App/PWA, não aplicativo iOS nativo.

Build e deploy manual, nesta pasta, PowerShell:

```powershell
flutter build web --release --dart-define=DATA_SOURCE=api --dart-define=API_BASE_URL=https://chega-junto-api.onrender.com
firebase deploy --only hosting
```

O alias público está em `.firebaserc`; `firebase.json` publica somente `build/web`, com fallback SPA e revalidação dos arquivos de bootstrap/versionamento. Builds, cache `.firebase/` e sessão da CLI ficam fora do Git. Não há auto-deploy GitHub ou serviços Firebase adicionais configurados.

JWT continua somente em memória: reload completo ou fechamento exige novo login. Validação manual realizada com sucesso no Safari de um iPhone físico utilizando a URL pública HTTPS. Cadastro pelo domínio Firebase e persistência de perfil após novo login integram a validação V6. Resultados, limitações, comandos e evidências estão no [relatório de publicação Web](../docs/RELATORIO_DEPLOY_FLUTTER_WEB_V6.md).

## Organização

```text
lib/
  app/          aplicação, sessão, rotas e tema
  core/         configuração, cliente HTTP, estado, utilitários e componentes
  data/         modelos, contratos, mappers, ApiRepositories e mocks
  features/     páginas e widgets específicos de cada funcionalidade
assets/         recursos locais e licença da fonte
test/           navegação, responsividade, progresso e estado compartilhado
```

`AppDependencies` seleciona as implementações de `PreparationRepository`, `ProfileRepository`, `NotificationRepository` e `PreferencesRepository`. `PreparationController` e `ProfileController` mantêm estado compartilhado. `ReportController` reidrata o agregado completo e conserva revisões do servidor como strings; no modo API, salva alterações com debounce de 600 ms e ao navegar, preservando rascunho em conflito. Recebe `AiAssistantService` e `AudioDraftService`; os mocks reorganizam o texto e demonstram áudio sem acessar o microfone. `SpeechController` depende de `SpeechEngine`, com implementações Android/Web substituíveis por fake. HTTP fica no cliente/repositories, sem chamadas diretas nas telas. O perfil usa respostas canônicas; alterações passam pelo backend, nunca por conexão Flutter/MySQL.

A leitura Android usa `flutter_tts` e o mecanismo instalado no aparelho. Na Web utiliza Web Speech API via Dart/JavaScript, selecionando somente vozes locais. Em ambas é necessária uma voz local em português. Sem ela, o aplicativo informa a indisponibilidade; não utiliza serviços remotos como alternativa. Nenhum conteúdo é enviado para uma API de voz. As preferências de notificação controlam a central interna e não programam notificações Android.

## Referências e identidade

As pastas externas de documentação, protótipos e Landing Page são fontes de referência e não devem ser editadas pelo aplicativo. A marca e a ilustração são renderizadas a partir de regiões de cópias dos PNGs aprovados; todos os controles e textos das telas são widgets Flutter. Um filtro de transparência aplicado somente ao logo remove o fundo branco visível sem modificar os originais.

Fonte local: Nunito Sans, licença SIL Open Font License em `assets/fonts/OFL.txt`. A família é uma aproximação visual, pois não foi fornecido o arquivo tipográfico dos protótipos. A fotografia do login deriva do PNG de baixa resolução disponível; um original em alta resolução permitirá refinamento futuro.

Dependências de execução: `go_router 17.5.0`, para navegação centralizada e URLs Web; [`flutter_tts 4.2.5`](https://pub.dev/packages/flutter_tts), licença MIT, para leitura pelo mecanismo de voz Android; e `cupertino_icons 1.0.9`, licença MIT, para fornecer a fonte de ícones referenciada internamente pelo SDK. São gratuitas. A inclusão da fonte corrige o aviso de família ausente sem alterar o design das telas. `flutter_localizations` pertence ao SDK; `flutter_lints` e `flutter_test` são usados na validação. `integration_test`, também do SDK, foi acrescentado apenas como dependência de desenvolvimento para executar o fluxo e obter screenshots no emulador Android; não integra o aplicativo de produção. Não há bibliotecas de estado ou carregamento remoto de fontes.

Na V3, [`http 1.6.0`](https://pub.dev/packages/http) foi acrescentado para REST, cancelamento e transporte Web/Android. Testes da integração usam HTTP falso; não necessitam de backend nem fazem mutações no Aiven.

Checkpoint histórico **V2**, de 8 de outubro de 2026: as 21 telas e o fluxo principal foram aprovados estruturalmente, com 76 testes, análise e builds Web/Android. A jornada passou manualmente no emulador Android 16/API 36. O build Web JavaScript mantém três avisos do dry run WebAssembly de `flutter_tts`; Wasm não é alvo deste MVP. Consulte [o relatório oficial da V2](docs/RELATORIO_V2_MVP_FUNCIONAL_2026-10-08.md) e [o status daquele checkpoint](docs/RELATORIO_STATUS_2026-10-08.md). A integração autorizada da V3 está documentada no relatório desta fase.

## Git

O repositório abrange a pasta principal do projeto, incluindo este aplicativo e as referências, conforme decisão posterior do projeto. Builds, caches, capturas locais, configurações de máquina e segredos são ignorados. `pubspec.lock` deve ser versionado. A tag `V1` identifica a primeira versão salva e permanece intacta. A tag `V2` identifica o checkpoint do MVP funcional principal.

## Validar o fluxo de relato no Android

```powershell
flutter drive --driver=test_driver/report_flow_driver.dart --target=integration_test/report_flow_test.dart -d emulator-5554
flutter build web
flutter build apk --debug
```

Capturas nativas ficam em `.local/android-qa/`, ignoradas pelo Git. O teste utiliza exclusivamente dados fictícios e a organização mockada. O APK gerado por `flutter drive` inicia o teste; execute `flutter build apk --debug` após ele para gerar novamente o APK normal de demonstração.

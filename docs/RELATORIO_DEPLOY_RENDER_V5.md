# Chega Junto — deploy Render V5

Data: 12 de outubro de 2026. **Status: Live; fluxo Flutter → Render → Aiven validado para revisão.** O usuário autorizou o plano gratuito e confirmou o login Android. A substituição das credenciais envolvidas no incidente descrito abaixo permanece pendente por decisão explícita do usuário; a segurança operacional não deve ser considerada encerrada antes dessa substituição.

## Objetivo e limites

Publicar somente a FastAPI para demonstrar `Flutter → HTTPS → Render → TLS → Aiven MySQL`. O banco atual continua sendo a fonte canônica. O Portal permanece em `Portal local → FastAPI local → Aiven`, com endpoints de simulador indisponíveis no Render. Usar somente contas e dados fictícios.

O código efetivamente publicado é o checkpoint V4: `7453572a4bddc92d0fd35f1cd710b939d0f282a5`, na branch `main` de `jeffsilva03/Chega-Junto---Desafio-IA`. Nenhuma mudança funcional, dependência ou migration foi feita nesta fase. O deploy foi entregue inicialmente sem commit, push ou tag V5; seu fechamento Git foi autorizado posteriormente pelo usuário. V1–V4 permanecem históricas. Auto-Deploy permanece Off, portanto o checkpoint documental não altera o código em execução no Render.

## Configuração aplicada no serviço criado

| Campo | Configuração |
| --- | --- |
| Tipo / nome | Web Service / `chega-junto-api` |
| Origem | Git Provider; repositório privado existente, branch `main` |
| Root Directory | `chega_junto_backend` |
| Runtime | Python 3 nativo, sem Docker |
| Python | `PYTHON_VERSION=3.14.3` |
| uv | `UV_VERSION=0.10.8`, mesma versão validada localmente |
| Build Command | `uv sync --frozen --no-dev` |
| Start Command | `uv run --no-sync uvicorn app.main:app --host 0.0.0.0 --port $PORT` |
| Health Check Path | `/health` |
| Pre-deploy Command | Vazio; não executar migrations no startup |
| Auto-Deploy | Off, confirmado no formulário |
| Plano | Free, $0/mês, 0.1 CPU e 512 MB RAM; nenhum pagamento autorizado |
| Região | Oregon (US West); Aiven DigitalOcean SFO informado explicitamente pelo usuário, costa oeste dos EUA |
| URL pública | https://chega-junto-api.onrender.com |

Serviço: `srv-db6inv0m7kps73b5l790`. Primeiro deploy (cancelado): `dep-db6inv8m7kps73b5l8o0`, status confirmado **Canceled**. O log confirmou checkout V4, Python 3.14.3, uv 0.10.8 e instalação de 30 pacotes pelo comando previsto. O aviso de `VIRTUAL_ENV` foi não bloqueante: uv criou a `.venv` no diretório do backend. O primeiro deploy não chegou ao startup. O segundo deploy manual, `dep-db6iqag473hc73dhr5lg`, ficou **Live / Deploy succeeded** em 58 segundos, executando o commit V4 indicado acima, sem alteração de schema. FastAPI iniciou e os health checks retornaram 200.

Oregon foi escolhido por proximidade geográfica com SFO entre as regiões Render disponíveis, sem medição de latência ou inferência pelo hostname. [Regiões Render](https://render.com/docs/regions).

A documentação oficial confirma Python 3.14.3 e seleção por variável, além de suporte ao uv quando `uv.lock` está no diretório raiz do serviço. Pinamos a versão local validada do uv para reduzir diferenças. [Python](https://render.com/docs/python-version), [uv](https://render.com/docs/uv-version).

Os comandos são relativos ao Root Directory; arquivos fora dele ficam indisponíveis ao serviço. O bind usa `0.0.0.0` e a porta fornecida pela plataforma. [Monorepo](https://render.com/docs/monorepo-support), [Web Services](https://render.com/docs/web-services), [FastAPI](https://render.com/docs/deploy-fastapi).

## Environment Variables e Secret File

Valores secretos nunca devem aparecer neste relatório. Preencher diretamente no Dashboard; não importar o `.env` local inteiro, que contém configurações de desenvolvimento.

| Nome | Política para o Render |
| --- | --- |
| `PYTHON_VERSION`, `UV_VERSION` | Versões aplicadas acima |
| `APP_ENV` | `production` |
| `AUTH_MODE` | `jwt` |
| `DEMO_MODE`, `SIMULATOR_MODE` | `false` |
| `AUTH_SECRET_KEY` | Segredo forte independente, gerado/inserido somente no Render; não reutilizar o segredo local |
| `AUTH_ACCESS_TOKEN_EXPIRE_MINUTES` | `60` |
| `LOG_LEVEL` | `INFO` |
| `APP_TIMEZONE` | `America/Sao_Paulo` |
| `CORS_ALLOWED_ORIGINS` | `["http://127.0.0.1:5173"]`, somente para o smoke Web local |
| `DATABASE_HOST`, `DATABASE_PORT`, `DATABASE_NAME`, `DATABASE_USER`, `DATABASE_PASSWORD` | Valores atuais do `.env` ignorado; banco existente, sem duplicação |
| `DATABASE_SSL_MODE` | `VERIFY_IDENTITY` |
| `DATABASE_SSL_CA_PATH` | `/etc/secrets/ca.pem` |

Não configurar identidade demo como alternativa ao JWT. Manter os defaults atuais de `DATABASE_CONNECT_TIMEOUT`, `DATABASE_READ_TIMEOUT`, `DATABASE_WRITE_TIMEOUT`, `DATABASE_POOL_SIZE`, `DATABASE_MAX_OVERFLOW`, `DATABASE_POOL_TIMEOUT`, `DATABASE_POOL_PRE_PING` e `DATABASE_POOL_RECYCLE`, sem tuning preventivo.

Em Environment → Secret Files → Add Secret File, adicionar `ca.pem` com o CA local ignorado. A plataforma disponibiliza o arquivo em `/etc/secrets/ca.pem`. Não colocar conteúdo do CA no Git, em base64 ou no frontend. Salvar variáveis sem deploy, quando disponível, permite revisar o conjunto antes da publicação. [Variáveis e Secret Files](https://render.com/docs/configure-environment-variables).

O engine existente usa CA, `CERT_REQUIRED`, verificação de hostname e TLS mínimo 1.2. Segredos ficam no backend. Logs de erro existentes são sanitizados e o SQLAlchemy oculta parâmetros. Não modificar a allowlist Aiven sem autorização caso o Render encontre bloqueio.

## Validação local e resultados consolidados

| Verificação | Resultado em 12/10/2026 |
| --- | --- |
| `uv sync --frozen --no-dev` | Aprovado, 30 pacotes em venv isolada ignorada `.local/render-venv`; Python 3.14.3, uv 0.10.8; lockfile preservado |
| Start Command com porta fornecida pelo ambiente | Aprovado em processo temporário local; `uv run --no-sync uvicorn` iniciou e encerrou normalmente |
| `uv run pytest -q` | 325 aprovados; um aviso de depreciação Starlette/TestClient/httpx |
| Ruff check / format check | Aprovados; 81 arquivos já formatados |
| `compileall` | Aprovado |
| `uv run alembic current` | `20261012_0003 (head)` |
| `uv run alembic check` | Sem operações pendentes |
| `dart format .` | 119 arquivos, nenhuma alteração |
| `flutter analyze` | Sem problemas |
| Testes Flutter mock | 162 aprovados |
| Testes Portal | 18 aprovados |
| Android | AVD `Emulador`, `emulator-5554`, Android 16/API 36, iniciado com a API HTTPS Render; usuário confirmou login normal |
| Auditoria de arquivos versionáveis, incluindo documentação nova | 326 arquivos verificados; nenhuma ocorrência de segredo real ou IP particular; `.env`, `ca.pem` e `.local/` ignorados |

Ensaio **local**, sem mutações no banco, com `APP_ENV=production`, JWT, demo/simulador desligados e CORS exato: `/health` 200 com `status=ok` e `database=ok`; `/docs` e `/openapi.json` 200; Bearer no OpenAPI; zero rotas simulator no contrato; simulator appointments 404; perfil sem token 401 com `WWW-Authenticate: Bearer`; CORS retornou apenas a origem permitida. Este ensaio usa a conexão local existente e **não comprova conectividade Render → Aiven**. Não gera nem reutiliza segredo local para o deploy.

O processo temporário foi encerrado. Os três serviços de demonstração local existentes nas portas 8000, 8080 e 5500 foram preservados.

## Validação pública HTTPS real

| Verificação | Resultado |
| --- | --- |
| `/health` | 200, `status=ok`, `database=ok`; comprova Render → Aiven |
| `/docs` | 200 |
| `/openapi.json` | 200, Bearer documentado, 32 operações APP e health; zero rotas simulator |
| `/api/v1/simulator/appointments` | 404 |
| `/api/v1/me/profile` sem token | 401, `WWW-Authenticate: Bearer` |
| CORS, origem autorizada | Origem exata `http://127.0.0.1:5173` retornada |
| CORS, origem fictícia não autorizada | Nenhum `Access-Control-Allow-Origin` |

Requests HTTPS usaram validação normal de certificado. `APP_ENV=production`, `AUTH_MODE=jwt`, `DEMO_MODE=false`, `SIMULATOR_MODE=false`; guards existentes preservados. Nenhuma allowlist ou proteção Aiven foi alterada. O repositório privado permaneceu privado, com a conexão GitHub já existente.

## Smoke Flutter Web → Render → Aiven

Aplicativo normal em `http://127.0.0.1:5173`, `DATA_SOURCE=api`, com URL HTTPS via `--dart-define`, sem alteração Dart ou fallback mock.

1. Criada **uma única conta fictícia adicional** em `example.test`, pela interface Flutter, mediante autorização do usuário. Senha aleatória mantida apenas em memória durante o teste, sem arquivo, comando, relatório ou valor literal salvo.
2. Cadastro concluiu e abriu Home. Login/Bearer e resolução canônica por `/auth/me` funcionaram no fluxo existente do aplicativo.
3. Perfil aberto; somente o nome fictício foi editado de `Pessoa Teste Render V5` para `Pessoa Teste Render V5 Persistido` e salvo.
4. Logout retornou ao Login. Novo login abriu Home e Perfil com o nome alterado, comprovando persistência remota e nova leitura do Aiven.
5. Home, Agenda, Preparo, notificações e preferências abriram normalmente: conta nova com zero consultas/lembretes/notificações e nenhum próximo atendimento, sem dados inventados.
6. Logs Render confirmaram GET 200 de appointments, reminders, profile, preparation/overview, notification-preferences, accessibility-preferences e notifications, além de PUT profile 200. Foram consultados somente métodos, paths e status, sem bodies ou tokens.

Não houve seed, criação de consulta pelo Render ou publicação do Portal. Detalhes com consulta existente não foram exercitados nessa conta vazia; permanecem cobertos pelos testes e pelo smoke histórico V4, sem alegar nova validação visual com dados nesta etapa. Nenhum CPF, SUS, endereço ou saúde real foi usado. Evidência de persistência em `.local/render-qa/persistence.png`, ignorada.

## Android, builds e repetição dos checks

AVD `Emulador`, dispositivo `emulator-5554`, Android 16/API 36, iniciado com o APK normal e a URL HTTPS Render. O usuário entrou com conta fictícia e confirmou: **“fiz o login, funcionou normal”**. A validação autenticada Android foi realizada pelo usuário; a janela nativa não foi observada pelo agente.

`flutter run` encontrou versionCode 4004 de uma instalação anterior, superior ao versionCode 1 do APK normal, e reinstalou o app no emulador. Isso afeta estado local do app, sem alteração nos dados Aiven. O app iniciou e o login funcionou após a reinstalação.

Builds com `https://chega-junto-api.onrender.com` aprovados:

- Web JavaScript: `chega_junto_app/build/web`.
- APK debug normal: `chega_junto_app/build/app/outputs/flutter-apk/app-debug.apk`.

Todos os checks locais da tabela acima foram repetidos após o deploy e no fechamento do checkpoint: **325 backend, 162 Flutter, 18 Portal**, Ruff/format/compileall aprovados, analyze sem problemas, 119 arquivos Dart sem alteração, Alembic `20261012_0003 (head)` e sem operações pendentes. Último pytest: 45,60 segundos. Nenhuma migration nova, upgrade, downgrade ou seed. Fixtures existentes preservadas; única mutação da fase de deploy: conta fictícia e seu perfil. No fechamento Git, as checagens da API publicada foram somente de leitura: health/OpenAPI/docs 200, perfil sem token 401/Bearer, simulator 404 e CORS exato. Nenhuma conta ou dado foi criado/alterado para o checkpoint.

Warnings não bloqueantes: Starlette/TestClient/httpx nos testes; três avisos `flutter_tts` no dry run Wasm, com alvo JavaScript aprovado; aviso uv de `VIRTUAL_ENV` diferente, com `.venv` correta criada no backend; mensagens de desempenho/engine do emulador no startup; aviso Flutter Web de substituição da meta viewport existente. Console Web: zero erros críticos, um aviso viewport. Nenhuma dependência, proteção TLS ou timeout foi alterado.

## Flutter: execução e builds com a URL confirmada

No diretório `chega_junto_app`, usando o serviço HTTPS confirmado:

```powershell
flutter run -d chrome --web-hostname 127.0.0.1 --web-port 5173 --dart-define=DATA_SOURCE=api --dart-define=API_BASE_URL=https://chega-junto-api.onrender.com
flutter build web --dart-define=DATA_SOURCE=api --dart-define=API_BASE_URL=https://chega-junto-api.onrender.com
flutter build apk --debug --dart-define=DATA_SOURCE=api --dart-define=API_BASE_URL=https://chega-junto-api.onrender.com
flutter devices
# Se houver Android, substituir ID_DO_DISPOSITIVO pelo ID listado:
flutter run -d ID_DO_DISPOSITIVO --dart-define=DATA_SOURCE=api --dart-define=API_BASE_URL=https://chega-junto-api.onrender.com
```

Mock e API local continuam disponíveis por `--dart-define`, sem alteração em Dart. Android nativo não depende de CORS. iPhone Web não é obrigatório; eventual origem temporária `http://IP_DO_PC:8080` deve existir apenas no ambiente Render enquanto necessária e ser removida depois. Nenhuma credencial Aiven ou CA pertence aos builds.

## Plano gratuito e operação futura

Free foi utilizado para demonstração acadêmica, sem cartão ou contratação paga. A documentação não o recomenda para produção: dorme após 15 minutos sem tráfego e pode demorar cerca de um minuto para acordar. Há 750 horas mensais por workspace, limites de banda/build, filesystem efêmero e possibilidade de suspensão por tráfego de saída elevado, inclusive banco externo. Não há disco persistente, shell/SSH ou jobs avulsos. Sem método de pagamento, exceder cotas pode suspender serviços ou novos builds. Não adicionar cartão, contratar plano pago nem criar keep-alive. [Limitações Free](https://render.com/docs/free).

Dados persistem no Aiven existente. Não criar migration ou executar upgrade/downgrade/seed/startup migration nesta fase. A revisão 0003 já aplicada permanece intacta. Para futuras alterações de schema, executar migrations de forma controlada antes do deploy autorizado; Free não é motivo para improvisar migrations no startup.

Para futuros deploys autorizados, revisar commit e configurações, verificar Alembic, executar testes e usar Manual Deploy no serviço com Auto-Deploy Off. Não publicar mudanças locais não commitadas como se estivessem na branch remota. [Deploy manual](https://render.com/docs/deploys).

O `/health` existente consulta o banco. O Render considera HTTP health bem-sucedido quando recebe 2xx/3xx em até cinco segundos; isso foi confirmado no deploy real sem reduzir a segurança TLS. [Health Checks](https://render.com/docs/health-checks).

## Incidente na revisão do formulário e interação necessária

A leitura automática do DOM, feita imediatamente após clicar no primeiro deploy autorizado, retornou valores de campos que o Render mostrava visualmente como ocultos. Isso incluiu credenciais Aiven, segredo JWT recém-gerado e CA. Nenhum valor deve ser copiado para documentação, Git, logs locais ou frontend. Ocultação visual do Dashboard não garante ocultação em saídas de automação.

O primeiro deploy foi cancelado e o status Canceled foi verificado. O usuário foi informado e autorizou explicitamente retomar com as credenciais atuais, deixando a substituição para depois. A senha Aiven e o `AUTH_SECRET_KEY` permanecem com rotação pendente; nenhuma credencial foi alterada automaticamente. Quando substituir a senha, atualizar o `.env` local ignorado, o Render e demais clientes que compartilhem o usuário do banco. Não enviar valores ao chat. Novas leituras devem limitar-se a nomes/status ou aplicar sanitização antes de qualquer saída. Na retomada, o CA armazenado foi comparado em memória com o arquivo local: conteúdo idêntico e quebras de linha preservadas, sem imprimir o certificado.

## Auditoria pós-deploy e ponto de parada

Git e documentos foram inspecionados sem imprimir valores. `.env`, `ca.pem`, `.local/`, `build/` e `.dart_tool/` continuam ignorados. Comparação de valores reais locais em memória e padrões de credenciais/JWT/hashes/connection strings/PEM/IP particular realizada. Web e APK também são inspecionados separadamente, com entradas APK descomprimidas; nenhum segredo de backend ou variável `DATABASE_*` pertence ao frontend. Resultado: 41 arquivos Web e 159 entradas APK auditados, URL HTTPS Render encontrada em ambos, nenhuma credencial local/JWT literal/conteúdo CA/variável DATABASE_* ou segredo de backend encontrado. Ocorrências numéricas de IP no snapshot/engine foram confrontadas com o SDK original: constantes internas, sem IP pessoal introduzido pelo projeto. Git/documentos também passaram sem segredos ou IP particular.

Arquivos da entrega: este relatório criado, READMEs backend e Flutter atualizados. Apenas documentação versionável foi alterada. Scripts auxiliares, capturas e builds ficam em diretórios ignorados.

Portal permanece local. Mock e API local preservados. iPhone físico contra Render não foi testado nesta etapa opcional. O frontend Web continua servido localmente; Android acessa a API pública sem depender da porta 8000, firewall do notebook ou Wi-Fi compartilhado.

Ação manual pendente: substituir senha Aiven e JWT secret conforme o incidente acima. O CA público não requer substituição por esse motivo. Nenhuma credencial foi rotacionada automaticamente. Não confundir êxito funcional do deploy com encerramento dessa pendência.

O fechamento autorizado utiliza um único commit `chore: registra deploy do backend no Render V5`, na `main`, seguido de push da branch e tag anotada `V5` com mensagem `V5 - Backend publicado no Render`. V1–V4 são preservadas. O checkpoint inclui somente este relatório e os READMEs backend/Flutter; nenhum arquivo secreto ou artefato de build integra a entrega.

Sem alteração do serviço Render, publicação do Portal/Flutter Web, IA, OAuth, RBAC ou nova migration durante o fechamento. A rotação das credenciais continua pendente conforme decisão do usuário.

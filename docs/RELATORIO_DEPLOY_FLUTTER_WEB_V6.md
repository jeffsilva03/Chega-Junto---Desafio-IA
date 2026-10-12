# Chega Junto — publicação Flutter Web no Firebase Hosting

Data: 12 de outubro de 2026. **Status: V6 aprovada para fechamento oficial.** Flutter Web publicado, cadastro público e persistência validados; validação física Safari confirmada pelo usuário. O checkpoint autorizado usa commit `chore: publica Flutter Web no Firebase V6`, push da `main` e tag anotada `V6`, antes de qualquer implementação V7.

## Objetivo e arquitetura

Disponibilizar o Flutter Web por HTTPS, sem depender do notebook, porta 8080, firewall local, IP do PC ou mesma rede Wi-Fi.

```text
iPhone / navegador / desktop
          ↓ HTTPS
Firebase Hosting (Flutter Web / Web App / PWA)
          ↓ HTTPS + JWT próprio
FastAPI no Render
          ↓ TLS VERIFY_IDENTITY
Aiven MySQL existente
```

O Portal Simulador continua exclusivamente local. Android continua sendo Android; esta publicação não cria um aplicativo iOS nativo. Nenhuma mudança Dart, de tela, ícone, identidade visual, regra de negócio backend ou migration foi feita.

## Projeto, plano e publicação

| Item | Resultado |
| --- | --- |
| Firebase Project Name | `Chega Junto - Desafio IA` |
| Firebase Project ID | `chega-junto-desafio-ia` |
| Firebase Project Number | `40227348301` |
| Firebase Hosting Site ID | `chega-junto-desafio-ia`, site padrão confirmado pela CLI |
| Plano | Spark, sem billing e sem conta de cobrança vinculada |
| Confirmação de custo | API Cloud Billing, leitura de `billingInfo`: `billingEnabled=false`, sem vínculo de conta; nenhum pagamento habilitado |
| URL principal | https://chega-junto-desafio-ia.web.app |
| URL alternativa | https://chega-junto-desafio-ia.firebaseapp.com |
| Resultado do deploy | `Deploy complete!`; 40 arquivos públicos enviados somente de `build/web` |
| Backend | https://chega-junto-api.onrender.com |
| Base Git | `main`, `d26b32bc247bad4fcea1e97755fb1f4ec1c9ab69` (V5) |

O nome visual sugerido com travessão foi recusado pelo Google (`INVALID_ARGUMENT`, caracteres inválidos em `display_name`). O hífen simples foi aceito, mantendo o ID profissional solicitado. Nenhum projeto existente de outro produto foi reutilizado.

A CLI criou o projeto e inicializou somente Hosting clássico. Analytics, Firebase Auth, Firestore, Realtime Database, Storage, Functions, Cloud Run e App Hosting não foram configurados. Nenhum SDK Firebase foi adicionado ao Flutter. GitHub automatic builds/deploys e instalação de agent skills foram recusados no init. O `build/web/index.html` existente não foi sobrescrito. Gemini e telemetria opcionais da CLI foram recusados no login.

## Ferramentas e documentação consultada

- Flutter **3.41.4 stable**, Dart **3.11.1**; SDK existente preservado.
- Node **22.22.0**, npm **10.9.4**; Firebase CLI oficial **15.33.0**, instalada com `npm install -g firebase-tools@15.33.0 --no-audit --no-fund`.
- O guia geral da CLI informa Node 18 ou superior; o pacote efetivamente instalado declara `>=20.0.0 || >=22.0.0 || >=24.0.0`. O Node local atende ao requisito do pacote. [Firebase CLI](https://firebase.google.com/docs/cli).
- Hosting clássico serve um diretório estático, aceita rewrite SPA e publica os dois subdomínios com HTTPS. [Quickstart](https://firebase.google.com/docs/hosting/quickstart), [configuração](https://firebase.google.com/docs/hosting/full-config).
- Spark dispensa informação de pagamento; o Hosting possui cotas gratuitas. Sem Blaze, exceder cotas pode impedir novos deploys ou suspender o site; não há autorização para upgrade automático. Consultar as cotas vigentes no Console. [Planos](https://firebase.google.com/docs/projects/billing/firebase-pricing-plans), [cotas Hosting](https://firebase.google.com/docs/hosting/usage-quotas-pricing).
- A documentação Flutter atual distingue bootstrap, build estático, cache e service worker. A saída do SDK instalado foi inspecionada diretamente, sem presumir que ele tenha o mesmo comportamento de versões anteriores. [Deploy Web](https://docs.flutter.dev/deployment/web), [Web FAQ](https://docs.flutter.dev/platform-integration/web/faq), [inicialização](https://docs.flutter.dev/platform-integration/web/initialization).

Avisos da instalação npm: deprecações transitivas de `node-domexception`, `json-ptr`, `uuid` e `glob`. Nenhuma dependência do aplicativo foi atualizada por isso.

## Build final e dados

Executado em `chega_junto_app`, PowerShell:

```powershell
flutter pub get
dart format .
flutter analyze
flutter test --dart-define=DATA_SOURCE=mock
flutter build web --release --dart-define=DATA_SOURCE=api --dart-define=API_BASE_URL=https://chega-junto-api.onrender.com
```

O build release foi gerado novamente após os checks e enviado no deploy final. `flutter clean` não foi necessário. A configuração continua em `String.fromEnvironment`; repositories não receberam URL fixa. Mock, API local e API Render permanecem selecionáveis. `API_BASE_URL` é pública; nenhum segredo foi passado como dart-define.

SHA-256 de `main.dart.js` publicado, comparado em memória com o arquivo local final e **idêntico**:

```text
801D0188BB02DD312BAC230CA07CFBEFB35BDEE41D33B929C905919B8A7FF120
```

Permanecem os três avisos conhecidos do dry run WebAssembly de `flutter_tts 4.2.5`. O alvo publicado é JavaScript e compilou normalmente; nenhuma opção foi acrescentada para esconder esses avisos.

## firebase.json final e SPA

Configuração em `chega_junto_app/firebase.json`:

```json
{
  "hosting": {
    "public": "build/web",
    "ignore": [
      "firebase.json",
      "**/.*",
      "**/node_modules/**",
      "**/*.map"
    ],
    "headers": [
      {
        "source": "/",
        "headers": [{ "key": "Cache-Control", "value": "no-cache" }]
      },
      {
        "source": "**/!(*.*)",
        "headers": [{ "key": "Cache-Control", "value": "no-cache" }]
      },
      {
        "source": "/@(index.html|flutter_bootstrap.js|flutter.js|main.dart.js|version.json|manifest.json|flutter_service_worker.js)",
        "headers": [{ "key": "Cache-Control", "value": "no-cache" }]
      }
    ],
    "rewrites": [{ "source": "**", "destination": "/index.html" }]
  }
}
```

O app conserva hash routing. O fallback SPA também atende paths diretos: `/perfil` e `/agenda` retornaram HTML Flutter, HTTP 200. A regra global de rewrite pode devolver o HTML para um asset inexistente; os assets reais foram verificados por status e Content-Type. Não houve troca da estratégia de navegação.

`.firebaserc` contém exclusivamente o alias público:

```json
{ "projects": { "default": "chega-junto-desafio-ia" } }
```

## Cache, Safari e service worker

`no-cache` permite armazenar, mas exige revalidação, reduzindo bootstrap obsoleto entre deploys. Aplica-se à raiz, paths sem ponto usados como rotas SPA e aos arquivos explícitos de entrada/versionamento acima. `main.dart.js` e `flutter.js` também revalidam porque seus nomes não contêm hash. Nenhum `no-store` global foi aplicado; os demais assets mantêm o cache padrão do Hosting. [Headers Hosting](https://firebase.google.com/docs/hosting/full-config#headers), [cache](https://firebase.google.com/docs/hosting/manage-cache).

Confirmação HTTP **no site público**:

| Recurso | Status | Cache-Control |
| --- | --- | --- |
| `/`, `/perfil`, `/agenda`, `/index.html` | 200 | `no-cache` |
| `/flutter_bootstrap.js`, `/main.dart.js` | 200 | `no-cache` |
| `/version.json`, `/manifest.json`, `/flutter_service_worker.js` | 200 | `no-cache` |
| `/favicon.png`, quatro ícones 192/512 e maskable | 200 | `max-age=3600` |
| `/assets/FontManifest.json` | 200 | `max-age=3600` |
| Domínio `firebaseapp.com`, raiz | 200 | Site alternativo disponível |

O SDK gerou `flutter_service_worker.js`, **815 bytes**, idêntico ao stub do SDK: registra install/activate para desregistrar service workers antigos e navegar novamente nos clientes. Ele não é um cache offline novo. Foi preservado e recebeu `no-cache`. Nenhum service worker manual foi criado, e não há promessa de funcionamento offline.

O servidor oficial local `firebase serve` serviu os arquivos e o SPA corretamente, mas não retornou os headers customizados neste ambiente Windows. A inspeção da dependência oficial `superstatic` mostrou normalização de globs com barras Windows; a conferência determinante foi feita após o deploy, onde todos os headers da tabela foram recebidos corretamente.

## CORS e operação Render

Única alteração operacional: `CORS_ALLOWED_ORIGINS`.

```json
[
  "http://127.0.0.1:5173",
  "https://chega-junto-desafio-ia.web.app",
  "https://chega-junto-desafio-ia.firebaseapp.com"
]
```

A origem local existente foi revisada e preservada para o preview. Não há wildcard. Outros valores e Secret Files não foram revelados ou editados. A leitura do painel foi limitada aos controles e à linha de CORS, cujo conteúdo é público.

Selecionado **Save and deploy**, reutilizando o build existente; deploy Render `dep-db6mgbks728c73cj54l0`, **Live**, gatilho Environment updated, duração exibida **21,2 s**, mesmo código `7453572a4bddc92d0fd35f1cd710b939d0f282a5` da V5. Não houve rebuild do backend nem mudança de build/start, autenticação, simulador, banco, CA ou plano. [Operação de variáveis Render](https://render.com/docs/configure-environment-variables).

| Check após CORS | Resultado |
| --- | --- |
| `GET /health` | 200; `status=ok`, `database=ok` |
| `GET /api/v1/simulator/appointments` | 404 |
| OPTIONS login das três origens permitidas | 200; devolve a origem exata |
| OPTIONS login de origem fictícia não permitida | 400; nenhum Access-Control-Allow-Origin |
| Preflights GET de profile, health-items, health-records e ambas preferências | 200; origem Firebase exata e Authorization permitido |

## Preview e validação desktop pública

Preview oficial:

```powershell
firebase serve --only hosting --host 127.0.0.1 --port 5173 --project chega-junto-desafio-ia --non-interactive
```

O servidor Flutter antigo que ocupava 5173 foi identificado como preview deste projeto usando Render e substituído temporariamente pelo servidor Firebase. Não houve alteração de firewall. Boas-vindas, Login, Cadastro e Home foram validados no build release local, com API HTTPS real.

Na publicação inicial foi criada **uma única conta inteiramente fictícia em `example.test` no preview**, persistida no Render/Aiven. Na preparação do fechamento V6, o usuário autorizou **um cadastro adicional pelo domínio público Firebase** para resolver a pendência específica. A jornada pública concluída está registrada abaixo. Ambas as senhas aleatórias foram mantidas somente em memória, sem gravação ou divulgação.

| Fluxo no Firebase público | Resultado |
| --- | --- |
| Boas-vindas / Login | Aplicação e identidade visual carregaram por HTTPS |
| Login | Mesma conta fictícia do preview autenticou; logs Render confirmaram POST login 200 e GET auth/me 200 |
| Home | Sem próximo atendimento e badge sem notificações; houve falha transitória inicial recuperada com Tentar novamente |
| Agenda | Todos/consultas/exames/lembretes = 0; estado vazio correto; sem fixture criada |
| Preparo | Mensagem de ausência de próximo atendimento; sem consulta inventada |
| Detalhes, checklist com itens, presença e relato de uma consulta | Não exercitados com dados nesta conta vazia; cobertura automatizada preservada |
| Perfil | Identidade fictícia e dados opcionais vazios; carga completa apresentou falhas transitórias e recuperou após retry |
| Gravação de perfil | Nome alterado de Pessoa Teste Web V6 para Pessoa Teste Web V6 Persistido; retorno canônico exibido |
| Logout e novo login / persistência | Aprovados; após nova autenticação da mesma conta, Perfil reidratado exibiu Pessoa Teste Web V6 Persistido, com necessidade de retry de leitura |
| Notificações | Central carregou com zero avisos e filtros existentes |
| Preferências de notificações | Tela carregou com defaults; nenhuma preferência alterada desnecessariamente |
| Acessibilidade | Tela e preferências existentes carregaram; nenhuma mudança de design ou de preferências |
| Refresh/reload completo | A rota `/#/perfil` recarregou o Flutter e retornou a `/#/login`, sem 404 ou tela branca; token em memória descartado conforme esperado. Nova recarga realizada após encerrar o servidor local |
| Console | Sem erro crítico/CORS/Mixed Content capturado; um warning de inicialização pertence à extensão do navegador, não ao app |
| Network | Build contém somente destino HTTPS Render; preflights e logs HTTP Render confirmam requests da jornada. O painel Network do DevTools não foi aberto pela ferramenta disponível |

As falhas transitórias da publicação inicial foram mostradas pelo app como “Não foi possível conectar”. Houve OPTIONS 200 e leituras GET 200 no Render; não foi determinado o motivo exato de todas as falhas de transporte. Não atribuir automaticamente ao banco, ao plano gratuito ou ao CORS. Nenhum ajuste preventivo de timeout, pool ou backend foi realizado. O usuário posteriormente confirmou bom funcionamento no Safari físico; as ocorrências iniciais ficam preservadas como histórico.

## PWA e iPhone físico

`web/index.html`, `web/manifest.json` e os quatro ícones existentes foram preservados. Manifest mantém Chega Junto, standalone, portrait, descrição, tema e ícones maskable. Manifest e ícones públicos retornaram 200 com Content-Type adequado.

**Confirmado pelo usuário no fechamento V6:** “Validação manual realizada com sucesso no Safari de um iPhone físico utilizando a URL pública HTTPS.” O usuário confirmou acesso sem depender do backend local, IP do notebook, porta 8080, firewall ou mesma rede Wi-Fi. Modelo, versão iOS, rede específica e tempos não foram registrados e não são inferidos.

**Opcional, não realizado:** Compartilhar → Adicionar à Tela de Início; verificar nome, ícone, standalone e login. A publicação é Web App/PWA, não iOS nativo.

Token permanece exclusivamente em memória. Reload completo ou fechamento pode exigir novo login; isso é comportamento conhecido e foi observado no reload da rota Perfil. Não foram implementados localStorage, cookies de sessão, secure storage ou refresh token.

O preview Firebase local foi encerrado e a ausência de listener em 5173 foi confirmada. A URL Firebase continuou iniciando o aplicativo após nova recarga. A aba pública foi mantida aberta em Login para o usuário; abas temporárias de preview/Render foram fechadas. A senha de smoke foi descartada da memória de automação após o teste, sem gravação em arquivo. Essa verificação desktop complementa, mas não substitui, o teste físico fora da LAN.

## Testes e auditoria

| Verificação nesta fase | Resultado |
| --- | --- |
| `flutter pub get` | Aprovado; lockfile e dependências do app preservados |
| `dart format .` | 119 arquivos; zero alterações |
| `flutter analyze` | Sem problemas |
| `flutter test --dart-define=DATA_SOURCE=mock` | 162 aprovados |
| `npm test`, Portal | 18 aprovados |
| `uv run pytest -q`, após CORS | 325 aprovados, 53,82 s; um warning conhecido de depreciação Starlette/TestClient/httpx |
| `uv run ruff check app scripts migrations tests` | Aprovado |
| `uv run ruff format --check app scripts migrations tests` | 81 arquivos já formatados |
| `uv run python -m compileall -q app scripts migrations` | Aprovado |
| `uv run alembic current` | `20261012_0003 (head)` |
| `uv run alembic check` | Sem novas operações de upgrade |
| Build Web release final | Aprovado; JavaScript publicado com SHA-256 igual ao local |
| Auditoria do build | 41 arquivos locais, 40 publicados; nenhuma ocorrência das variáveis DATABASE_*/AUTH_SECRET_KEY, Aiven, PEM, JWT fixo, Authorization Bearer literal ou strings localhost/127.0.0.1/192.168./10.0.2.2 |
| Comparação com valores reais locais em memória | Host/usuário/senha do banco e segredo JWT: zero ocorrências no build e nos 329 arquivos versionáveis; nenhum valor foi impresso |
| Source maps / arquivos indevidos | Zero `.map`, `.env`, PEM, logs ou arquivos backend/Portal no build; `.map` também ignorado preventivamente no Hosting |

`build/`, `.local/`, logs, `.env`, PEM e caches permanecem ignorados. Adicionada somente `/.firebase/` ao `.gitignore` Flutter para cache da CLI. `firebase.json` e `.firebaserc` permanecem versionáveis e não contêm credenciais. A sessão Firebase reside fora do projeto e não foi copiada para o repositório.

A pendência operacional de rotação de credenciais descrita no relatório V5 permanece separada e não foi alterada nesta fase. A auditoria limpa do frontend não encerra essa pendência histórica.

## Novo deploy manual

Na raiz do repositório, PowerShell:

```powershell
cd chega_junto_app
flutter pub get
flutter analyze
flutter test --dart-define=DATA_SOURCE=mock
flutter build web --release --dart-define=DATA_SOURCE=api --dart-define=API_BASE_URL=https://chega-junto-api.onrender.com
firebase deploy --only hosting
```

Se `firebase` ainda não estiver no PATH da sessão PowerShell após a instalação npm, usar:

```powershell
& "$env:APPDATA\npm\firebase.cmd" deploy --only hosting --project chega-junto-desafio-ia --non-interactive
```

Esse foi o executável utilizado nesta fase. Antes de publicar, revisar plano gratuito, CORS exato, health/simulador, build e auditoria; depois conferir HTTP, cache, assets e fluxos reais. Login oficial somente quando necessário; nenhuma credencial integra o comando de build/deploy. Não há auto-deploy, Functions, domínio personalizado ou arquivo secreto necessário para compilar o frontend.

## Arquivos e fechamento Git V6

Arquivos versionáveis desta fase: `chega_junto_app/firebase.json`, `chega_junto_app/.firebaserc`, `chega_junto_app/.gitignore`, este relatório e atualizações pequenas dos READMEs. Capturas de evidência ficam em `chega_junto_app/.local/firebase-qa/`, ignoradas.

V5 permanece no commit `d26b32bc247bad4fcea1e97755fb1f4ec1c9ab69`. As referências V1–V5 foram confrontadas com a leitura inicial e permanecem intactas; a tag anotada V5 continua com objeto `9124b81382a69b2e02b9fe8c1ae571ddf11182d6`. O fechamento V6 inclui somente os seis arquivos abaixo. Portal, backend e produto Flutter permanecem sem alterações de código. Builds, caches, logs, capturas e credenciais são excluídos do staging.

`git status` / `git status --short`: branch `main`, três arquivos modificados e três novos, todos sem staging. `git diff --check` sem problemas. `git diff --stat` dos arquivos já rastreados: três arquivos, 18 inserções; os três novos ainda não aparecem no stat convencional. Arquivos exatos:

```text
 M README.md
 M chega_junto_app/.gitignore
 M chega_junto_app/README.md
?? chega_junto_app/.firebaserc
?? chega_junto_app/firebase.json
?? docs/RELATORIO_DEPLOY_FLUTTER_WEB_V6.md
```

No fechamento, cadastro público e Safari físico foram resolvidos. Detalhes/Preparo com consulta e Add to Home Screen não foram repetidos nessa conta nova vazia; Add to Home Screen é opcional. O painel Network/DevTools não foi acessado pela ferramenta disponível; a evidência reúne console capturado, bytes publicados, preflights e logs HTTP do Render. A V7 terá seu próprio E2E com consulta, em checkpoint separado.

### Revalidação do fechamento em 12/10/2026

- Cadastro novo diretamente em `https://chega-junto-desafio-ia.web.app/`, com uma conta `example.test`: Home aberta, Perfil carregado, nome fictício alterado de `Pessoa Fictícia Firebase V6` para `Pessoa Fictícia Firebase V6 Persistido`, salvo; logout e novo login confirmaram a persistência no Perfil. Nenhum dado real, seed ou consulta foi acrescentado para este cadastro.
- Backend: **325 testes aprovados**, um warning conhecido TestClient/httpx; Ruff check/format (81 arquivos), compileall, Alembic `20261012_0003 (head)` e check sem operações pendentes.
- Flutter: **162 testes aprovados**, analyze sem problemas, format 119 arquivos sem alterações. Portal: **18 testes aprovados**.
- Raiz, manifest, bootstrap, ícones e FontManifest públicos retornaram 200. Bundle público preserva o SHA-256 acima e contém destino HTTPS Render. Health `status=ok`, `database=ok`; simulator 404; preflight de cadastro 200 com origem Firebase exata.
- Auditoria: 329 arquivos versionáveis e 41 arquivos do build, zero correspondências de valores reais de host/usuário/senha Aiven e segredo JWT. Build sem variáveis secretas, PEM, JWT literal, localhost ou IP local. Nenhum arquivo proibido entre os versionáveis.

O usuário autorizou explicitamente o fechamento V6 e a etapa V7 subsequente. A implementação V7 só pode começar após push da main e da tag V6; V6 deve continuar apontando para este estado anterior à autenticação de operador.

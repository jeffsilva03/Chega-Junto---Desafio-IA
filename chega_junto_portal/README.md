# Portal Web de Agendamentos

**AMBIENTE DEMONSTRATIVO — SISTEMA NÃO OFICIAL.** Portal acadêmico do Chega Junto, sem integração com SUS, gov.br ou sistemas governamentais. Usar somente dados fictícios de pacientes e agendamentos. O modo simulator continua exclusivamente local; modo operator publicado no Firebase. Migration, criação manual do operador, deploys, autenticação/isolamento, E2E desktop e recebimento no iPhone físico validados.

## Portal autenticado V7

Reutiliza esta aplicação, com login de operador e JWT próprio na FastAPI. Sem signup público/Firebase Auth. Token somente em memória: reload exige novo login. Logout e 401 limpam sessão, paciente, lista, editor e filtros; respostas antigas são descartadas. O operador pode identificar usuário por e-mail exato e gerenciar agendamentos/checklist, sem acesso a dados clínicos. Cadastro manual seguro explicado no [README backend](../chega_junto_backend/README.md#portal-autenticado--publicação-v7).

Segundo site publicado no projeto `chega-junto-desafio-ia`, Site ID `chega-junto-agendamentos`, target `portal`. URLs públicas https://chega-junto-agendamentos.web.app e https://chega-junto-agendamentos.firebaseapp.com. Os 11 arquivos publicados correspondem ao build local, com cache e headers conferidos; App Flutter permanece no site original com o hash V6.

Após backend V7 publicado e operador criado, na pasta portal:

```powershell
npm test
npm run build
firebase deploy --only hosting:portal --project chega-junto-desafio-ia
```

Build usa allowlist, sem dependências adicionais, copiando somente index.html/css/js/assets para dist ignorado. Firebase publica somente dist com target explícito. Não publicar a raiz da pasta. HTML/JS/CSS usam no-cache; assets max-age=3600, CSP/nosniff/no-referrer. Configuração separada preserva a publicação Flutter. Sem auto-deploy/PWA/service worker.

No domínio público, API é HTTPS Render e namespace `/api/v1/operator` com Bearer; não envia header simulator. Login aceita e-mail válido de qualquer domínio, inclusive `@gmail.com`, e senha de 8–128 caracteres, conforme o cadastro administrativo. Localmente, `serve.py --api-base http://127.0.0.1:8000 --mode operator` oferece o mesmo login contra API local explicitamente configurada. Backend local exige chave efêmera privada e flag de operador quando esse modo for testado; o segredo de produção permanece só no Render. O modo simulator exige `--mode simulator`, API/servidor loopback e os guards V4 abaixo.

[Contrato V7](../chega_junto_backend/docs/API_CONTRACT_V7.md) e [relatório completo V7](../docs/RELATORIO_PORTAL_PUBLICO_V7.md). Sem recuperação de senha/MFA/refresh/RBAC avançado/auditoria completa/cadastro de unidades. Login/logout/reload, teclado, busca, filtros, criação, checklist, edição e cancelamento conferidos publicamente; tokens cruzados recusados e consulta recebida no iPhone. Checkpoint V7 fechado após essas validações.

O operador localiza um usuário por e-mail, consulta agendamentos paginados, cria, visualiza, edita e cancela consultas. As unidades vêm de `facilities`. O portal só conversa com FastAPI; não possui driver, credenciais ou acesso ao MySQL. Flutter e portal compartilham a mesma fonte de verdade no Aiven.

## Estrutura

```text
chega_junto_portal/
  index.html            # interface semântica, aviso permanente, tabela/editor/dialog
  css/portal.css        # referência visual sistema web.png, desktop/tablet
  assets/               # marca ilustrativa, ícones SVG e fontes locais licenciadas
  js/api.js             # HTTP, configuração, timeout e erros sanitizados
  js/domain.js          # datas São Paulo, filtros, payload e loading
  js/app.js             # interação, paginação e edição
  tests/portal.test.js   # node:test, sem dependências
  serve.py              # servidor estático local + config.json dinâmico
  package.json
  README.md
```

## Executar localmente

Requisitos: Python/uv, Node para testes e Flutter para o aplicativo. Abra terminais separados na raiz do repositório. Configure o `.env` **somente no backend**, com TLS `VERIFY_IDENTITY`, certificado local e chave JWT já usados na V3. Não sobrescreva um `.env` existente. Nunca coloque esses valores no portal.

Backend:

```powershell
cd chega_junto_backend
uv sync --locked --dev
uv run alembic upgrade head
$env:SIMULATOR_MODE='true'
uv run uvicorn app.main:app --host 127.0.0.1 --port 8000 --no-proxy-headers
```

Portal, em outro terminal na raiz:

```powershell
uv run --project chega_junto_backend python chega_junto_portal/serve.py --api-base http://127.0.0.1:8000 --port 5500 --mode simulator
```

Abra `http://127.0.0.1:5500`. `--api-base` é obrigatório e gera `config.json` em memória: contém somente a origem pública da API. Não abra `index.html` com `file://`. O servidor aceita somente loopback; a porta adotada é 5500. Para outra porta, ajuste explicitamente `SIMULATOR_ALLOWED_ORIGINS` no backend. Preserve `CORS_ALLOWED_ORIGINS` do Flutter.

Flutter Web:

```powershell
cd chega_junto_app
flutter pub get
flutter run -d chrome --web-hostname=127.0.0.1 --web-port=8080 --dart-define=DATA_SOURCE=api --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

Android Emulator: mantenha o portal no PC. Para o emulador acessar a API, execute o backend com `--host 0.0.0.0 --no-proxy-headers` em uma rede local controlada, e depois:

```powershell
cd chega_junto_app
flutter devices
flutter run -d ID_DO_EMULADOR --dart-define=DATA_SOURCE=api --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

iPhone Web: na mesma rede Wi-Fi do PC, acrescente **a origem exata** `http://IP_DO_PC:8080` a `CORS_ALLOWED_ORIGINS`, preservando as demais. Backend com `--host 0.0.0.0 --no-proxy-headers`. Então:

```powershell
cd chega_junto_app
flutter run -d web-server --web-hostname=0.0.0.0 --web-port=8080 --dart-define=DATA_SOURCE=api --dart-define=API_BASE_URL=http://IP_DO_PC:8000
```

No Safari, abra `http://IP_DO_PC:8080`. Substitua `IP_DO_PC` localmente; não versione IP particular. Permita apenas as portas necessárias na rede privada do firewall. O operador continua usando o portal no PC: o simulador recusa clientes da LAN, inclusive o telefone. HTTP local não habilita todas as APIs de voz do Safari; este fluxo não depende delas. Não configura distribuição iOS nativa.

A validação manual final da V4 utilizou FastAPI em 8000, Flutter Web em 8080 e Portal em 5500. O usuário confirmou o fluxo completo após configurar permissões persistentes no firewall do Windows. Isso é configuração local de desenvolvimento, não requisito de produção; regras e IP da máquina não são versionados. O relato está no [relatório V4](../docs/RELATORIO_PORTAL_SIMULADOR_V4.md#validação-manual-final-informada-pelo-usuário).

## Controle do simulador

`SIMULATOR_MODE` é falso por padrão. Desabilitado: namespace retorna 404 antes de acessar banco e não entra no OpenAPI. `APP_ENV=production` com modo ativo falha na configuração. Ativo: exige conexão de loopback, Host local, origem na lista explícita quando presente e `X-Simulator-Request: local`. Esse header é **público, não é senha ou token**: obriga preflight no navegador e impede submissão simples de outra origem. A API normal do app continua exigindo seu JWT.

Use obrigatoriamente `--no-proxy-headers`: a verificação depende do peer real, não de `X-Forwarded-For`. Não coloque o simulador atrás de proxy, túnel ou servidor público. Não há autenticação de operador/RBAC: o limite de confiança é o PC local controlado. CORS sozinho não seria proteção suficiente; programas locais confiáveis também podem usar a API. Uma fase pública precisará de autenticação e autorização próprias antes de exposição.

Para encerrar: `Ctrl+C` nos servidores e, no terminal backend, `Remove-Item Env:SIMULATOR_MODE`. Não deixe o modo ativo permanentemente.

## Regras operacionais

- Busca retorna exclusivamente id, nome, e-mail e ativo. Não existem telas ou rotas do simulador para dados clínicos.
- A tabela usa páginas de 20 e filtros de paciente, dia, unidade, especialidade e status. Filtros são aplicados ao alterar a seleção ou após 400 ms de digitação; Enter também aplica. Unidades ativas são carregadas em páginas de 100.
- A composição visual segue `Design Telas ChegaJunto/sistema web.png`: cabeçalho institucional, barra lateral, cartões de paciente, tabela com ações em linha, editor lateral e mensagens no canto inferior. Navegação fora de Agendamentos, sino e Sair permanecem desabilitados: não representam módulos ou autenticação de operador implementados.
- Especialidade e profissional continuam campos de texto; as sugestões vêm somente dos registros da página atual. Contador de orientações respeita o limite real de 25.000 caracteres. O checklist usa descrição e obrigatoriedade existentes, sem inventar subtítulos clínicos ou dados do protótipo.
- Tipos canônicos: `consultation`, `exam`, `return`. Status: `scheduled`, `cancelled`, `completed`.
- Formulário interpreta data/hora em `America/Sao_Paulo`, envia instante com fuso e persiste UTC. Exemplo: 09:30 local → 12:30Z em outubro/2026.
- Consulta e checklist são uma transação. Checklist vazio é permitido; zero obrigatórios resulta em `documents_done=true`.
- PATCH não aceita proprietário. Checklist enviado substitui a composição; IDs existentes preservam conclusão se a descrição não mudou. Mudança de descrição reinicia a conclusão desse item. Itens opcionais não alteram percentual obrigatório.
- Somente agendadas podem ser editadas. Canceladas/concluídas são somente leitura. Cancelar é idempotente, preserva consulta e relações; não há DELETE de consulta nem botão de concluir.
- No app, use **Atualizar atendimentos** na Home/Agenda. Consulta cancelada continua na Agenda e deixa de ser próxima ativa. Sem polling ou WebSocket.
- Erro/timeout de escrita pode ter ocorrido após persistência: atualize a lista antes de repetir. O portal nunca repete POST automaticamente.

Contrato e validação: [API V4](../chega_junto_backend/docs/API_CONTRACT_V4.md) e [relatório](../docs/RELATORIO_PORTAL_SIMULADOR_V4.md).

## Qualidade

```powershell
cd chega_junto_portal
node --test
node --check js/app.js
```

Não há `npm install`, framework ou dependência de produção. HTML/CSS/JS são locais. Servidor aplica CSP, `nosniff`, `no-store` e política de referrer. Validação visual em desktop/tablet; celular não é prioridade desta fase.

Roboto regular/negrito são servidos localmente em `assets/fonts`, com licença Apache 2.0 incluída em `LICENSE.txt`. Arquivos sem alteração obtidos do cache de fontes Material do SDK Flutter já instalado. Não há chamada a Google Fonts ou CDN.

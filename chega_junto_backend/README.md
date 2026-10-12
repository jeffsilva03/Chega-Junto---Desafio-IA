# Chega Junto — Backend

Checkpoint V5: backend demonstrativo no Render, com JWT e conexão TLS ao Aiven. Consulte [Deploy Render](#deploy-render--v5) e o [relatório V5](../docs/RELATORIO_DEPLOY_RENDER_V5.md) para configuração, validações e pendências operacionais.

Base V4 preservada: Portal Simulador local, 7 operações em namespace separado, desabilitado por padrão e indisponível no Render. Consulte [contrato atual V4](docs/API_CONTRACT_V4.md), [execução e controle do simulador](../chega_junto_portal/README.md) e [relatório](../docs/RELATORIO_PORTAL_SIMULADOR_V4.md). A contagem de 33 operações abaixo descreve a base histórica V3.

Fase 4: backend funcional com cadastro/login/JWT, executado localmente com MySQL Aiven. **33 operações HTTP**: 29 de produto + 3 de autenticação em `/api/v1` e `/health`. Flutter possui modo mock e ApiRepositories com sessão por usuário.

- [Autenticação e validação da Fase 4](docs/RELATORIO_AUTENTICACAO_V3.md).

- [Contrato completo e mapa Flutter](docs/API_CONTRACT_V3.md).
- [Relatório funcional e validações](docs/RELATORIO_BACKEND_FUNCIONAL_V3.md).
- [Validação inicial Aiven](docs/RELATORIO_VALIDACAO_AIVEN_V3.md).
- [Infraestrutura inicial](docs/RELATORIO_INFRAESTRUTURA_V3.md).
- [Modelagem aprovada](../chega_junto_app/docs/PROPOSTA_MODELAGEM_BACKEND_V3.md).

Os relatórios iniciais e o relatório funcional da Fase 2 são históricos. O contrato e o relatório de autenticação descrevem a superfície atual.

## Arquitetura

```text
Flutter Android/Web (mock ou API com JWT)
  → HTTP REST → FastAPI local / Router → Pydantic Schema
  → Service → Repository → SQLAlchemy / PyMySQL
  → SSLContext VERIFY_IDENTITY → MySQL Aiven
```

Routers não acessam SQLAlchemy diretamente. Services controlam regras, titularidade e commit/rollback; repositories consultam/persistem sem commits próprios. DTOs públicos separados dos models ORM; sessão por request, queries parametrizadas. Não há criação de tabelas, migrations ou fixtures no startup.

Pastas: `app/api/v1`, `schemas`, `services`, `repositories`, `models`, `database`, `core`; `migrations`, `scripts`, `tests`, `docs`. Modelagem e migration inicial preservadas.

## Requisitos e execução local

Python 3.12 a 3.14 e `uv`; validado com Python 3.14.3/MySQL Aiven 8.4.11. DDL requer MySQL >=8.0.16 para enforcement de CHECK. Na pasta backend:

```powershell
uv sync --locked --dev
```

Na **primeira configuração**, somente se `.env` ainda não existir:

```powershell
Copy-Item -LiteralPath .env.example -Destination .env
```

Edite localmente, sem sobrescrever `.env` preenchido. `.env` e `ca.pem` são ignorados pelo Git; `.env.example` mantém credenciais vazias. Nunca colocar segredos em Flutter, código, comandos, documentação ou logs.

| Variável | Uso / padrão |
| --- | --- |
| APP_ENV / LOG_LEVEL | development e INFO; payloads/erros internos não são registrados |
| DATABASE_HOST / DATABASE_PORT | host DNS e porta fornecidos pelo serviço |
| DATABASE_NAME | banco existente; **defaultdb é intencional na demo** |
| DATABASE_USER / DATABASE_PASSWORD | credenciais exclusivamente no backend |
| DATABASE_SSL_MODE | obrigatoriamente VERIFY_IDENTITY |
| DATABASE_SSL_CA_PATH | CA do serviço: ca.pem relativo ao backend ou caminho absoluto |
| DATABASE_CONNECT_TIMEOUT / DATABASE_READ_TIMEOUT / DATABASE_WRITE_TIMEOUT | 5 s cada |
| DATABASE_POOL_SIZE / DATABASE_MAX_OVERFLOW | 3 + 2 por processo |
| DATABASE_POOL_TIMEOUT / DATABASE_POOL_PRE_PING / DATABASE_POOL_RECYCLE | 10 s / true / 300 s |
| CORS_ALLOWED_ORIGINS | lista JSON de origens exatas autorizadas |
| APP_TIMEZONE | America/Sao_Paulo |
| DEMO_MODE / DEMO_USER_ID | true e ID do usuário fictício existente |
| AUTH_MODE | jwt (padrão); demo somente local/teste explícito, proibido em produção |
| AUTH_SECRET_KEY | chave aleatória de desenvolvimento com pelo menos 32 bytes, somente no .env ignorado; exemplo vazio |
| AUTH_ACCESS_TOKEN_EXPIRE_MINUTES | 60; intervalo permitido de 1 a 1440 |

URL `mysql+pymysql` construída em memória por `URL.create`, charset utf8mb4; não há URL pública. Senhas com caracteres especiais respeitam sintaxe dotenv. Ambiente tem precedência sobre `.env`. TLS valida cadeia e hostname, mínimo 1.2, sem fallback inseguro. CA local não é chave privada.

Configuração parcial, CA inválido/ausente, wildcard CORS e SSL diferente de VERIFY_IDENTITY são rejeitados. JWT sem chave válida impede startup com erro sanitizado. Configure a chave local uma vez usando gerador criptográfico, sem publicá-la no terminal ou versioná-la; a aplicação nunca gera segredo no startup. Em development sem banco configurado, mas com autenticação configurada, /health retorna 503; production exige conexão completa e proíbe modo demo.

## Alembic e seed

Para conferir o banco já validado:

```powershell
uv run alembic current
uv run alembic check
```

Esperado: `20261012_0003 (head)` e `No new upgrade operations detected.` São 16 tabelas de negócio e `alembic_version`. Migration histórica 0001 não editada; 0002 move o e-mail para users, adiciona hash/conta ativa e permite perfil inicial incompleto. A extensão 0003 adiciona status de consulta e tipo retorno.

Em instalação nova, somente após inspecionar o destino e descartar conflitos com estruturas desconhecidas:

```powershell
uv run alembic upgrade head
uv run python -m scripts.seed_demo
```

Não repetir upgrade/seed para testar endpoints; não executar downgrade/reset na demo. MySQL DDL não é integralmente transacional; não usar stamp para esconder divergências.

Seed explícito/idempotente, somente development/demo: 1 usuário/perfil, 2 unidades, 3 atendimentos, 7 itens de checklist, 1 lembrete, 4 medicamentos, 3 alergias, 6 registros históricos, 2 documentos textuais, preferências, 6 notificações e 1 relato inicial. Datas fixas de outubro/2026. Reconhece demo existente sem duplicar/sobrescrever; não reconcilia fixtures incompletas. A conta demo legada não recebe senha e não faz login por senha. Cadastro normal não executa seed nem copia esses dados.

## Servidor e Swagger

```powershell
uv run uvicorn app.main:app --host 127.0.0.1 --port 8000
```

Em outro terminal:

```powershell
Invoke-RestMethod -Uri http://127.0.0.1:8000/health
```

Na tela Cadastro do Flutter, crie somente uma conta fictícia; login envia JSON e recebe token automaticamente. Endpoints protegidos requerem Authorization Bearer. No Swagger, use o token recebido em Authorize, sem salvá-lo em documentação/logs. Um GET de perfil sem token retorna 401. Não use comandos que imprimam a resposta do login no terminal.

[Swagger local](http://127.0.0.1:8000/docs), [ReDoc](http://127.0.0.1:8000/redoc), [OpenAPI](http://127.0.0.1:8000/openapi.json). Health faz SELECT 1 real: 200 status/database ok ou 503 indisponível; não verifica versão Alembic.

Encerre por Ctrl+C. No Windows/Python 3.14, uma execução de validação registrou erro de transporte asyncio no encerramento e precisou terminar o processo residual após a porta fechar. Os requests e os dados não foram afetados. Para limitar espera no encerramento local, Uvicorn aceita `--timeout-graceful-shutdown 5`; não foi alterada a infraestrutura da aplicação para contornar esse comportamento do ambiente.

## API v1 e modo demo

| Domínio | Operações |
| --- | --- |
| Autenticação | POST `/auth/register`, POST `/auth/login`, GET `/auth/me` |
| Perfil | GET/PUT `/me/profile` |
| Unidades | GET lista/detalhe `/facilities` |
| Agenda | GET lista/detalhe `/appointments` |
| Preparação | GET overview e preparo por atendimento; GET/PATCH checklist; GET/PUT presença |
| Lembretes | GET/POST `/reminders` |
| Saúde | GET/PUT `/me/health-items`; GET histórico/lista e detalhe |
| Relato | GET/PUT report; DELETE somente summary; POST review; PUT final-review |
| Notificações | GET lista; PATCH marcar como lida |
| Preferências | GET/PUT notificações e acessibilidade |

Contratos completos no [API_CONTRACT_V3.md](docs/API_CONTRACT_V3.md). Identidade normal resolvida pelo sub do JWT e conta existente/ativa. Não se aceita `user_id` do cliente como identidade. Recursos de outro titular recebem o mesmo 404 de recurso ausente. Perfil aceita nome/e-mail e campos opcionais null; e-mail é canônico em users, inclusive para login.

IDs/revisões em strings decimais no JSON e OpenAPI; datas em UTC ISO 8601. Paginação limit/offset, limites 20/100. Progresso calculado, sem percentual persistido. Relato exige versão esperada, hash do servidor, revisão humana e locking; edição antiga retorna 409. Reordenação usa posições temporárias contra UNIQUE imediato.

Perfil/saúde/preferências usam PUT integral sem ETag. Saúde salva ambas as listas atomicamente. Presença/lembrete vinculado coordenam cartão interno na mesma transação, preservando leitura do cartão atualizado. POST de lembrete não deduplica retries: não repetir automaticamente após timeout. Não há push ou scheduler.

Modo demo **não é autenticação**: exige AUTH_MODE=demo explícito e clientes compartilham o titular configurado. Modo normal exige JWT, mesmo com DEMO_MODE=true legado. Usar somente dados fictícios; a API não está pronta para publicação com dados sensíveis. JWT vence em 60 minutos, sem refresh/revogação nesta fase. Logout Flutter descarta token e estado; fechar/recarregar exige novo login.

## CORS e Flutter

`CORS_ALLOWED_ORIGINS` permanece uma lista de origens exatas, com esquema/porta. Sem `*` ou cookies. Content-Type/Accept/Authorization; GET/POST/PUT/PATCH/DELETE e preflight pelo middleware. Android nativo não depende de CORS; Flutter Web/iPhone no navegador depende da origem Web autorizada. CORS não é autorização. IP particular fica somente no .env local, nunca em arquivos versionados.

Flutter acessa somente FastAPI. Banco, senha e eventual chave de IA pertencem ao backend. MockRepository/ApiRepository são alternáveis; adapters cuidam de DTOs, IDs de filhos, revisão esperada e 409. Comandos completos Web/Android/iPhone estão no [README Flutter](../chega_junto_app/README.md).

## Testes e qualidade

```powershell
uv run pytest -q
uv run ruff check app scripts migrations tests
uv run ruff format --check app scripts migrations tests
uv run python -m compileall -q app scripts migrations
```

**325 testes passam**, com o warning conhecido TestClient/httpx. Testes normais não herdam `.env` ou credenciais; chaves efêmeras são geradas somente para os testes. Mutações HTTP usam SQLite em memória exclusivamente nos testes, com FKs/CHECKs/UNIQUE imediato e compilação adaptada dos tipos MySQL. Produção continua exclusivamente MySQL; `create_all` está restrito à fixture efêmera. DDL/migrations são também verificados offline com dialeto MySQL.

Cobertura funcional: 33 contratos, autenticação, JWT inválido/expirado, isolamento de titulares, novo usuário vazio, no-op, limites/filtros, dia local, revisão/reordenação, rollback após flush e erros/logs sanitizados. UNIQUE imediato e SQL MySQL FOR UPDATE verificados; isso não substitui ensaio de concorrência sob carga em instância MySQL isolada.

Validação Aiven da Fase 4: migration 0002 aplicada, TLS/VERIFY_IDENTITY mantido e Alembic sem divergência; fingerprints preservaram todas as fixtures originais. Uma conta fictícia foi autorizada para o smoke Flutter de cadastro/logout/login. Detalhes e contagens no relatório de autenticação, sem credenciais ou tokens.

## Limites históricos da base V3

Adiadas: POST/PATCH atendimentos; PATCH/DELETE lembretes; DELETE relato inteiro; administração de unidades; refresh/revogação; recuperação/verificação de e-mail; Google/Apple; MFA/RBAC; exclusão de conta. Sem IA/áudio/transcrição reais, upload, push/Firebase/APNs, SUS/mapas ou Render. Sem novos estados de realização/cancelamento.

Integração e autenticação mínima implementadas; aguardam revisão e aprovação para a próxima fase. Nenhum commit/push/tag/deploy.

## Deploy Render — V5

Backend demonstrativo publicado em [chega-junto-api.onrender.com](https://chega-junto-api.onrender.com): `Flutter → HTTPS → Render → TLS VERIFY_IDENTITY → Aiven MySQL`. Portal e simulador continuam exclusivamente locais; não há integração SUS. Esta seção registra a evolução V5; limites históricos acima pertencem às fases anteriores.

Web Service `chega-junto-api`, Free, Oregon, runtime Python nativo 3.14.3, uv 0.10.8, repositório privado, branch `main`, Root Directory `chega_junto_backend`, Auto-Deploy Off. Comandos no Dashboard:

```text
Build: uv sync --frozen --no-dev
Start: uv run --no-sync uvicorn app.main:app --host 0.0.0.0 --port $PORT
Health Check Path: /health
```

Variáveis de runtime por nome: `PYTHON_VERSION`, `UV_VERSION`, `APP_ENV`, `AUTH_MODE`, `DEMO_MODE`, `SIMULATOR_MODE`, `AUTH_SECRET_KEY`, `AUTH_ACCESS_TOKEN_EXPIRE_MINUTES`, `LOG_LEVEL`, `APP_TIMEZONE`, `CORS_ALLOWED_ORIGINS`. Variáveis do banco: `DATABASE_HOST`, `DATABASE_PORT`, `DATABASE_NAME`, `DATABASE_USER`, `DATABASE_PASSWORD`, `DATABASE_SSL_MODE`, `DATABASE_SSL_CA_PATH`. Preencher valores secretos somente no ambiente privado; nunca em Git ou frontend.

Produção usa JWT, demo/simulador desligados e origem CORS exata `http://127.0.0.1:5173` para smoke local, sem wildcard. Secret File `ca.pem` em `/etc/secrets/ca.pem`, TLS `VERIFY_IDENTITY` mantido. Não publicar o Portal contra este serviço.

[Health](https://chega-junto-api.onrender.com/health) retornou 200 com banco ok; [Swagger](https://chega-junto-api.onrender.com/docs) e [OpenAPI](https://chega-junto-api.onrender.com/openapi.json) retornaram 200, sem rotas simulator. Simulator retorna 404; perfil sem token retorna 401/Bearer. Cadastro/login/logout e persistência de nome fictício após novo login foram validados via Flutter Web; login Android confirmado pelo usuário.

Alembic permanece `20261012_0003 (head)`, sem operações pendentes. Sem nova migration, pre-deploy migration ou migration no startup. Alterações futuras de schema exigem execução controlada antes do deploy autorizado. Para novo deploy: revisar commit/configuração, executar checks e usar Manual Deploy; não presumir que mudanças locais não commitadas foram publicadas.

Free pode dormir após 15 minutos sem tráfego e apresenta cold start/cotas; não há keep-alive. Consulte o [relatório V5](../docs/RELATORIO_DEPLOY_RENDER_V5.md) para todos os resultados e limites. **A senha Aiven e o segredo JWT envolvidos no incidente relatado ainda precisam ser substituídos pelo usuário**, que autorizou continuar com os atuais temporariamente. Nenhum segredo foi incluído nos documentos ou builds. O checkpoint oficial V5 registra esta entrega documental; Auto-Deploy Off preserva o serviço funcional durante o fechamento Git.

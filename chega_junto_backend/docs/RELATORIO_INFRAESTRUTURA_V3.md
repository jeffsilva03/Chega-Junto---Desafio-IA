# Relatório da infraestrutura V3 — Fase 1

**Data:** 9 de outubro de 2026, America/Sao_Paulo.

**Resultado:** infraestrutura local implementada e validada sem credenciais externas. A connection chain real FastAPI → SQLAlchemy → TLS → Aiven e a execução de `alembic upgrade head` no serviço remoto continuam pendentes da configuração local. Nenhum banco foi criado, nenhum seed foi executado no Aiven e nenhum deploy foi realizado.

**Autorização:** decisões oficiais e somente Fase 1, conforme solicitação aprovada em 9/10. As decisões foram incorporadas à [modelagem V3](../../chega_junto_app/docs/PROPOSTA_MODELAGEM_BACKEND_V3.md), incluindo a remoção de transcrição persistida. Nenhum arquivo de código Flutter foi alterado. Não houve commit/push.

## 1. Estrutura criada

```text
chega_junto_backend/
├── app/
│   ├── __init__.py
│   ├── main.py
│   ├── api/
│   │   ├── dependencies.py
│   │   └── v1/router.py
│   ├── models/
│   │   ├── __init__.py
│   │   ├── users.py
│   │   ├── appointments.py
│   │   ├── health.py
│   │   ├── reports.py
│   │   ├── notifications.py
│   │   └── preferences.py
│   ├── schemas/
│   │   ├── common.py
│   │   ├── health.py
│   │   └── report_content.py
│   ├── repositories/health.py
│   ├── services/
│   │   ├── health.py
│   │   └── report_revision.py
│   ├── database/
│   │   ├── base.py
│   │   └── session.py
│   └── core/
│       ├── config.py
│       └── errors.py
├── migrations/
│   ├── env.py
│   ├── script.py.mako
│   └── versions/20261009_0001_initial_schema.py
├── scripts/
│   ├── __init__.py
│   └── seed_demo.py
├── tests/
│   ├── conftest.py
│   ├── test_config.py
│   ├── test_infrastructure.py
│   ├── test_models_migration.py
│   ├── test_report_revision.py
│   └── test_seed.py
├── docs/RELATORIO_INFRAESTRUTURA_V3.md
├── alembic.ini
├── pyproject.toml
├── uv.lock
├── .env.example
├── .gitignore
└── README.md
```

Todas as pastas possuem função nesta entrega. A estrutura `/api/v1` contém apenas um router reservado, sem rotas de CRUD. Factory `create_app` permite testar configuração e banco injetados; lifespan cria engine/pool, sem consultar banco ou modificar schema no startup, e dispõe o pool no encerramento.

## 2. Dependências e reprodução

Versões efetivamente instaladas e validadas neste workspace; `uv.lock` fixa a resolução completa, incluindo transitivas. `pyproject.toml` declara faixas compatíveis; usar `uv sync --locked --dev` para reproduzir esta entrega.

| Componente | Versão |
| --- | --- |
| Python local | 3.14.3; projeto aceita >=3.12,<3.15 |
| uv | 0.10.8 |
| FastAPI | 0.143.0 |
| Pydantic | 2.14.0 |
| pydantic-settings | 2.15.0 |
| SQLAlchemy | 2.0.54 |
| PyMySQL | 1.2.3, extra rsa |
| Alembic | 1.20.0 |
| Uvicorn | 0.54.0 |
| tzdata | 2026.5 |
| Starlette, transitiva | 1.7.0 |
| pytest, desenvolvimento | 9.1.1 |
| httpx, desenvolvimento | 0.28.1 |
| Ruff, desenvolvimento | 0.16.10 |

O ambiente virtual `.venv` é local e ignorado. Sem mistura de drivers sync/async. PyMySQL usa o SSLContext do Python; não há fallback para SQLite no backend. O acesso síncrono do endpoint executa no threadpool do FastAPI.

## 3. Modelos implementados

| Tabela | Modelo / finalidade e relações |
| --- | --- |
| users | Raiz demo, timezone; 1:N consultas, saúde, lembretes e notificações |
| user_profiles | PK/FK user_id, 0..1 por usuário; endereço único e contato de emergência no agregado |
| facilities | Unidade reutilizada por várias consultas |
| appointments | Usuário e unidade obrigatórios; data UTC/fuso, orientações JSON, resposta de presença |
| appointment_checklist_items | Itens por consulta; obrigatório/marcado/seção/ordem; chave única por consulta |
| reminders | Usuário obrigatório, consulta opcional, horário absoluto; sem delivery status |
| medications | Lista livre por usuário, nome/detalhes/ordem |
| allergies | Lista livre por usuário, nome/detalhes/ordem |
| health_records | Histórico preexistente, independente da agenda; notas JSON |
| health_record_documents | Prévias textuais por histórico, em ordem; sem upload/blob |
| pre_visit_reports | 0..1 por consulta, FK única; original, hash de fonte, marcos e versões |
| report_sections | Todas as seções por relato, inclusive vazias; chave/ordem únicas no pai |
| report_questions | Todas as perguntas por relato, inclusive desmarcadas; texto/seleção/ordem |
| notifications | Cartões internos, source_key única por usuário, read_at e destinos com FKs |
| notification_preferences | PK/FK user_id; switches do usuário |
| accessibility_preferences | PK/FK user_id; texto, aparência e switches |

São exatamente **16 tabelas de negócio**. PKs `BIGINT UNSIGNED AUTO_INCREMENT`, exceto os três singletons com PK/FK user_id sem geração própria. FKs também unsigned. `DatabaseId` serializa IDs como strings decimais na fronteira JSON, incluindo o máximo unsigned de 64 bits; ainda não há DTOs públicos de CRUD.

MySQL InnoDB/utf8mb4/utf8mb4_unicode_ci; códigos e chaves técnicas específicos usam utf8mb4_bin. Estados usam VARCHAR e CHECK nomeados; não foram criadas tabelas de domínio ou ENUM MySQL. CHECK exige MySQL >=8.0.16; a versão real Aiven ainda deverá ser conferida. JSON é restrito a arrays de orientações/notas, com CHECK de tipo; validação dos elementos ficará nos schemas dos módulos.

Todas as tabelas têm created_at/updated_at DATETIME(6). Valores são UTC sem offset na borda MySQL, com fuso IANA no usuário/consulta. Defaults e onupdate são **do ORM**, incluindo timestamps, booleanos e arrays; a migration não instala triggers ou defaults SQL complexos. Inserções SQL diretas precisam fornecer os campos obrigatórios. No agregado futuro, serviços deverão atualizar updated_at do pai também quando apenas filhos mudarem. Sem deleted_at nesta fase.

RESTRICT preserva raízes e referências; CASCADE apenas em documentos do histórico e seções/perguntas do relato. Não existe exclusão pública desses pais nesta fase. Constraints de banco não substituem futura validação de titularidade entre recursos, que pertencerá aos serviços/autorização posteriores.

### Revisão e minimização

`pre_visit_reports` **não contém transcription_text ou transcription_used_at**. Não existe coluna de percentual, prompts internos, raciocínio de IA, diagnóstico gerado, prescrição ou tratamento sugerido. `health_records.type=diagnosis` representa exclusivamente registro histórico fictício preexistente da V2, sem geração pelo aplicativo.

Content_revision inicia em 1; reviewed_revision/final_review_revision são marcos opcionais, com pares de timestamps e constraints de consistência. O mapper possui version_id_col explícito, sem incremento automático; a política interna compara snapshots efetivos e incrementa apenas em alteração real. Seções vazias, perguntas desmarcadas, ordem e seleção fazem parte do snapshot. PUT idêntico não incrementará. Checklist e presença ficam fora dele.

O serviço de revisão desta fase é uma função interna testada, sem persistência ou endpoint de relato. Os serviços futuros precisarão usá-la na mesma transação dos filhos e traduzir conflito em 409. Não há ETag/If-Match para Perfil, Medicamentos ou Alergias. Atomicidade das listas, preservação de read_at no upsert e cálculo de progresso estão documentados, mas dependem dos módulos funcionais seguintes.

Perfil, medicamentos, alergias, histórico, relato e perguntas poderão conter dados sensíveis futuramente. Esta entrega utiliza somente fixtures fictícias; não implementa autorização nem amplia o uso para dados reais.

## 4. Migration inicial

Revision **20261009_0001**, arquivo [migration inicial](../migrations/versions/20261009_0001_initial_schema.py), sem down_revision. Snapshot estático, sem importar modelos atuais no arquivo de revision, sem fixtures. Contém 16 create_table e os índices, PKs/FKs, UNIQUE e CHECK correspondentes. Downgrade remove objetos em ordem inversa de dependências.

Rascunho produzido a partir do metadata com autogenerate do Alembic usando um catálogo SQLite vazio e efêmero apenas para detectar ausência de tabelas, sem criar tabelas ou persistir dados nesse catálogo. Os tipos MySQL explícitos foram preservados. Em seguida a revision foi revisada e compilada **com o dialeto MySQL**, comparada ao metadata por teste e conferida quanto a nomes/tamanhos, FKs, índices, ausência de transcrição e de seeds. O SQLite auxiliar não faz parte dos arquivos, dependências de conexão ou execução do backend.

`alembic upgrade head --sql` gera **17 CREATE TABLE**: 16 de negócio e `alembic_version`, tabela técnica do Alembic. Esse INSERT técnico de revision não é fixture. O teste de roundtrip registra as operações sem executar SQL e verifica a ordem segura do downgrade.

Validação offline não demonstra que o servidor Aiven aceita todo o DDL. Upgrade online, reflection e `alembic check` continuam pendentes. MySQL pode efetivar DDL parcialmente; falha online exige inspeção antes de retry. Não executar downgrade real no banco demo para testar.

## 5. Configuração, TLS e sessões

`app/core/config.py` é a única fonte de configuração para aplicação, Alembic e seed. `.env.example` tem campos de conexão vazios e defaults seguros. `.env`, certificados e chaves locais estão ignorados; nenhuma credencial real, URL privada ou chave foi incluída. Variáveis de ambiente prevalecem sobre `.env`.

Validações: limites de pool/portas/timeouts, timezone IANA, conexão completa ou totalmente ausente em development, CA existente, SSL apenas VERIFY_IDENTITY e origens CORS HTTP(S) exatas. Configuração inválida gera erro genérico sem imprimir valores. Senha usa SecretStr, não aparece no repr/dump. A URL SQLAlchemy é montada com URL.create, sem interpolação manual.

SSLContext com CA explícito, CERT_REQUIRED, check_hostname=true e mínimo TLS1.2. Engine mysql+pymysql, parâmetros e SQL sem logging de valores, echo=false/hide_parameters=true. Isso configura validação de identidade; não foi feita ainda uma negociação TLS com Aiven. [SQLAlchemy MySQL](https://docs.sqlalchemy.org/en/20/dialects/mysql.html), [PyMySQL Connection](https://pymysql.readthedocs.io/en/latest/modules/connections.html).

Pool default por processo: size3, overflow2, timeout10s, pre_ping=true, recycle300s; cinco conexões máximas da aplicação por processo. Connect/read/write timeouts5s. Os valores são configuráveis, inclusive DATABASE_POOL_PRE_PING. Uma instância inicialmente; Alembic e seed usam engines próprias temporárias e dispõem ao terminar.

Sessão por request/unidade de trabalho, rollback em erro, fechamento em finally; sem commit automático. Conexões ajustadas para UTC. Não existe create_all, migration ou seed no startup. Falhas SQLAlchemy do health são convertidas para resposta indisponível, sem traceback/conteúdo sensível nos logs.

## 6. Health e CORS

**GET /health**, síncrono, executa SELECT1. Retorna 200 `{"status":"ok","database":"ok"}` com resultado válido; 503 `{"status":"unavailable","database":"unavailable"}` quando a conexão não está configurada ou está indisponível. Erro inesperado recebe 500 genérico. A sessão fecha em todos os casos; erro faz rollback.

O health não valida migração aplicada e não expõe informações de negócio. Sem .env, development inicia para inspeção, mas retorna 503. Em production, ausência de conexão é erro de configuração. Nenhum segredo, host, usuário, URL ou stack trace é retornado.

`CORS_ALLOWED_ORIGINS` é lista JSON de origens exatas; sem wildcard, path, usuário/senha ou regex ampla. Exemplo usa http://localhost:5173 e http://127.0.0.1:5173. Métodos preparados para módulos futuros; headers iniciais Content-Type/Accept, credentials=false. CORS cobre também erros sanitizados. Origens definitivas de Web/iPhone deverão ser informadas antes da integração. Android nativo não usa CORS. Nenhuma alteração Flutter ou configuração Render foi necessária.

## 7. Seed fictício

`scripts/seed_demo.py`, execução explícita, nunca no startup/migration. Reproduz principais fixtures V2: usuário/perfil, 2 unidades, 3 consultas, 7 itens checklist, 1 lembrete, 4 medicamentos, 3 alergias, 6 históricos, 2 documentos textuais, preferências, 6 notificações e 1 relato original. Seções/perguntas começam ausentes porque o relato inicial ainda não foi organizado; não são fabricadas revisões concluídas.

Datas fixas em outubro de 2026; horário São Paulo convertido para UTC. O seed inicial permite derivar 75% do preparo da consulta principal, sem salvar o número: documentos obrigatórios marcados, presença confirmada, original não vazio, revisão final ausente. Sem transcrição ou áudio persistido.

Exige revision inicial e ambiente development/demo com DEMO_MODE=true. Usa GET_LOCK no MySQL para serializar seeds e transação para inserção. Detecta fixture por usuário/perfil/email e consulta inicial, retornando already_exists sem sobrescrever dados. Não reconcilia fixture parcialmente removida. Com outros dados ou IDs conflitantes, recusa alterações. A verificação não é autenticação; DEMO_USER_ID é contexto fictício para as próximas fases.

Testes exercitam construção e detecção com sessões simuladas. O script completo, seu lock/commit e inserções reais ainda precisam ser validados no Aiven após migration; não foram executados nesta entrega.

## 8. Validações executadas

| Verificação | Resultado / alcance |
| --- | --- |
| uv sync --dev | Dependências resolvidas e ambiente virtual local criado |
| uv sync --locked --dev | Lock reproduzido, 37 pacotes auditados |
| pytest -q | **53 testes passaram**, sem banco remoto |
| Ruff lint | Sem erros |
| Ruff format | Arquivos Python formatados |
| compileall app/scripts/migrations | Sem erros de compilação |
| alembic heads | Uma head: 20261009_0001 |
| Alembic upgrade offline | DDL MySQL compilado, sem conexão; 16 tabelas mais controle técnico |
| Alembic downgrade offline | SQL de reversão compilado; nenhuma tabela removida em banco |
| Consistência revision/metadata | Tipos, nullability, constraints, índices e opções MySQL conferidos |
| Política de revisão | Mudança real/no-op, remoção, ordem/seleção e conflito de versão testados |
| TLS | SSLContext capturado com CA e identidade obrigatórios; CA inválido rejeitado sem fallback |
| Uvicorn + HTTP real local | Inicializou; OpenAPI contém apenas /health; sem banco responde 503 controlado; processo encerrado |
| Rotas fora do escopo | /api/v1/appointments responde 404 |
| Falhas de banco/request | 503/500 sanitizados, rollback/close; ausência de segredo sentinela em resposta/log |
| CORS | Origem autorizada/rejeitada, preflight e headers em falhas 503/500 |

Há **um aviso de depreciação**, sem falha: Starlette 1.7.0 avisa que o TestClient deixará de usar httpx em favor de httpx2. Isso afeta a dependência de testes; a suite atual passa. Reavaliar essa dependência ao atualizar o ambiente, sem confundir o aviso com erro do backend.

Testes de infraestrutura utilizam doubles, sem create/drop/seed em Aiven. Não houve execução de testes/builds Flutter porque o frontend não mudou. Resultados offline não substituem teste de integração MySQL.

## 9. O que falta do Aiven

Não existe `.env` local preenchido nesta entrega. Para continuar, fornecer **localmente no .env**, sem colar segredos na conversa/código:

1. DATABASE_HOST: hostname DNS do serviço.
2. DATABASE_PORT: porta efetiva do serviço.
3. DATABASE_NAME: banco existente destinado à demo.
4. DATABASE_USER: usuário com permissões para conectar; migrations precisam DDL e seed precisa DML.
5. DATABASE_PASSWORD: senha local correspondente.
6. DATABASE_SSL_CA_PATH: caminho do CA público do próprio serviço, baixado do Aiven.

Manter VERIFY_IDENTITY. Confirmar serviço acessível e versão MySQL compatível; não inventar host/porta/credenciais e não trocar por TLS sem validação. Não foi criado .env com placeholders que pareçam uma conexão real. Não é necessária chave privada para o fluxo planejado de CA/usuário/senha.

Depois: SELECT1 pelo health, upgrade Alembic, current/check, seed explícito e nova conferência. A ordem está autorizada pela solicitação quando a configuração real existir; não foi realizada por falta desses dados.

## 10. Comandos exatos

No PowerShell, na máquina deste workspace:

```powershell
Set-Location -LiteralPath 'C:\Users\jeffo\Desktop\ChegaJunto - Desafio IA\chega_junto_backend'
uv sync --locked --dev
Copy-Item -LiteralPath .env.example -Destination .env
```

Copiar somente se `.env` ainda não existir; editar os valores localmente antes da conexão. Para inspecionar sem banco, deixar todos os seis campos vazios, mantendo development.

```powershell
uv run pytest -q
uv run ruff check app scripts migrations tests
uv run ruff format --check app scripts migrations tests
uv run python -m compileall -q app scripts migrations
uv run alembic heads
uv run alembic upgrade head --sql
```

Depois da configuração real Aiven, executar manualmente nesta ordem:

```powershell
uv run alembic current
uv run alembic upgrade head
uv run alembic current
uv run alembic check
uv run python -m scripts.seed_demo
uv run uvicorn app.main:app --host 127.0.0.1 --port 8000
```

Em outro terminal: `Invoke-RestMethod -Uri http://127.0.0.1:8000/health`. Esperado com banco acessível: status/database ok. Para revisar a reversão sem executar DDL: `uv run alembic downgrade 20261009_0001:base --sql`. Downgrade real remove tabelas; não faz parte da validação da demo.

Nenhum comando de deploy Render foi criado. Binding público, PORT, HTTPS e CORS da publicação serão tratados na fase posterior.

## 11. Próximos passos e parada

1. Configurar Aiven localmente e validar cadeia real TLS/MySQL, migration e seed; resolver qualquer incompatibilidade real de DDL antes de CRUD.
2. Revisar esta entrega e autorizar a próxima fase funcional separadamente.
3. Iniciar perfil e leituras de unidades/agenda conforme o plano, depois checklist/presença/lembretes, saúde/histórico, relato/revisão e notificações/preferências.
4. ApiRepositories progressivos somente quando autorizados, preservando mocks; Render por último.

O contrato oficial futuro permanece com 30 operações essenciais, mas esta entrega implementa somente health. POST/PATCH consultas, PATCH/DELETE lembretes e DELETE integral do relato continuam adiados. Não iniciar CRUD, frontend, IA, autenticação, novos serviços ou deploy sem a próxima autorização.

# Relatório de validação Aiven — V3

**Data:** 9 de outubro de 2026, America/Sao_Paulo.

**Resultado:** infraestrutura validada contra o Aiven MySQL real. Conexão SQLAlchemy/PyMySQL com TLS e identidade verificada, migration aplicada, schema inspecionado, seed executado duas vezes sem duplicação/sobrescrita e FastAPI local com `/health` HTTP 200.

**Próximo passo:** infraestrutura tecnicamente apta para **V3 — Fase 2: Perfil + primeiro CRUD real**, mediante nova autorização. Esta validação não implementou CRUD ou integração Flutter.

## 1. Ambiente e escopo

| Item | Resultado |
| --- | --- |
| Python | 3.14.3 |
| MySQL real no Aiven | **8.4.11**, obtido por SELECT VERSION() |
| Banco selecionado | defaultdb, conforme decisão intencional do responsável |
| Driver / ORM | PyMySQL 1.2.3 / SQLAlchemy 2.0.54, síncronos |
| Alembic | 1.20.0 |
| FastAPI / Uvicorn | 0.143.0 / 0.54.0 |
| Migration aplicada | **20261009_0001**, head única |
| Execução do backend | Local, 127.0.0.1:8000, somente durante validação |
| Render | Nenhuma configuração ou deploy |

Esta etapa completa as verificações remotas que estavam pendentes no [relatório de infraestrutura](RELATORIO_INFRAESTRUTURA_V3.md). A [modelagem aprovada](../../chega_junto_app/docs/PROPOSTA_MODELAGEM_BACKEND_V3.md) foi preservada integralmente, com as mesmas 16 entidades.

## 2. Proteção dos arquivos e configuração

Antes da primeira conexão e novamente ao finalizar:

- `.env` e `ca.pem` existem localmente, **não são rastreados pelo Git** e estão ignorados por `.gitignore`.
- `git ls-files` não retornou nenhum desses dois arquivos; `git check-ignore` confirmou as regras `.env` e `*.pem`.
- `.env.example` contém campos de conexão vazios, sem host, usuário, senha ou URL reais. O campo DATABASE_HOST, que estava ausente do exemplo local, foi restaurado vazio; whitespace no campo de senha vazio foi removido.
- Nenhuma senha, host, usuário, connection string completa, certificado privado ou conteúdo do `.env` foi incluído neste relatório, em código ou em documentação.

A primeira leitura segura de configuração detectou **DATABASE_SSL_CA_PATH vazio**. Foi preenchido somente esse campo no `.env` local com `ca.pem`, arquivo já fornecido. A igualdade dos demais valores antes/depois foi verificada sem imprimi-los. VERIFY_IDENTITY foi mantido.

Depois desse ajuste, a configuração existente carregou corretamente: conexão completa, banco defaultdb, SSL VERIFY_IDENTITY e CA encontrado. Não foram inventadas credenciais ou alteradas políticas de TLS. Os valores sensíveis permaneceram exclusivamente no ambiente local ignorado.

## 3. Conectividade e TLS reais

Foi usada a função existente `build_engine(load_settings())`, sem um driver alternativo ou SSLContext de teste. Na conexão real:

| Verificação | Resultado |
| --- | --- |
| SELECT 1 | 1, conexão estabelecida |
| SELECT DATABASE() | defaultdb acessível |
| Socket PyMySQL | SSLSocket real |
| Protocolo negociado | **TLS 1.3** |
| SSLContext.check_hostname | true |
| SSLContext.verify_mode | CERT_REQUIRED |
| Certificado do servidor | Presente, aceito pela cadeia de confiança carregada |
| CA local configurado | Carregado com sucesso |
| VERIFY_IDENTITY | Mantido, sem fallback ou desativação de validação |

O handshake bem-sucedido, combinado com check_hostname e CERT_REQUIRED no socket efetivamente utilizado, confirma validação da cadeia e da identidade do hostname na conexão. Dados de certificado que poderiam identificar o serviço não foram registrados.

## 4. Compatibilidade e estado inicial

Antes de qualquer upgrade, a inspeção de defaultdb encontrou **zero tabelas e zero views**. Não havia estruturas desconhecidas, objetos conflitantes ou revision anterior. `uv run alembic current` terminou com código 0 e sem revision, coerente com banco vazio.

O MySQL 8.4.11 suporta as estruturas da migration. O preflight verificou InnoDB disponível, collation utf8mb4_unicode_ci, funções JSON e precisão de DATETIME(6) por consultas sem escrita. A aplicação da migration e a inspeção posterior confirmaram BIGINT UNSIGNED, AUTO_INCREMENT, JSON, DATETIME(6), utf8mb4, PKs, FKs, UNIQUE e CHECK.

Referências consultadas: [CHECK no MySQL 8.4](https://dev.mysql.com/doc/refman/8.4/en/create-table-check-constraints.html), [tipo JSON](https://dev.mysql.com/doc/refman/8.4/en/json.html) e [foreign keys](https://dev.mysql.com/doc/refman/8.4/en/create-table-foreign-keys.html). A comprovação para este schema foi a execução no servidor e a inspeção dos objetos resultantes.

**Nenhuma incompatibilidade estrutural exigiu mudança na modelagem ou na migration.** Nenhuma tabela desconhecida foi removida/sobrescrita e nenhum downgrade real foi executado.

## 5. Alembic e schema criado

| Comando | Resultado |
| --- | --- |
| uv run alembic current, antes | Código 0, sem revision; banco vazio |
| uv run alembic upgrade head | Código 0, migration aplicada |
| uv run alembic current, depois | **20261009_0001 (head)** |
| uv run alembic check | Código 0: **No new upgrade operations detected.** |

Foram confirmadas **17 tabelas: 16 de negócio + alembic_version**. A tabela técnica contém a revision esperada. Nenhuma view ou tabela extra foi encontrada.

Conferência complementar, além do Alembic:

| Objeto | Conferência real |
| --- | --- |
| PKs | 16, todas conferidas contra o metadata |
| Colunas | 158 colunas de negócio; nomes, tipos e nullability conferidos |
| IDs | BIGINT UNSIGNED; AUTO_INCREMENT nos IDs próprios e PK/FK compartilhada nos singletons |
| Foreign keys | **19**, com colunas, pais, referências e ações de exclusão conferidas |
| UNIQUE | **10** conjuntos de colunas conferidos |
| Índices explícitos do modelo | **10** conferidos; além de índices de PK/UNIQUE e suporte a FK do MySQL |
| CHECK | **17**, presentes e ENFORCED=YES no information_schema |
| Engine / collation | InnoDB e utf8mb4_unicode_ci nas 16 tabelas de negócio |
| Strings com collation específica | utf8mb4_bin onde previsto; charset utf8mb4 conferido por coluna |
| transcription_text / transcription_used_at | Ausentes em todas as tabelas de negócio |
| Percentual/progresso persistido | Ausente; conjunto de colunas coincide com o modelo aprovado |
| Tabelas inesperadas | Zero |

Relações verificadas incluem usuário → perfil/preferências/consultas/saúde, unidade → consultas, consulta → checklist/relato/lembrete opcional, relato → seções/perguntas, histórico → documentos e destinos das notificações. UNIQUE garante, entre outros, um relato por atendimento, source_key por usuário e as posições dos filhos conforme modelagem.

A reflection retornou opções de tabela vazias e explicitou CHARACTER SET nos tipos de algumas strings. O auxiliar de inspeção foi adaptado para obter engine/collation de information_schema e normalizar apenas a apresentação dos tipos, conferindo charset/collation separadamente. Isso não exigiu alteração em aplicação, banco, ORM ou migration. O Alembic não apontou diferenças.

## 6. Seed fictício: primeira e segunda execuções

Foi executado **duas vezes**, pelo comando `uv run python -m scripts.seed_demo`, sem startup automático e sem fixtures dentro da migration.

**Primeira execução:** código 0; fixtures criadas em banco sem dados de negócio. Contagens e relações foram verificadas por consultas somente leitura.

**Segunda execução:** código 0; fixture existente detectada, resultado `already_exists`. Não houve nova inserção ou sobrescrita.

| Tabela / fixture | Após primeira execução | Após segunda execução |
| --- | ---: | ---: |
| users | 1 | 1 |
| user_profiles | 1 | 1 |
| facilities | 2 | 2 |
| appointments | 3 | 3 |
| appointment_checklist_items | 7 | 7 |
| reminders | 1 | 1 |
| medications | 4 | 4 |
| allergies | 3 | 3 |
| health_records | 6 | 6 |
| health_record_documents | 2 | 2 |
| notification_preferences | 1 | 1 |
| accessibility_preferences | 1 | 1 |
| notifications | 6 | 6 |
| pre_visit_reports | 1 | 1 |
| report_sections | 0 | 0 |
| report_questions | 0 | 0 |

Seções e perguntas começam vazias porque a fixture inicial contém somente o relato original ainda não organizado, conforme a V2. As tabelas existem; não foram fabricadas revisões ou perguntas para preencher contagens.

As contagens antes/depois foram idênticas. Também foram comparados digests internos de **todas as linhas e campos** das 16 tabelas, incluindo timestamps, ordenados por PK. Todos permaneceram iguais: a segunda execução não alterou conteúdo. Dados e digests não foram impressos nem incluídos no relatório. A conferência de todas as FKs não encontrou registros órfãos. As contagens foram reconferidas após os testes automatizados.

Na captura auxiliar da saída da primeira execução, houve uma diferença de encoding do terminal Windows (CP1252 versus UTF-8). O seed havia retornado 0 e concluído a inserção; a falha foi apenas de leitura da saída pelo auxiliar. A retomada validou as fixtures existentes e realizou somente a segunda execução, com encoding explícito. Não foi necessário alterar a lógica do seed ou recriar dados.

## 7. FastAPI e health reais

Servidor iniciado com o comando solicitado:

```powershell
uv run uvicorn app.main:app --host 127.0.0.1 --port 8000
```

Consulta HTTP real a `http://127.0.0.1:8000/health`:

**HTTP 200**

```json
{
  "status": "ok",
  "database": "ok"
}
```

A execução CLI carregou `app.main:app` e o `.env` real, sem injeção de banco simulado, override de dependências ou TestClient. O repository de health existente executou SELECT 1 pela sessão SQLAlchemy/PyMySQL conectada ao Aiven. DEMO_MODE não substitui o banco do health por mock.

O OpenAPI confirmou somente `/health` como rota funcional. Swagger/ReDoc/OpenAPI permanecem documentação técnica padrão; nenhuma rota funcional `/api/v1` foi adicionada.

O servidor foi encerrado por Ctrl+C, com mensagens de application shutdown complete e finished server process. Ao finalizar, a porta 8000 não estava atendendo conexões. Nenhum servidor de validação ficou em execução.

## 8. Qualidade e ajuste mínimo dos testes

Na primeira execução de pytest com o `.env` real presente, passaram 52 testes e falhou `test_invalid_environment_error_is_generic`. O teste pretendia simular configuração parcial, mas herdava os demais campos do `.env` real e a configuração se tornava completa.

**Correção mínima:** em `tests/conftest.py`, a fixture existente passou a desabilitar o env_file padrão durante cada teste, além de limpar variáveis do ambiente. Arquivos de teste explicitamente passados por `_env_file` continuam funcionando. Não houve alteração em config da aplicação, credenciais, modelos, migration ou comportamento de negócio.

Resultado final:

| Comando | Resultado |
| --- | --- |
| uv run pytest -q | **53 passed, 1 warning** |
| uv run ruff check app scripts migrations tests | **All checks passed!** |
| uv run ruff format --check app scripts migrations tests | **31 files already formatted** |
| uv run python -m compileall -q app scripts migrations | Código 0, sem erros |

O warning conhecido continua: StarletteDeprecationWarning sobre uso de httpx no TestClient e futura adoção de httpx2. Conforme solicitado, não foi corrigido nesta etapa.

Testes automatizados usam sessões simuladas e DDL offline; não executaram operações destrutivas no Aiven. A conexão real, schema, seed e HTTP foram validados separadamente. Nenhum teste/build Flutter foi necessário porque seu código permaneceu inalterado.

## 9. Problemas e alterações necessárias

| Item | Situação / ação |
| --- | --- |
| Caminho do CA vazio no .env | Corrigido localmente para ca.pem; outros valores preservados |
| .env.example incompleto | DATABASE_HOST restaurado vazio; senha continua vazia |
| TLS / hostname / CA | Sem problema após configurar caminho; VERIFY_IDENTITY mantido |
| Compatibilidade MySQL | Sem incompatibilidade estrutural; nenhum ajuste de schema |
| Alembic | Upgrade/current/check concluídos sem erro |
| Reflection no auxiliar | Conferência por information_schema e normalização de representação, sem alteração no backend |
| Seed | Duas execuções concluídas; captura auxiliar de encoding ajustada; sem falha lógica, duplicação ou sobrescrita |
| Teste herdando .env real | Isolamento corrigido em tests/conftest.py; 53 testes passaram |
| Warning TestClient | Conhecido, preservado, não bloqueante |

Arquivos persistentes alterados nesta etapa: `.env.example`, `tests/conftest.py` e este relatório. Ajuste local ignorado: somente o caminho de CA em `.env`. `ca.pem` permaneceu local e não foi versionado. Auxiliares temporários de inspeção foram mantidos fora do conjunto versionável.

## 10. Próximo passo e parada

**A infraestrutura está apta a iniciar V3 — Fase 2: Perfil + primeiro CRUD real.** A cadeia validada foi FastAPI local → SQLAlchemy → PyMySQL → TLS VERIFY_IDENTITY → Aiven MySQL, com schema e fixtures reais.

A próxima fase depende de autorização específica. Nesta etapa não foram criados CRUDs, ApiRepositories Flutter, autenticação, IA/OpenAI, transcrição real, upload, novas entidades ou funcionalidades de produto. Não houve alteração Flutter, deploy Render, commit ou push. Não houve downgrade real ou remoção de estruturas desconhecidas.

O backend continua previsto para execução local; o servidor temporário usado na validação foi encerrado. **Parada após esta entrega, aguardando aprovação.**

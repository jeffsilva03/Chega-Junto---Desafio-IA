# Relatório — Backend funcional V3

**Fase 2 ampliada — Backend funcional consolidado. Data: 09/10/2026.**

## 1. Resumo executivo

Implementadas as **30 operações HTTP essenciais** sobre a infraestrutura existente, sem alteração Flutter, schema, migration histórica, credenciais ou TLS. Backend local funcional para os módulos atuais da V2. Foram preservados os limites de produto, atendimentos somente leitura e documentos históricos textuais.

**219 testes aprovados**, Ruff/format/compileall aprovados, Alembic current/check aprovados, **18 GETs reais Aiven HTTP 200**, além de Swagger/ReDoc/OpenAPI. Comparação de contagens e hashes das linhas das 16 tabelas antes/depois comprovou ausência de alteração das fixtures durante o smoke. Gravações testadas somente em banco efêmero isolado.

Apto à próxima fase de integração controlada Flutter → API local, após autorização. Não é entrega de autenticação nem publicação para dados reais.

## 2. Arquitetura final

HTTP → Router → Pydantic Schema → Service → Repository → SQLAlchemy síncrono/PyMySQL → SSLContext VERIFY_IDENTITY → MySQL Aiven.

Dependências centralizam sessão e `UserContext`. Routers delegam a services, sem importar SQLAlchemy. Schemas por domínio, não models ORM como payload. Services coordenam regras e transações; repositories executam consultas/persistência sem commits independentes. Query Core/ORM parametrizada; nenhum SQL de produto construído por concatenação de entrada.

Estrutura existente evoluída, mantendo `/health` fora do prefixo de versão. Não foi criada infraestrutura nova nem alterado o contrato da Fase 1.

## 3. Endpoints implementados

| Método | Quantidade |
| --- | ---: |
| GET | 18 |
| POST | 2 |
| PUT | 7 |
| PATCH | 2 |
| DELETE | 1 |
| **Total** | **30** |

São 29 operações de produto em `/api/v1` + 1 health. Endpoint aqui significa par método/path; documentação técnica não entra no total. Contratos completos, schemas, queries e exemplos reais de teste isolado: [API_CONTRACT_V3.md](API_CONTRACT_V3.md).

| Módulo | Superfície |
| --- | --- |
| Profile | GET/PUT `/me/profile` |
| Facilities | GET `/facilities`, GET `/facilities/{facility_id}` |
| Appointments | GET `/appointments`, GET `/appointments/{appointment_id}` |
| Preparation | GET `/preparation/overview`; GET preparo/checklist/presença por atendimento; PATCH item; PUT presença |
| Reminders | GET/POST `/reminders` |
| Health | GET/PUT `/me/health-items`; GET `/me/health-records` e detalhe |
| Reports | GET/PUT report; DELETE report/summary; POST report/review; PUT final-review |
| Notifications | GET `/me/notifications`; PATCH marcar cartão como lido |
| Preferences | GET/PUT notification-preferences e accessibility-preferences |
| Infraestrutura | GET `/health`, não versionado |

As cinco operações adiadas retornaram 404/405 nos testes HTTP isolados: POST appointments; PATCH appointments/{id}; PATCH e DELETE reminders/{id}; DELETE appointments/{id}/report. Ausência também conferida no OpenAPI real.

## 4. Schemas Pydantic

DTOs de leitura/escrita/nesting organizados por perfil, agenda, preparo, saúde, relato, notificações e preferências. `extra=forbid`; comandos sensíveis não aceitam campos de servidor. Tipos comuns centralizam IDs/revisões, UTC, paginação e período.

Banco mantém BIGINT UNSIGNED; JSON de resposta e OpenAPI usam strings decimais, inclusive IDs/revisões aninhados. Validação interna também aceita inteiros exatos dentro do intervalo, mas recomenda-se string no cliente. Instantes ISO UTC, criação de lembrete exige offset/Z, datas civis sem offset.

CPF/CEP/telefones normalizados em dígitos; UF validada/normalizada, complemento vazio null. SUS permanece somente leitura e sem validação externa. Campos extras e booleanos inválidos são rejeitados. Limites: saúde nome 80/detalhes 160, 200 itens/lista; título lembrete 80; original/seção 20000, pergunta 4000, até 64 seções/200 perguntas, soma dos textos filhos 100000. Sem truncar em 500 caracteres. Demais limites constam no contrato.

## 5. Repositories

`UserRepository`, `AppointmentRepository`, `HealthRepository`, `ReportRepository`, `NotificationRepository`, `PreferencesRepository` e repository health existente. Agrupamento por domínio/agregado, sem um repository para cada tabela. Helpers compartilhados: paginação e substituição de listas ordenadas.

Agenda faz join específico de atendimento/unidade; não carrega histórico, relato ou saúde por linha. Listas ordenadas deterministicamente e escopadas. Teste de query count comprovou quantidade constante para agenda com limit=1 versus 100, sem agregados sensíveis. Demais endpoints carregam consultas específicas em quantidade fixa, sem lazy-loading por item.

## 6. Services

`ProfileService`, `AppointmentService`, `PreparationService`, `HealthService`, `ReportService`, `NotificationService`, `PreferencesService`; resolução central de identidade; serviço de versão existente reutilizado. Regras de produto permanecem fora dos routers/repositories. Helpers centralizam transaction, paginação e validação de IDs de filhos.

`resolve_current_user` usa DEMO_MODE/DEMO_USER_ID do backend. Ausência do usuário ou demo desligada gera 503 controlado e nenhuma inserção. Identidade enviada pelo cliente não altera o contexto.

## 7. Regras de negócio

- Perfil: PUT integral, uma transação, resposta canônica; sem ETag, APIs externas ou edição de SUS/titular/timestamps.
- Unidades: só leitura e acesso por vínculo com agenda do titular. Sem administração.
- Agenda: leitura/lista/detalhe; sem status realizado/cancelado/faltou. Presença `unable` não cancela/avisa/remarca.
- Checklist: somente is_completed, com item vinculado ao atendimento e atendimento ao titular. Não edita estrutura.
- Presença: confirmed/undecided/unable; cada salvamento explícito registra horário. PUT idêntico não duplica cartão.
- Lembretes: listar/criar, horário absoluto, vínculo opcional validado. Sem alarmes/jobs/push/status de entrega. POST sem mecanismo complexo de idempotência; retries podem duplicar.
- Saúde: substituição integral das duas listas ordenadas, manter/editar/criar/remover/reordenar, detalhes livres sem decomposição clínica; valida ambos os conjuntos de IDs antes de salvar.
- Histórico: leitura, filtros, detalhe e documentos textuais demonstrativos. Alterar medicamentos/alergias não inventa eventos históricos.
- Preferências: GET/PUT integral e canônico. Voz/capacidades/tema efetivo continuam locais ao aparelho.

## 8. Preparação/progresso

Regra única reutilizada: documents_done = todos os obrigatórios concluídos, incluindo zero obrigatórios; attendance_done = confirmed; report_done = original.trim não vazio; final_done = organização atual + conteúdo de seção válido + revisão humana atual + finalização da versão atual.

completed_count = soma dos quatro booleanos; fraction = count/4; percentage = count*25. Checklist possui fração própria apenas dos obrigatórios. Nada disso é persistido como coluna de progresso.

Home usa início de hoje no fuso do usuário, preservando atendimentos de hoje mesmo com horário já passado. Teste de 01:00 UTC/22:00 São Paulo confirmou dia correto. Sem próximo atendimento, next_appointment/preparation null, sem gerar fixtures. A agenda fixa de outubro pode futuramente produzir Home vazia, comportamento esperado.

## 9. Relato/versionamento

Agregado persistido: original, seções, perguntas/seleção/ordem, procedência SHA-256 calculada pelo servidor, horários e três revisões. Sem áudio/transcrição, prompt, raciocínio interno, diagnóstico/tratamento/prescrição gerados, interpretação de exame ou percentual.

PUT distingue edit/organize. Organização local/mock exige fonte exatamente igual ao original enviado. Edição de seção conserva procedência; edição de original torna-a desatualizada. Versionamento compara conteúdo lógico e incrementa uma vez por mudança efetiva; no-op/GET/abrir tela/checklist/presença não incrementam. Atualizar somente procedência não aumenta a revisão de conteúdo.

Requests de mutação exigem expected_revision. PUT pode criar relato ausente usando "0"; primeira revisão "1". Versão antiga retorna 409, inclusive payload idêntico. Atendimento é bloqueado antes do relato, inclusive para serializar criação ausente; pai/filhos são lidos com FOR UPDATE nas mutações. Leituras de filhos com lock evitam snapshot antigo após espera no REPEATABLE READ do MySQL. ORM mantém version_id_col como verificação adicional no UPDATE.

Revisão humana exige fonte atual e alguma seção não vazia; zero perguntas selecionadas é permitido. Repetição é idempotente. Finalização exige revisão humana atual; reabrir limpa finalização. Mudança posterior conserva números antigos, mas invalida flags por comparação de versão. Não há transação aberta durante IA externa porque nenhum serviço externo é chamado.

Reordenação estaciona posições em slots altos livres (até 65535, compatíveis com SMALLINT UNSIGNED), faz flush, remove omitidos e só então atribui 0..N-1/flush final. Testes exercitam troca de seções/perguntas sob UNIQUE imediato e inspecionam flush temporário. Não há updates ingênuos de troca direta.

DELETE summary preserva relato/original/estrutura das seções, esvazia textos, remove perguntas e invalida procedência. Revisão aumenta somente se conteúdo muda; repetição é no-op. DELETE do agregado inteiro não existe.

## 10. Notificações

Cartões internos persistidos, sem infraestrutura push. GET respeita active, in_app e preferência de categoria; desativar não apaga nada. Badge unread_count é global entre cartões visíveis, independente de filtros/página. Leitura define read_at no servidor uma vez.

Presença reutiliza source_key ou cartão de confirmação inicial, serializado pelo atendimento. Atualização mantém read_at/published_at e não afirma que unidade foi avisada. Lembrete vinculado cria cartão source_key reminder:{id} na mesma transação; avulso não inventa destino. Checklist não gera eventos de documentos inexistentes no comportamento V2. GET nunca materializa cartões.

## 11. Persistência

MySQL Aiven **8.4.11**, TLS **1.3**, VERIFY_IDENTITY preservado, CA carregado, cadeia/hostname verificados. Banco defaultdb intencional. Pool existente 3 + overflow 2 por processo, pre-ping e recycle mantidos. Configuração/credenciais/CA não foram modificados.

**16 tabelas de negócio**, todas existentes: users, user_profiles, facilities, appointments, appointment_checklist_items, reminders, medications, allergies, health_records, health_record_documents, pre_visit_reports, report_sections, report_questions, notifications, notification_preferences, accessibility_preferences. Mais alembic_version técnica. Sem novas tabelas ou colunas.

**Uma migration existente: 20261009_0001**, preservada. `alembic current`: 20261009_0001 (head). `alembic check`: No new upgrade operations detected. Nenhum upgrade/downgrade/stamp/seed/reset foi executado nesta fase.

## 12. Transações

| Unidade | Garantia |
| --- | --- |
| PUT perfil | todos os campos no mesmo commit; teste de falha no commit reverte |
| PUT health-items | medications + allergies, incluindo ordem, no mesmo commit; falha após flush de medicamentos reverte ambas |
| PUT/DELETE/review/final de relato | pai, filhos, revisão, procedência/marcas no mesmo commit; falha após substituir filhos reverte tudo |
| PUT presença | resposta + atualização/criação de cartão no mesmo commit; falha de cartão reverte presença |
| POST lembrete | lembrete + cartão vinculado no mesmo commit; falha de cartão reverte lembrete |
| PATCH checklist/notificação | update canônico no mesmo commit; timestamps de leitura idempotentes |
| PUT preferências | lock do usuário + singleton, um commit |

Context manager de service usa a sessão que já iniciou autobegin na resolução demo; faz commit ao concluir ou rollback em qualquer falha. Session fechada pela dependência. Leituras não fazem commit de mutação. Locks de raiz e leituras atuais também aplicados em saúde/preferências/cartão para evitar decisões sobre snapshot anterior à espera.

## 13. Segurança/titularidade

Filtro direto ou vínculo ao atendimento do titular em todas as operações. IDs de filhos de outro agregado/titular retornam 404. Payloads não podem trocar user_id/appointment_id/posição/timestamps/revisões resultantes/hash. Campo user_id em query é rejeitado, nunca usado como identidade.

Envelope de erros de /api/v1: 400 semântica, 404 ausente/terceiro, 409 versão/estado, 422 validação, 500 interno, 503 dependência/contexto. 405 para método ausente. SQL/trace/hostname/URL/credenciais/payload não são retornados ou logados. Testes injetam exceções com conteúdo privado e conferem response/caplog. Health conserva envelope histórico.

Dados potencialmente sensíveis futuramente: perfil, agenda, saúde/histórico/documentos, relato/seções/perguntas e conteúdo de cartões. Somente fixtures fictícias nesta fase. Sem autenticação/authorization de produção; clientes compartilham demo. CORS exato preservado, nenhuma origem nova ou wildcard. Nenhum segredo no Flutter.

## 14. Paginação/filtros

Limit/offset: padrão 20/0; limites 100/100000. Total filtrado do titular. Agenda, unidades, lembretes, histórico e notificações paginados; saúde/checklist/relato pequenos agregados não paginados.

Agenda filtra from/to/type/query (120 caracteres, LIKE com escape dos curingas); histórico type/período; lembretes período/appointment_id com titularidade; notificações category/unread/período. Unidades só paginação. Datas civis interpretadas no fuso do usuário, to inclusivo por dia; instantes com offset e to exclusivo. Intervalo inválido 400; datas inválidas/sem offset/fora do intervalo operacional 422.

Ordem determinística: agenda/lembretes instante/id asc; unidades nome/id asc; histórico/notificações instante/id desc; filhos posição/id. Sem SQL arbitrário ou filtros ilimitados.

## 15. Testes

| Verificação | Resultado |
| --- | --- |
| uv run pytest -q | **219 passed, 1 warning**; antes 53 testes |
| uv run ruff check app scripts migrations tests | All checks passed! |
| uv run ruff format --check app scripts migrations tests | 69 files already formatted |
| uv run python -m compileall -q app scripts migrations | código 0 |
| uv run alembic current | 20261009_0001 (head) |
| uv run alembic check | No new upgrade operations detected. |

Cobrem todos os endpoints, happy path, validação, ownership/404, no-op e conflitos; progresso/zero obrigatórios/status de presença/dia local/vazio; paginação/filtros; CRUD agregado de saúde e perfil; prefs/badge/read idempotente; proteção contra campos de servidor; sanitização de erros/inputs/logs; ausência das cinco rotas adiadas; query count da agenda; transações com falhas após flush/commit.

Relato cobre carregar, organizar, no-op, editar seção/original, organização antiga, review atual/antiga, final/reabertura, edição posterior e invalidação, reordenar seções/perguntas, desmarcar todas, excluir/adicionar pergunta, limpar resumo preservando original, criar ausente, stale expected_revision, ownership de filhos e rollback do agregado. Strings maiores que 500 são preservadas; limites operacionais testados.

**Isolamento:** testes de mutação usam SQLite em memória com adaptações de compilação de BIGINT/MEDIUMTEXT, FKs/CHECKs, collations auxiliares e UNIQUE imediato. Configuração de teste não herda `.env`/credenciais. create_all é exclusivamente efêmero. Produção permanece MySQL; aplicação/migrations não dependem de SQLite. DDL MySQL offline e compilação FOR UPDATE complementam os testes.

**Limite explícito:** não houve execução de mutações ou corrida simultânea em MySQL real isolado; 409 foi testado por clientes/versões sucessivas. SQLite não reproduz todos os locks, isolamento, collations e concorrência do InnoDB. UNIQUE imediato valida o algoritmo de estacionamento, mas não se apresenta isso como ensaio de carga/concurrency MySQL. Recomenda-se acrescentar essa validação em instância descartável separada antes de carga multiusuário, preservando defaultdb.

Warning conhecido preservado: StarletteDeprecationWarning do TestClient sobre httpx/futura adoção de httpx2, sem falha de teste. Não foi corrigido fora do escopo.

## 16. Smoke tests Aiven

Uvicorn CLI local, sem TestClient, overrides ou banco simulado. Credenciais carregadas do `.env` ignorado; CA local; SQLAlchemy/PyMySQL e TLS reais. **Todos os 18 GETs documentados responderam 200**: health; perfil; unidades/lista+detalhe; agenda/lista+detalhe; overview; preparo/checklist/presença; lembretes; saúde; histórico/lista+detalhe; relato; notificações; duas preferências.

`/health`: HTTP 200, status ok/database ok, SELECT 1 real. IDs/revisões recursivamente conferidos como strings; respostas passam pelos response_models. `/docs`, `/redoc`, `/openapi.json` HTTP 200. OpenAPI confirmou 30 operações, tags e ausência das rotas adiadas.

| Fixture/tabela | Antes | Depois |
| --- | ---: | ---: |
| users / user_profiles | 1 / 1 | 1 / 1 |
| facilities / appointments | 2 / 3 | 2 / 3 |
| appointment_checklist_items / reminders | 7 / 1 | 7 / 1 |
| medications / allergies | 4 / 3 | 4 / 3 |
| health_records / health_record_documents | 6 / 2 | 6 / 2 |
| notifications | 6 | 6 |
| notification_preferences / accessibility_preferences | 1 / 1 | 1 / 1 |
| pre_visit_reports | 1 | 1 |
| report_sections / report_questions | 0 / 0 | 0 / 0 |

Comparadas também assinaturas SHA-256 das linhas ordenadas de **todas** as tabelas de negócio: iguais. Nenhum conteúdo pessoal/de saúde foi incluído em logs ou neste relatório; somente contagens. Revisão manteve-se a mesma. Não houve requests de mutação no Aiven nem lembretes de teste permanentes.

Encerramento: a execução inicial com Ctrl+C fechou a porta, mas em Windows/Python 3.14 emitiu ConnectionResetError/WinError 10054 no callback de transporte asyncio e permaneceu esperando encerramento. O processo de validação identificado foi terminado; não houve falha HTTP ou alteração de dados. Uma segunda execução, com `--timeout-graceful-shutdown 5`, repetiu os 18 GETs e a validação do OpenAPI final; encerrou com application shutdown complete/finished server process. Porta 8000 livre e nenhum servidor de validação remanescente ao final. O evento operacional foi registrado, sem reduzir TLS ou mudar infraestrutura para ocultá-lo.

## 17. OpenAPI

Tags Profile, Facilities, Appointments, Preparation, Reminders, Health, Reports, Notifications, Preferences; Infraestrutura no health. Summaries/descriptions específicas, response_models e status 201 no POST lembrete; demais operações 200. Erros sanitizados declarados por router, 422 usa ErrorResponse. IDs/revisões documentados como string decimal também em requests.

Contrato Markdown inclui cada método/path, parâmetros, schema/request JSON, schema/response JSON, erros e notas de estado; apêndice de schemas/limites, convenções e mapa completo para controllers/repositories Flutter. Exemplos foram obtidos de HTTP com fixtures efêmeras fictícias, nunca copiados do Aiven.

## 18. Arquivos criados/alterados

| Grupo | Arquivos principais |
| --- | --- |
| Novos routers | app/api/v1/profile.py, appointments.py, preparation.py, reminders.py, health_items.py, reports.py, notifications.py, preferences.py |
| Novos schemas | app/schemas/profile.py, appointments.py, preparation.py, health_items.py, reports.py, notifications.py, preferences.py |
| Novos repositories | app/repositories/users.py, appointments.py, health_items.py, reports.py, notifications.py, preferences.py, common.py |
| Novos services | app/services/identity.py, profile.py, appointments.py, preparation.py, health_items.py, reports.py, notifications.py, preferences.py, common.py |
| Infraestrutura evoluída | app/main.py, app/core/errors.py, app/api/dependencies.py, app/api/v1/router.py, app/schemas/common.py |
| Novos testes | tests/__init__.py, isolated_database.py, test_api_reads.py, test_api_mutations.py, test_api_reports.py, test_preparation_rules.py, test_api_safety.py |
| Testes ajustados | tests/conftest.py, test_infrastructure.py |
| Documentação | README.md, docs/API_CONTRACT_V3.md, este relatório |

Models, migration 0001, seed, dependências/lock, `.env`, CA e Flutter preservados nesta fase. Auxiliares temporários ficaram em `.local` ignorado, fora do conjunto versionável, e foram removidos após uso. Relatórios anteriores são históricos e não foram reescritos.

Git: backend/modelagem já estavam untracked no início desta fase; esta entrega não fez commit/push. A lista acima discrimina a evolução funcional sobre os arquivos anteriores, sem fingir que o diff Git rastreado representa toda a entrega. `.env` e ca.pem ignorados e não rastreados; `.env.example` sem credenciais reais. Conferência final de segredos nos arquivos versionáveis, sem imprimir valores. Nenhum Dart alterado.

## 19. Limitações restantes

1. Demo compartilhada, sem autenticação/autorização de produção. Usar somente dados fictícios.
2. Flutter ainda utiliza mocks. Adapters precisarão manter IDs/revisões, tratar 409, compor DTOs/paginação e invalidar caches; nenhum design refatorado.
3. Sem mutações/concorrência ensaiadas em instância MySQL descartável; limite dos testes isolados descrito na seção 15.
4. POST lembrete sem idempotency key: retry automático pode duplicar. Sem scheduler/push/entrega.
5. Sem ETag em perfil/saúde/preferências, conforme escopo; último salvamento integral prevalece nesses agregados.
6. Fixtures de outubro fixas podem deixar Home vazia; não se recriam atendimentos automaticamente.
7. Limites de conteúdo Pydantic não substituem limite de bytes/rate limiting de uma publicação futura. Sem upload ou endpoint de IA/áudio.
8. Warning TestClient conhecido e evento de encerramento Windows descritos acima.
9. Sem POST/PATCH de atendimentos, PATCH/DELETE de lembretes, DELETE de relato inteiro, administração de unidades, integrações clínicas, JWT/Google, IA/OpenAI/transcrição reais, arquivos, push/Firebase/APNs/SMS/email ou Render.

Nenhum risco foi contornado desligando validação TLS, aceitando wildcard CORS, alterando secrets ou modificando schema aprovado.

## 20. Próxima fase recomendada

Após aprovação: integração incremental Flutter → FastAPI **local** → Aiven. Manter mocks/ApiRepositories alternáveis; começar perfil/preferências, seguir agenda/preparo/saúde, relato com versões e notificações. Usar API_CONTRACT_V3.md como base, conservar IDs como String, tratar vazio/loading/erro/409 e não gerar fixtures em requests.

Antes de dados reais/publicação: autenticação/autorização, ensaio MySQL isolado e controles de operação/privacidade em fase própria. Render permanece posterior. Nenhuma dessas etapas foi iniciada nesta entrega.

**Parada após esta entrega, aguardando aprovação. Sem integração Flutter, commit, push ou deploy.**

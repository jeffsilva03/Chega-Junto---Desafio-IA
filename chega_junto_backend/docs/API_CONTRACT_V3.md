# Chega Junto — contratos HTTP V3

Atualizado na Fase 4, 09/10/2026: cadastro/login/JWT e integração Flutter real, mantendo modo mock. Base local: `http://127.0.0.1:8000`. São **29 operações de produto + 3 de autenticação em `/api/v1` + GET `/health` = 33**. Swagger em `/docs`, ReDoc em `/redoc`, especificação em `/openapi.json`.

## Autenticação — Fase 4

| Método | Path | Request JSON | Resposta |
| --- | --- | --- | --- |
| POST | `/api/v1/auth/register` | `full_name`, `email`, `password` | 201 AuthSession |
| POST | `/api/v1/auth/login` | `email`, `password` | 200 AuthSession |
| GET | `/api/v1/auth/me` | sem body; Authorization Bearer | 200 AuthUser |

AuthSession contém `access_token` (string), `token_type="bearer"` e `user` (AuthUser). AuthUser contém somente `id` (string decimal), `full_name` e `email`. Nunca retorna senha/hash. Enviar token em `Authorization: Bearer <token recebido>`; nenhum segredo de assinatura é enviado ao Flutter. Swagger usa HTTPBearer e o botão Authorize; login é JSON, não OAuth2 password form.

Nome: aparado, 1–160 caracteres. E-mail: trim/lowercase, máximo 254, formato básico com domínio; é único em users e compartilhado canonicamente entre perfil/login/me. Senha: 8–128 caracteres Unicode, preservada exatamente; confirmação não faz parte da API. Campos extras são rejeitados. Argon2id guarda somente hash com salt. Cadastro cria user/perfil mínimo/preferências atomicamente e não copia fixtures de produto.

JWT HS256, issuer `chega-junto`, sub/iat/exp/iss obrigatórios; validade padrão 60 minutos. Verificação de assinatura/algoritmo/expiração/conta ativa em cada request. Sem refresh, revogação, troca de senha, recuperação, verificação de e-mail ou OAuth externo. Logout Flutter limpa sessão/estado local; token copiado permanece válido até expirar. Flutter usa token somente em memória e exige login ao reiniciar/recarregar.

Erros adicionais: `401 invalid_credentials` (login sem distinguir conta ausente/inativa/senha incorreta), `401 invalid_token` (sessão inválida/expirada/ausente), `409 email_already_registered`, `422 validation_error`, `503 dependency_unavailable`. 401 inclui WWW-Authenticate Bearer. Envelope continua `{"error":{"code":"...","message":"..."}}`, sem input, senha, token ou traceback.

### Perfil inicial e e-mail canônico

GET perfil de nova conta retorna nome/e-mail e campos opcionais null, inclusive SUS. PUT continua integral: nome/e-mail obrigatórios; telefone, nascimento, CPF, CEP, endereço e contato de emergência podem ser null/omitidos (omissão equivale a null). Complemento já era opcional. Não enviar string vazia para campos com formato: o adapter converte vazio em null. Alterar e-mail modifica users na mesma transação do perfil e passa a valer no login; colisão é 409 e não salva parcialmente o nome. `id`, `user_id`, SUS e timestamps seguem proibidos no PUT.

Sem dados: agenda, unidades acessíveis, lembretes, histórico e notificações respondem páginas vazias com pagination.total=0; saúde responde duas listas vazias; overview responde next_appointment/preparation=null; preferências têm defaults oficiais. Não há criação automática de atendimentos ou relatos.

## Convenções comuns

- Identidade normal definida por JWT Bearer: `sub` identifica conta existente/ativa. `AUTH_MODE=jwt` é padrão. As 29 operações de produto e `/auth/me` exigem token; register/login/health são públicos. `user_id` na query de produto é rejeitado e nos comandos é campo extra inválido. Modo legado exige `AUTH_MODE=demo` explícito, restrito a desenvolvimento/teste e proibido em produção. Token inválido nunca cai para demo.
- IDs e revisões em **respostas JSON são strings decimais**, inclusive campos aninhados. O Flutter deve conservá-los como `String`, sem conversão para `double`/número JavaScript. Requests devem enviar strings decimais; a validação também aceita inteiros exatos. IDs positivos até BIGINT UNSIGNED; `expected_revision="0"` somente no PUT de criação de relato ausente.
- Instantes respondidos em ISO 8601 UTC com `Z`; persistência em UTC/DATETIME(6). `birth_date` e `reference_date` são datas, sem fuso. `remind_at` exige offset ou `Z` e é convertido para UTC. Não enviar datetime sem fuso.
- `from`/`to` aceitam data ISO ou instante com offset. Data `from` inicia à meia-noite no fuso do usuário; data `to` inclui o dia inteiro, usando a meia-noite seguinte como limite exclusivo. Instante `to` é exclusivo. Limites aceitos para filtros: anos 1000 a 9998. Início >= fim retorna 400. Dia depende do fuso IANA do usuário, atualmente America/Sao_Paulo.
- Paginação por `limit` (padrão 20, 1..100) e `offset` (padrão 0, 0..100000). `pagination.total` conta itens filtrados do titular antes da paginação. Coleções pequenas agregadas não são paginadas. Unidade lista por nome/id; agenda e lembretes por instante/id crescentes; histórico e notificações por instante/id decrescentes; filhos por posição/id.
- PUTs de perfil, saúde e preferências salvam o agregado completo, sem ETag/If-Match. Omissão de item nas listas de saúde/relato significa remoção. Campos extras são proibidos nos comandos. Em saúde, envie ambas as listas, mesmo vazias.
- IDs existentes de filhos devem pertencer ao agregado. Novos filhos omitem `id` ou usam `null`; não enviar IDs temporários locais. Resposta traz IDs definitivos. Seções podem reutilizar ID pela `section_key`; itens sem ID e idênticos na mesma posição também podem ser reconciliados para preservar no-op. Para manter/editar/reordenar um filho existente, sempre envie seu ID canônico.
- Campos de servidor (`position`, timestamps, titularidade, revisões resultantes, hash) não são editáveis. A ordem dos arrays determina `position`, começando em 0. `sus_card_number` é somente leitura nesta fase.
- Perfil: CPF 11 dígitos, CEP 8; telefones 10/11 dígitos nacionais ou 12/13 começando por 55. Pontuação usual é removida. UF é normalizada para maiúsculas e validada; complemento vazio vira null. Sem consulta de CPF, CEP ou SUS externa. Campos textuais obrigatórios indicados como `NonEmpty` são aparados e não podem ser vazios.
- Limites operacionais de saúde: até 200 medicamentos e 200 alergias; nome 80 e detalhes 160 caracteres. Lembrete: título 80. Relato: original/seção até 20000 caracteres, até 64 seções e 200 perguntas; pergunta até 4000; soma de textos de seções/perguntas até 100000. Não há corte silencioso nem limite de 500 caracteres. O apêndice de schemas registra todos os demais limites. São limites de conteúdo validado, não um firewall de tamanho do corpo HTTP.
- Sem push, scheduler ou entrega de lembretes. POST de lembrete retorna 201 e não possui idempotency key nesta versão: um retry após timeout pode criar outro lembrete. Não repetir automaticamente esse POST sem decisão do usuário/cliente. PUTs idênticos são seguros; presença atualiza o horário do salvamento explícito.
- `active`, `in_app` e as seis preferências de categoria controlam a visibilidade das notificações, sem apagá-las. `unread_count` é o total não lido **visível**, independente da página e dos filtros. GET não cria cartões. Marcar como lida preserva o primeiro `read_at`. Atualizar cartão de presença preserva `read_at` e `published_at`.
- Presença `unable` não cancela o atendimento e não avisa a unidade. Lembrete vinculado gera cartão interno; lembrete avulso não inventa destino. Atualização de checklist não gera novos cartões de documentos nesta fase.
- Autenticação mínima e titularidade por usuário implementadas; CORS não é autorização. Modo demo explícito ainda compartilha o titular configurado. Use somente dados fictícios: o MVP não foi liberado para dados sensíveis reais ou publicação em produção.

### Erros

As operações `/api/v1` usam envelope sanitizado:

```json
{"error":{"code":"resource_not_found","message":"Recurso não encontrado."}}
```

| HTTP | Códigos / sentido |
| --- | --- |
| 400 | `client_identity_forbidden`, `invalid_period`, `section_key_immutable`: comando semanticamente inválido |
| 404 | `resource_not_found`: ausente ou pertencente a outro titular, sem distinguir existência |
| 405 | `method_not_allowed`: método sem contrato nessa rota |
| 409 | `revision_conflict`, `report_not_ready`, `report_not_reviewed`, `state_conflict`: recarregar estado e decidir novamente |
| 422 | `validation_error`: campos, tipos, limites, versões obrigatórias ou extras inválidos |
| 500 | `internal_error`: falha interna sem SQL, payload ou traceback |
| 503 | `dependency_unavailable`, `demo_disabled`, `demo_user_unavailable`: dependência/contexto indisponível |

`/health` mantém o contrato de infraestrutura: 200 `{"status":"ok","database":"ok"}`, 503 `{"status":"unavailable","database":"unavailable"}` ou 500 `{"detail":"Erro interno."}`. Não revela detalhes do banco e não verifica a revisão Alembic.

## Estado de preparação e relato

As quatro etapas são calculadas no `PreparationService`: `documents_done` = todos os obrigatórios concluídos (zero obrigatórios = true); `attendance_done` = confirmed; `report_done` = original não vazio após trim; `final_done` = organização atual, alguma seção não vazia, revisão humana da versão atual e finalização dessa mesma versão. `completed_count`, `fraction` e `percentage` são derivados, nunca colunas.

A Home escolhe o primeiro atendimento a partir do início de **hoje no fuso do usuário**, inclusive horários de hoje já passados, preservando a V2 sem inventar status de realização. Sem próximo atendimento, `next_appointment` e `preparation` são null; `reference_date` informa o dia considerado. A fração do checklist obrigatório é separada do progresso das quatro macroetapas.

### Salvamento e concorrência do relato

1. GET do relato ausente retorna 404. PUT com `expected_revision="0"` pode criá-lo; o primeiro conteúdo terá revisão "1". Para relato existente, todos os comandos exigem a versão lida; versão diferente retorna 409, mesmo se o payload parecer idêntico.
2. PUT envia o conteúdo completo (`original_text`, `sections`, `questions`). `intent="edit"` é o padrão e preserva a procedência da organização. Alteração efetiva no original, seções/títulos/textos/ordem ou perguntas/textos/seleção/ordem incrementa `content_revision` uma vez. GET, no-op, checklist e presença não incrementam.
3. Para persistir resultado da organização **local/mock**, enviar `intent="organize"` e `organization_source_text` exatamente igual a `original_text`. Backend calcula SHA-256, nunca recebe hash. Original não vazio e pelo menos uma seção são exigidos; revisão humana também exige alguma seção com texto não vazio. Não há chamada de IA.
4. Organização da mesma fonte e conteúdo idêntico é no-op, preservando revisão/timestamps. Se apenas a procedência precisava ser atualizada para o original atual, o hash/horário podem mudar sem incrementar conteúdo.
5. Editar original deixa a organização anterior desatualizada. Editar conteúdo mantém números históricos de revisão/finalização, mas `reviewed` e `final_done` tornam-se false pela comparação com `content_revision`.
6. POST `/report/review` exige organização correspondente ao original e conteúdo válido; **zero perguntas ou zero selecionadas é permitido**. Repetir a revisão atual preserva `reviewed_at`.
7. PUT `/final-review` com `completed=true` exige revisão humana atual, sem exigir checklist ou presença concluídos. `completed=false` reabre deliberadamente e limpa apenas a marca de finalização. Repetição preserva estado/horários.
8. DELETE `/report/summary?expected_revision=...` mantém relato, original, IDs/chaves/títulos/ordem das seções; esvazia textos e exclui perguntas. Incrementa conteúdo apenas quando havia texto/perguntas a remover. Limpa procedência organizada; revisões anteriores tornam-se semanticamente inválidas. Repetição na versão atual é no-op. Não existe DELETE do relato inteiro.
9. Transação cobre pai, filhos, revisão e procedência. Locks em atendimento, relato e filhos fazem leitura atual do InnoDB; `version_id_col` acrescenta comparação no UPDATE. Reordenação libera posições finais com um flush de posições temporárias antes do flush final, evitando colisão intermediária UNIQUE.

No Flutter futuro, reter a revisão da resposta canônica, enviar a versão esperada em **todos** os comandos e, ao receber 409, recarregar sem sobrescrever a edição local automaticamente. Invalidar caches de preparo/overview após gravações. GET não confirma revisão por abrir tela.

## Mapa da integração Flutter

As interfaces atuais podem continuar tendo MockRepository e ApiRepository. Algumas retornam objetos agregados em memória: o adapter precisará compor respostas menores, armazenar IDs/revisões e recarregar o overview. Adapters implementados na Fase 3; autenticação e sessão acrescentadas na Fase 4.

| Flutter V2 atual | Contratos implementados / ajuste futuro |
| --- | --- |
| ProfileRepository.loadProfile / ProfileController.load | GET `/me/profile`; carregar preferências nos seus GETs separados |
| ProfileRepository.saveProfile / ProfileController.saveProfile | PUT `/me/profile`; excluir SUS/timestamps/ID do comando, aplicar resposta canônica |
| ProfileRepository.loadHealth / ProfileController.load | GET `/me/health-items` + GET `/me/health-records`; detalhe histórico sob demanda |
| ProfileRepository.saveHealth / ProfileController.saveHealth | PUT `/me/health-items`; manter IDs existentes e substituir ambas as listas; histórico permanece separado |
| PreparationRepository.loadOverview / PreparationController.load | GET `/preparation/overview`; GET `/appointments/{id}/preparation` para seleção por atendimento; GET `/report` separado |
| PreparationRepository.loadAppointments / PreparationController.load | GET `/appointments` paginado; GET detalhe; GET `/facilities` e detalhe para unidade quando necessário |
| PreparationRepository.loadReminders / PreparationController.load | GET `/reminders`; paginar até obter o período necessário |
| PreparationRepository.setChecklistItem / PreparationController.setChecklistItem | PATCH checklist; retorno ChecklistResponse; recarregar overview/preparation quando necessário |
| PreparationRepository.setAttendance / PreparationController.setAttendance | PUT attendance; enum Flutter `confirmed/undecided/unable` corresponde diretamente ao backend; recarregar preparo/notificações |
| PreparationRepository.addReminder / PreparationController.addReminder | POST `/reminders`; usar ID retornado; sem edição/exclusão e sem retry automático |
| PreparationRepository.saveReport / PreparationController.saveReportReview | PUT `/appointments/{id}/report`; enviar conteúdo integral, intenção e versão; POST review como comando explícito separado |
| PreparationRepository.setFinalReview / PreparationController.completeFinalReview | PUT `/final-review` com completed=true e revisão atual; resposta ReportRead, recarregar preparo |
| PreparationController.invalidateFinalReview | Mudança de conteúdo invalida por versão no servidor; reabertura deliberada usa PUT final-review completed=false |
| ReportController.setText / editSection | PUT report intent=edit no ponto de persistência futuro; manter estado de edição local |
| ReportController.organize | MockAiAssistantService continua local; persistir seu resultado com PUT report intent=organize + fonte original exata |
| ReportController.selectQuestion / selectAll / saveQuestion / removeQuestion / moveQuestion / dismissSuggestions | PUT report com array completo, seleção/ordem reais, IDs de filhos mantidos e expected_revision |
| ReportController.clearSummary | DELETE `/report/summary` com expected_revision; aplicar resposta canônica |
| ReportController.finishReview / completePreparation | POST review / PUT final-review respectivamente, sempre com versão atual |
| mock_notifications.dart / ProfileController.markRead / isRead | GET `/me/notifications`, PATCH `{is_read:true}`; futuro repository de notificações em lugar do Set local; badge usa unread_count |
| ProfileController.setNotification | GET/PUT `/me/notification-preferences`; enviar todos os booleanos, recarregar visibilidade |
| ProfileController.setAccessibility | GET/PUT `/me/accessibility-preferences`; salvar opções, resolver efeito/voz/capacidades no aparelho |
| AuthRepository / MockAuthRepository / ApiAuthRepository | POST auth/register/login e GET auth/me; mock permanece local |
| MockAudioDraftService / ReportController.*Audio / setTranscription / useTranscription | Sem endpoint de áudio/transcrição; somente o texto incorporado em original_text poderá ser persistido |
| SpeechController.speak / stop | Recurso local; sem endpoint |

Todos os paths da tabela, exceto `/health`, têm prefixo `/api/v1`. O adapter converte nomes de campos snake_case para os models Dart, sem inventar novos estados de atendimento.

## Catálogo de operações e schemas

As seções seguintes foram extraídas da especificação OpenAPI e exercitadas em banco **efêmero isolado**, com fixtures fictícias. Os exemplos não são dados extraídos do Aiven e não constituem uma sequência de requests a reproduzir na demo. Coleções exemplificadas usam `limit=1` para leitura; a tabela de parâmetros registra o padrão real 20. Schemas no apêndice são a fonte completa dos campos/tipos/limites. O OpenAPI também documenta IDs/revisões de requests como strings decimais para evitar perda de precisão em clientes Web.

### Índice

| Método | Path | Resposta |
| --- | --- | --- |
| POST | `/api/v1/auth/register` | 201 AuthSession |
| POST | `/api/v1/auth/login` | 200 AuthSession |
| GET | `/api/v1/auth/me` | 200 AuthUser |
| GET | `/health` | 200 HealthResponse |
| GET | `/api/v1/me/profile` | 200 ProfileRead |
| PUT | `/api/v1/me/profile` | 200 ProfileRead |
| GET | `/api/v1/facilities` | 200 Page_FacilityRead_ |
| GET | `/api/v1/facilities/{facility_id}` | 200 FacilityRead |
| GET | `/api/v1/appointments` | 200 Page_AppointmentRead_ |
| GET | `/api/v1/appointments/{appointment_id}` | 200 AppointmentDetail |
| GET | `/api/v1/appointments/{appointment_id}/preparation` | 200 PreparationRead |
| GET | `/api/v1/appointments/{appointment_id}/checklist` | 200 ChecklistResponse |
| PATCH | `/api/v1/appointments/{appointment_id}/checklist/{item_id}` | 200 ChecklistResponse |
| GET | `/api/v1/appointments/{appointment_id}/attendance` | 200 AttendanceRead |
| PUT | `/api/v1/appointments/{appointment_id}/attendance` | 200 AttendanceRead |
| GET | `/api/v1/preparation/overview` | 200 OverviewRead |
| GET | `/api/v1/reminders` | 200 Page_ReminderRead_ |
| POST | `/api/v1/reminders` | 201 ReminderRead |
| GET | `/api/v1/me/health-items` | 200 HealthItemsRead |
| PUT | `/api/v1/me/health-items` | 200 HealthItemsRead |
| GET | `/api/v1/me/health-records` | 200 Page_HistoryRead_ |
| GET | `/api/v1/me/health-records/{record_id}` | 200 HistoryDetail |
| GET | `/api/v1/appointments/{appointment_id}/report` | 200 ReportRead |
| PUT | `/api/v1/appointments/{appointment_id}/report` | 200 ReportRead |
| DELETE | `/api/v1/appointments/{appointment_id}/report/summary` | 200 ReportRead |
| POST | `/api/v1/appointments/{appointment_id}/report/review` | 200 ReportRead |
| PUT | `/api/v1/appointments/{appointment_id}/final-review` | 200 ReportRead |
| GET | `/api/v1/me/notifications` | 200 NotificationPage |
| PATCH | `/api/v1/me/notifications/{notification_id}` | 200 NotificationRead |
| GET | `/api/v1/me/notification-preferences` | 200 NotificationPreferencesDTO |
| PUT | `/api/v1/me/notification-preferences` | 200 NotificationPreferencesDTO |
| GET | `/api/v1/me/accessibility-preferences` | 200 AccessibilityPreferencesDTO |
| PUT | `/api/v1/me/accessibility-preferences` | 200 AccessibilityPreferencesDTO |

### GET /health

**Health**

Parâmetros de path/query: nenhum.


Request body: nenhum.


Response — HTTP 200, `HealthResponse`:

```json
{
  "status": "ok",
  "database": "ok"
}
```


Erros documentados: **503**. Aplicam-se os significados comuns acima; 409 é relevante nas mutações/versionamento. O envelope genérico não contém payload de entrada.

Estado: somente leitura; sem recriação de fixtures ou alteração de revisão.


### GET /api/v1/me/profile

**Carregar perfil do usuário autenticado**

Parâmetros de path/query: nenhum.


Request body: nenhum.


Response — HTTP 200, `ProfileRead`:

```json
{
  "full_name": "Maria da Silva",
  "email": "maria@example.test",
  "phone": "11999999999",
  "birth_date": "1985-04-12",
  "cpf": "12345678900",
  "postcode": "01000000",
  "street": "Av. das Flores",
  "number": "123",
  "complement": "Apto 12",
  "neighborhood": "Centro",
  "city": "São Paulo",
  "state_code": "SP",
  "emergency_name": "João da Silva",
  "emergency_relationship": "Familiar",
  "emergency_phone": "11988880000",
  "id": "1",
  "sus_card_number": "700123456789012",
  "created_at": "2026-10-09T12:53:51.152909Z",
  "updated_at": "2026-10-09T12:53:51.152922Z"
}
```


Erros documentados: **400, 404, 409, 422, 500, 503**. Aplicam-se os significados comuns acima; 409 é relevante nas mutações/versionamento. O envelope genérico não contém payload de entrada.

Estado: somente leitura; sem recriação de fixtures ou alteração de revisão.


### PUT /api/v1/me/profile

**Salvar perfil completo**

Parâmetros de path/query: nenhum.


Request — `ProfileWrite` (JSON):

```json
{
  "full_name": "Maria da Silva",
  "email": "maria@example.test",
  "phone": "11999999999",
  "birth_date": "1985-04-12",
  "cpf": "12345678900",
  "postcode": "01000000",
  "street": "Av. das Flores",
  "number": "123",
  "complement": "Apto 12",
  "neighborhood": "Centro",
  "city": "São Paulo",
  "state_code": "SP",
  "emergency_name": "João da Silva",
  "emergency_relationship": "Familiar",
  "emergency_phone": "11988880000"
}
```


Response — HTTP 200, `ProfileRead`:

```json
{
  "full_name": "Maria da Silva",
  "email": "maria@example.test",
  "phone": "11999999999",
  "birth_date": "1985-04-12",
  "cpf": "12345678900",
  "postcode": "01000000",
  "street": "Av. das Flores",
  "number": "123",
  "complement": "Apto 12",
  "neighborhood": "Centro",
  "city": "São Paulo",
  "state_code": "SP",
  "emergency_name": "João da Silva",
  "emergency_relationship": "Familiar",
  "emergency_phone": "11988880000",
  "id": "1",
  "sus_card_number": "700123456789012",
  "created_at": "2026-10-09T12:53:51.152909Z",
  "updated_at": "2026-10-09T12:53:51.152922Z"
}
```


Erros documentados: **400, 404, 409, 422, 500, 503**. Aplicam-se os significados comuns acima; 409 é relevante nas mutações/versionamento. O envelope genérico não contém payload de entrada.

Estado: salvamento em uma transação; campos de servidor definidos pelo backend. Esta operação não incrementa revisão de conteúdo do relato.


### GET /api/v1/facilities

**Listar unidades vinculadas à agenda**

| Parâmetro | Local | Obrigatório | Tipo | Limites / padrão |
| --- | --- | --- | --- | --- |
| `limit` | query | não | integer | default=20; minimum=1; maximum=100 |
| `offset` | query | não | integer | default=0; minimum=0; maximum=100000 |

Request body: nenhum.


Response — HTTP 200, `Page_FacilityRead_`:

```json
{
  "items": [
    {
      "id": "2",
      "name": "Laboratório Municipal",
      "address_text": "Rua do Cuidado, 45 – Centro, São Paulo – SP",
      "is_active": true
    }
  ],
  "pagination": {
    "limit": 1,
    "offset": 0,
    "total": 2
  }
}
```


Erros documentados: **400, 404, 409, 422, 500, 503**. Aplicam-se os significados comuns acima; 409 é relevante nas mutações/versionamento. O envelope genérico não contém payload de entrada.

Estado: somente leitura; sem recriação de fixtures ou alteração de revisão.


### GET /api/v1/facilities/{facility_id}

**Consultar unidade acessível**

| Parâmetro | Local | Obrigatório | Tipo | Limites / padrão |
| --- | --- | --- | --- | --- |
| `facility_id` | path | sim | string | maxLength=20; pattern="^[1-9][0-9]*$" |

Request body: nenhum.


Response — HTTP 200, `FacilityRead`:

```json
{
  "id": "1",
  "name": "UBS Centro",
  "address_text": "Av. das Flores, 123 – Centro, São Paulo – SP, 01000-000",
  "is_active": true
}
```


Erros documentados: **400, 404, 409, 422, 500, 503**. Aplicam-se os significados comuns acima; 409 é relevante nas mutações/versionamento. O envelope genérico não contém payload de entrada.

Estado: somente leitura; sem recriação de fixtures ou alteração de revisão.


### GET /api/v1/appointments

**Listar agenda do titular**

Datas são interpretadas no fuso do usuário; instantes exigem offset. Ordenação por scheduled_at e id.

| Parâmetro | Local | Obrigatório | Tipo | Limites / padrão |
| --- | --- | --- | --- | --- |
| `limit` | query | não | integer | default=20; minimum=1; maximum=100 |
| `offset` | query | não | integer | default=0; minimum=0; maximum=100000 |
| `from` | query | não | string (date) ou string (date-time) ou null | — |
| `to` | query | não | string (date) ou string (date-time) ou null | — |
| `type` | query | não | string ou null | enum=["consultation", "exam"] |
| `query` | query | não | string ou null | maxLength=120 |

Request body: nenhum.


Response — HTTP 200, `Page_AppointmentRead_`:

```json
{
  "items": [
    {
      "id": "1",
      "type": "consultation",
      "title": "Consulta clínica",
      "specialty": "Clínica geral",
      "professional_name": "Dra. Ana Beatriz Souza",
      "scheduled_at": "2026-10-09T11:00:00Z",
      "timezone": "America/Sao_Paulo",
      "facility": {
        "id": "1",
        "name": "UBS Centro",
        "address_text": "Av. das Flores, 123 – Centro, São Paulo – SP, 01000-000",
        "is_active": true
      },
      "attendance_status": "confirmed"
    }
  ],
  "pagination": {
    "limit": 1,
    "offset": 0,
    "total": 3
  }
}
```


Erros documentados: **400, 404, 409, 422, 500, 503**. Aplicam-se os significados comuns acima; 409 é relevante nas mutações/versionamento. O envelope genérico não contém payload de entrada.

Estado: somente leitura; sem recriação de fixtures ou alteração de revisão.


### GET /api/v1/appointments/{appointment_id}

**Consultar atendimento e orientações**

| Parâmetro | Local | Obrigatório | Tipo | Limites / padrão |
| --- | --- | --- | --- | --- |
| `appointment_id` | path | sim | string | maxLength=20; pattern="^[1-9][0-9]*$" |

Request body: nenhum.


Response — HTTP 200, `AppointmentDetail`:

```json
{
  "id": "1",
  "type": "consultation",
  "title": "Consulta clínica",
  "specialty": "Clínica geral",
  "professional_name": "Dra. Ana Beatriz Souza",
  "scheduled_at": "2026-10-09T11:00:00Z",
  "timezone": "America/Sao_Paulo",
  "facility": {
    "id": "1",
    "name": "UBS Centro",
    "address_text": "Av. das Flores, 123 – Centro, São Paulo – SP, 01000-000",
    "is_active": true
  },
  "attendance_status": "confirmed",
  "instructions": [
    "Chegue com 15 minutos de antecedência.",
    "Jejum não é necessário para esta consulta."
  ],
  "attendance_responded_at": "2026-10-07T13:00:00Z"
}
```


Erros documentados: **400, 404, 409, 422, 500, 503**. Aplicam-se os significados comuns acima; 409 é relevante nas mutações/versionamento. O envelope genérico não contém payload de entrada.

Estado: somente leitura; sem recriação de fixtures ou alteração de revisão.


### GET /api/v1/appointments/{appointment_id}/preparation

**Calcular as quatro etapas de preparo**

| Parâmetro | Local | Obrigatório | Tipo | Limites / padrão |
| --- | --- | --- | --- | --- |
| `appointment_id` | path | sim | string | maxLength=20; pattern="^[1-9][0-9]*$" |

Request body: nenhum.


Response — HTTP 200, `PreparationRead`:

```json
{
  "appointment": {
    "id": "1",
    "type": "consultation",
    "title": "Consulta clínica",
    "specialty": "Clínica geral",
    "professional_name": "Dra. Ana Beatriz Souza",
    "scheduled_at": "2026-10-09T11:00:00Z",
    "timezone": "America/Sao_Paulo",
    "facility": {
      "id": "1",
      "name": "UBS Centro",
      "address_text": "Av. das Flores, 123 – Centro, São Paulo – SP, 01000-000",
      "is_active": true
    },
    "attendance_status": "confirmed"
  },
  "progress": {
    "documents_done": true,
    "attendance_done": true,
    "report_done": true,
    "final_done": false,
    "completed_count": 3,
    "total_count": 4,
    "fraction": 0.75,
    "percentage": 75
  },
  "checklist": {
    "required_count": 2,
    "required_completed_count": 2,
    "fraction": 1.0,
    "percentage": 100
  },
  "attendance": {
    "attendance_status": "confirmed",
    "appointment_id": "1",
    "attendance_responded_at": "2026-10-07T13:00:00Z"
  },
  "report": {
    "organization_current": false,
    "has_content": false,
    "reviewed": false,
    "final_done": false
  }
}
```


Erros documentados: **400, 404, 409, 422, 500, 503**. Aplicam-se os significados comuns acima; 409 é relevante nas mutações/versionamento. O envelope genérico não contém payload de entrada.

Estado: somente leitura; sem recriação de fixtures ou alteração de revisão.


### GET /api/v1/appointments/{appointment_id}/checklist

**Carregar checklist e progresso derivado**

| Parâmetro | Local | Obrigatório | Tipo | Limites / padrão |
| --- | --- | --- | --- | --- |
| `appointment_id` | path | sim | string | maxLength=20; pattern="^[1-9][0-9]*$" |

Request body: nenhum.


Response — HTTP 200, `ChecklistResponse`:

```json
{
  "required_count": 2,
  "required_completed_count": 2,
  "fraction": 1.0,
  "percentage": 100,
  "items": [
    {
      "id": "1",
      "item_key": "documento",
      "title": "Documento com foto",
      "section": "documents",
      "is_required": true,
      "is_completed": true,
      "position": 0
    },
    {
      "id": "2",
      "item_key": "sus",
      "title": "Cartão do SUS",
      "section": "documents",
      "is_required": true,
      "is_completed": true,
      "position": 1
    },
    {
      "id": "3",
      "item_key": "exames",
      "title": "Comprovantes ou exames anteriores",
      "section": "documents",
      "is_required": false,
      "is_completed": true,
      "position": 2
    },
    {
      "id": "4",
      "item_key": "antecedencia",
      "title": "Chegar 15 minutos antes",
      "section": "reminders",
      "is_required": false,
      "is_completed": false,
      "position": 3
    },
    {
      "id": "5",
      "item_key": "duvidas",
      "title": "Separar dúvidas e sintomas",
      "section": "reminders",
      "is_required": false,
      "is_completed": true,
      "position": 4
    },
    {
      "id": "6",
      "item_key": "medicamentos",
      "title": "Levar lista de medicamentos, se usar",
      "section": "conversation",
      "is_required": false,
      "is_completed": false,
      "position": 5
    },
    {
      "id": "7",
      "item_key": "sintomas",
      "title": "Contar o que deseja conversar",
      "section": "conversation",
      "is_required": false,
      "is_completed": false,
      "position": 6
    }
  ],
  "progress": {
    "documents_done": true,
    "attendance_done": true,
    "report_done": true,
    "final_done": false,
    "completed_count": 3,
    "total_count": 4,
    "fraction": 0.75,
    "percentage": 75
  }
}
```


Erros documentados: **400, 404, 409, 422, 500, 503**. Aplicam-se os significados comuns acima; 409 é relevante nas mutações/versionamento. O envelope genérico não contém payload de entrada.

Estado: somente leitura; sem recriação de fixtures ou alteração de revisão.


### PATCH /api/v1/appointments/{appointment_id}/checklist/{item_id}

**Marcar um item do checklist**

| Parâmetro | Local | Obrigatório | Tipo | Limites / padrão |
| --- | --- | --- | --- | --- |
| `appointment_id` | path | sim | string | maxLength=20; pattern="^[1-9][0-9]*$" |
| `item_id` | path | sim | string | maxLength=20; pattern="^[1-9][0-9]*$" |

Request — `ChecklistWrite` (JSON):

```json
{
  "is_completed": true
}
```


Response — HTTP 200, `ChecklistResponse`:

```json
{
  "required_count": 2,
  "required_completed_count": 2,
  "fraction": 1.0,
  "percentage": 100,
  "items": [
    {
      "id": "1",
      "item_key": "documento",
      "title": "Documento com foto",
      "section": "documents",
      "is_required": true,
      "is_completed": true,
      "position": 0
    },
    {
      "id": "2",
      "item_key": "sus",
      "title": "Cartão do SUS",
      "section": "documents",
      "is_required": true,
      "is_completed": true,
      "position": 1
    },
    {
      "id": "3",
      "item_key": "exames",
      "title": "Comprovantes ou exames anteriores",
      "section": "documents",
      "is_required": false,
      "is_completed": true,
      "position": 2
    },
    {
      "id": "4",
      "item_key": "antecedencia",
      "title": "Chegar 15 minutos antes",
      "section": "reminders",
      "is_required": false,
      "is_completed": false,
      "position": 3
    },
    {
      "id": "5",
      "item_key": "duvidas",
      "title": "Separar dúvidas e sintomas",
      "section": "reminders",
      "is_required": false,
      "is_completed": true,
      "position": 4
    },
    {
      "id": "6",
      "item_key": "medicamentos",
      "title": "Levar lista de medicamentos, se usar",
      "section": "conversation",
      "is_required": false,
      "is_completed": false,
      "position": 5
    },
    {
      "id": "7",
      "item_key": "sintomas",
      "title": "Contar o que deseja conversar",
      "section": "conversation",
      "is_required": false,
      "is_completed": false,
      "position": 6
    }
  ],
  "progress": {
    "documents_done": true,
    "attendance_done": true,
    "report_done": true,
    "final_done": false,
    "completed_count": 3,
    "total_count": 4,
    "fraction": 0.75,
    "percentage": 75
  }
}
```


Erros documentados: **400, 404, 409, 422, 500, 503**. Aplicam-se os significados comuns acima; 409 é relevante nas mutações/versionamento. O envelope genérico não contém payload de entrada.

Estado: salvamento em uma transação; campos de servidor definidos pelo backend. Esta operação não incrementa revisão de conteúdo do relato.


### GET /api/v1/appointments/{appointment_id}/attendance

**Carregar intenção de comparecimento**

| Parâmetro | Local | Obrigatório | Tipo | Limites / padrão |
| --- | --- | --- | --- | --- |
| `appointment_id` | path | sim | string | maxLength=20; pattern="^[1-9][0-9]*$" |

Request body: nenhum.


Response — HTTP 200, `AttendanceRead`:

```json
{
  "attendance_status": "confirmed",
  "appointment_id": "1",
  "attendance_responded_at": "2026-10-07T13:00:00Z"
}
```


Erros documentados: **400, 404, 409, 422, 500, 503**. Aplicam-se os significados comuns acima; 409 é relevante nas mutações/versionamento. O envelope genérico não contém payload de entrada.

Estado: somente leitura; sem recriação de fixtures ou alteração de revisão.


### PUT /api/v1/appointments/{appointment_id}/attendance

**Registrar presença no aplicativo**

unable não cancela nem avisa a unidade. Horário da resposta é definido pelo servidor.

| Parâmetro | Local | Obrigatório | Tipo | Limites / padrão |
| --- | --- | --- | --- | --- |
| `appointment_id` | path | sim | string | maxLength=20; pattern="^[1-9][0-9]*$" |

Request — `AttendanceWrite` (JSON):

```json
{
  "attendance_status": "confirmed"
}
```


Response — HTTP 200, `AttendanceRead`:

```json
{
  "attendance_status": "confirmed",
  "appointment_id": "1",
  "attendance_responded_at": "2026-10-09T12:53:52.181791Z"
}
```


Erros documentados: **400, 404, 409, 422, 500, 503**. Aplicam-se os significados comuns acima; 409 é relevante nas mutações/versionamento. O envelope genérico não contém payload de entrada.

Estado: salvamento em uma transação; campos de servidor definidos pelo backend. Esta operação não incrementa revisão de conteúdo do relato.


### GET /api/v1/preparation/overview

**Carregar preparo para a Home**

Inclui atendimentos de hoje no fuso do titular. Sem próximo atendimento, retorna next_appointment/preparation null.

Parâmetros de path/query: nenhum.


Request body: nenhum.


Response — HTTP 200, `OverviewRead`:

```json
{
  "user": {
    "id": "1",
    "full_name": "Maria da Silva",
    "first_name": "Maria",
    "timezone": "America/Sao_Paulo"
  },
  "reference_date": "2026-10-09",
  "next_appointment": {
    "id": "1",
    "type": "consultation",
    "title": "Consulta clínica",
    "specialty": "Clínica geral",
    "professional_name": "Dra. Ana Beatriz Souza",
    "scheduled_at": "2026-10-09T11:00:00Z",
    "timezone": "America/Sao_Paulo",
    "facility": {
      "id": "1",
      "name": "UBS Centro",
      "address_text": "Av. das Flores, 123 – Centro, São Paulo – SP, 01000-000",
      "is_active": true
    },
    "attendance_status": "confirmed"
  },
  "preparation": {
    "appointment": {
      "id": "1",
      "type": "consultation",
      "title": "Consulta clínica",
      "specialty": "Clínica geral",
      "professional_name": "Dra. Ana Beatriz Souza",
      "scheduled_at": "2026-10-09T11:00:00Z",
      "timezone": "America/Sao_Paulo",
      "facility": {
        "id": "1",
        "name": "UBS Centro",
        "address_text": "Av. das Flores, 123 – Centro, São Paulo – SP, 01000-000",
        "is_active": true
      },
      "attendance_status": "confirmed"
    },
    "progress": {
      "documents_done": true,
      "attendance_done": true,
      "report_done": true,
      "final_done": false,
      "completed_count": 3,
      "total_count": 4,
      "fraction": 0.75,
      "percentage": 75
    },
    "checklist": {
      "required_count": 2,
      "required_completed_count": 2,
      "fraction": 1.0,
      "percentage": 100
    },
    "attendance": {
      "attendance_status": "confirmed",
      "appointment_id": "1",
      "attendance_responded_at": "2026-10-07T13:00:00Z"
    },
    "report": {
      "organization_current": false,
      "has_content": false,
      "reviewed": false,
      "final_done": false
    }
  }
}
```


Erros documentados: **400, 404, 409, 422, 500, 503**. Aplicam-se os significados comuns acima; 409 é relevante nas mutações/versionamento. O envelope genérico não contém payload de entrada.

Estado: somente leitura; sem recriação de fixtures ou alteração de revisão.


### GET /api/v1/reminders

**Listar lembretes pessoais**

| Parâmetro | Local | Obrigatório | Tipo | Limites / padrão |
| --- | --- | --- | --- | --- |
| `limit` | query | não | integer | default=20; minimum=1; maximum=100 |
| `offset` | query | não | integer | default=0; minimum=0; maximum=100000 |
| `from` | query | não | string (date) ou string (date-time) ou null | — |
| `to` | query | não | string (date) ou string (date-time) ou null | — |
| `appointment_id` | query | não | string ou null | maxLength=20; pattern="^[1-9][0-9]*$" |

Request body: nenhum.


Response — HTTP 200, `Page_ReminderRead_`:

```json
{
  "items": [
    {
      "id": "1",
      "title": "Levar documento com foto",
      "remind_at": "2026-10-09T10:30:00Z",
      "appointment_id": null,
      "created_at": "2026-10-09T12:53:51.159358Z"
    }
  ],
  "pagination": {
    "limit": 1,
    "offset": 0,
    "total": 1
  }
}
```


Erros documentados: **400, 404, 409, 422, 500, 503**. Aplicam-se os significados comuns acima; 409 é relevante nas mutações/versionamento. O envelope genérico não contém payload de entrada.

Estado: somente leitura; sem recriação de fixtures ou alteração de revisão.


### POST /api/v1/reminders

**Salvar lembrete com horário absoluto**

Sem alarme, push ou scheduler. POST não possui deduplicação por retry nesta versão.

Parâmetros de path/query: nenhum.


Request — `ReminderWrite` (JSON):

```json
{
  "title": "Separar documentos fictícios",
  "remind_at": "2026-10-13T09:00:00-03:00",
  "appointment_id": "2"
}
```


Response — HTTP 201, `ReminderRead`:

```json
{
  "id": "2",
  "title": "Separar documentos fictícios",
  "remind_at": "2026-10-13T12:00:00Z",
  "appointment_id": "2",
  "created_at": "2026-10-09T12:53:52.221656Z"
}
```


Erros documentados: **400, 404, 409, 422, 500, 503**. Aplicam-se os significados comuns acima; 409 é relevante nas mutações/versionamento. O envelope genérico não contém payload de entrada.

Estado: salvamento em uma transação; campos de servidor definidos pelo backend. Esta operação não incrementa revisão de conteúdo do relato.


### GET /api/v1/me/health-items

**Carregar medicamentos e alergias**

Parâmetros de path/query: nenhum.


Request body: nenhum.


Response — HTTP 200, `HealthItemsRead`:

```json
{
  "medications": [
    {
      "id": "1",
      "name": "Losartana",
      "details": "50 mg • 1x ao dia",
      "position": 0
    },
    {
      "id": "2",
      "name": "Metformina",
      "details": "850 mg • 2x ao dia",
      "position": 1
    },
    {
      "id": "3",
      "name": "Omeprazol",
      "details": "20 mg • pela manhã",
      "position": 2
    },
    {
      "id": "4",
      "name": "Vitamina D",
      "details": "1 cápsula por semana",
      "position": 3
    }
  ],
  "allergies": [
    {
      "id": "1",
      "name": "Dipirona",
      "details": "Reação: coceira",
      "position": 0
    },
    {
      "id": "2",
      "name": "Frutos do mar",
      "details": "Reação: inchaço",
      "position": 1
    },
    {
      "id": "3",
      "name": "Látex",
      "details": "Reação: irritação na pele",
      "position": 2
    }
  ]
}
```


Erros documentados: **400, 404, 409, 422, 500, 503**. Aplicam-se os significados comuns acima; 409 é relevante nas mutações/versionamento. O envelope genérico não contém payload de entrada.

Estado: somente leitura; sem recriação de fixtures ou alteração de revisão.


### PUT /api/v1/me/health-items

**Salvar as duas listas de saúde atomicamente**

Substituição completa: omitir um item remove-o da lista. Envie IDs existentes para manter/editar itens; omita o ID de novos itens. Itens idênticos sem ID podem ser reconciliados na mesma posição.

Parâmetros de path/query: nenhum.


Request — `HealthItemsWrite` (JSON):

```json
{
  "medications": [
    {
      "id": "1",
      "name": "Losartana",
      "details": "50 mg • 1x ao dia"
    },
    {
      "id": "2",
      "name": "Metformina",
      "details": "850 mg • 2x ao dia"
    },
    {
      "id": "3",
      "name": "Omeprazol",
      "details": "20 mg • pela manhã"
    },
    {
      "id": "4",
      "name": "Vitamina D",
      "details": "1 cápsula por semana"
    }
  ],
  "allergies": [
    {
      "id": "1",
      "name": "Dipirona",
      "details": "Reação: coceira"
    },
    {
      "id": "2",
      "name": "Frutos do mar",
      "details": "Reação: inchaço"
    },
    {
      "id": "3",
      "name": "Látex",
      "details": "Reação: irritação na pele"
    }
  ]
}
```


Response — HTTP 200, `HealthItemsRead`:

```json
{
  "medications": [
    {
      "id": "1",
      "name": "Losartana",
      "details": "50 mg • 1x ao dia",
      "position": 0
    },
    {
      "id": "2",
      "name": "Metformina",
      "details": "850 mg • 2x ao dia",
      "position": 1
    },
    {
      "id": "3",
      "name": "Omeprazol",
      "details": "20 mg • pela manhã",
      "position": 2
    },
    {
      "id": "4",
      "name": "Vitamina D",
      "details": "1 cápsula por semana",
      "position": 3
    }
  ],
  "allergies": [
    {
      "id": "1",
      "name": "Dipirona",
      "details": "Reação: coceira",
      "position": 0
    },
    {
      "id": "2",
      "name": "Frutos do mar",
      "details": "Reação: inchaço",
      "position": 1
    },
    {
      "id": "3",
      "name": "Látex",
      "details": "Reação: irritação na pele",
      "position": 2
    }
  ]
}
```


Erros documentados: **400, 404, 409, 422, 500, 503**. Aplicam-se os significados comuns acima; 409 é relevante nas mutações/versionamento. O envelope genérico não contém payload de entrada.

Estado: salvamento em uma transação; campos de servidor definidos pelo backend. Esta operação não incrementa revisão de conteúdo do relato.


### GET /api/v1/me/health-records

**Listar histórico preexistente**

| Parâmetro | Local | Obrigatório | Tipo | Limites / padrão |
| --- | --- | --- | --- | --- |
| `limit` | query | não | integer | default=20; minimum=1; maximum=100 |
| `offset` | query | não | integer | default=0; minimum=0; maximum=100000 |
| `from` | query | não | string (date) ou string (date-time) ou null | — |
| `to` | query | não | string (date) ou string (date-time) ou null | — |
| `type` | query | não | string ou null | enum=["consultation", "exam", "medication", "allergy", "diagnosis"] |

Request body: nenhum.


Response — HTTP 200, `Page_HistoryRead_`:

```json
{
  "items": [
    {
      "id": "1",
      "type": "consultation",
      "occurred_at": "2026-10-06T11:00:00Z",
      "title": "Clínica geral",
      "subtitle": "UBS Centro – Dra. Ana Beatriz Souza"
    }
  ],
  "pagination": {
    "limit": 1,
    "offset": 0,
    "total": 6
  }
}
```


Erros documentados: **400, 404, 409, 422, 500, 503**. Aplicam-se os significados comuns acima; 409 é relevante nas mutações/versionamento. O envelope genérico não contém payload de entrada.

Estado: somente leitura; sem recriação de fixtures ou alteração de revisão.


### GET /api/v1/me/health-records/{record_id}

**Carregar registro e documentos textuais**

| Parâmetro | Local | Obrigatório | Tipo | Limites / padrão |
| --- | --- | --- | --- | --- |
| `record_id` | path | sim | string | maxLength=20; pattern="^[1-9][0-9]*$" |

Request body: nenhum.


Response — HTTP 200, `HistoryDetail`:

```json
{
  "id": "1",
  "type": "consultation",
  "occurred_at": "2026-10-06T11:00:00Z",
  "title": "Clínica geral",
  "subtitle": "UBS Centro – Dra. Ana Beatriz Souza",
  "professional_text": "Dra. Ana Beatriz Souza",
  "facility_text": "UBS Centro",
  "reason": "Conversa sobre rotina e dúvidas anotadas para o atendimento.",
  "summary": "Registro fictício de atendimento anterior, distinto da consulta futura de 9/10.",
  "notes": [
    "Anotar o que deseja conversar no próximo atendimento.",
    "Guardar os documentos recebidos."
  ],
  "documents": [
    {
      "id": "1",
      "title": "Anotações do atendimento",
      "content_text": "Exemplo fictício: atendimento em 6/10/2026. Anotações pessoais.",
      "position": 0
    },
    {
      "id": "2",
      "title": "Documentos do atendimento",
      "content_text": "Exemplo fictício, sem receita, laudo ou encaminhamento válido.",
      "position": 1
    }
  ]
}
```


Erros documentados: **400, 404, 409, 422, 500, 503**. Aplicam-se os significados comuns acima; 409 é relevante nas mutações/versionamento. O envelope genérico não contém payload de entrada.

Estado: somente leitura; sem recriação de fixtures ou alteração de revisão.


### GET /api/v1/appointments/{appointment_id}/report

**Carregar relato estruturado e revisões**

| Parâmetro | Local | Obrigatório | Tipo | Limites / padrão |
| --- | --- | --- | --- | --- |
| `appointment_id` | path | sim | string | maxLength=20; pattern="^[1-9][0-9]*$" |

Request body: nenhum.


Response — HTTP 200, `ReportRead`:

```json
{
  "organization_current": false,
  "has_content": false,
  "reviewed": false,
  "final_done": false,
  "id": "1",
  "appointment_id": "1",
  "original_text": "Quero lembrar de conversar sobre como tenho dormido e tirar minhas dúvidas durante a consulta.",
  "organized_at": null,
  "content_revision": "1",
  "reviewed_revision": null,
  "reviewed_at": null,
  "final_review_revision": null,
  "final_review_at": null,
  "updated_at": "2026-10-07T13:00:00Z",
  "sections": [],
  "questions": []
}
```


Erros documentados: **400, 404, 409, 422, 500, 503**. Aplicam-se os significados comuns acima; 409 é relevante nas mutações/versionamento. O envelope genérico não contém payload de entrada.

Estado/versionamento: segue as regras de relato descritas acima; resposta canônica inclui revisão e flags. GET não altera estado.


### PUT /api/v1/appointments/{appointment_id}/report

**Salvar conteúdo do relato com versão esperada**

expected_revision=0 cria um relato ausente; versões antigas geram 409. intent=organize exige organization_source_text igual ao original enviado; edit preserva a fonte anterior. Ordem das listas define position.

| Parâmetro | Local | Obrigatório | Tipo | Limites / padrão |
| --- | --- | --- | --- | --- |
| `appointment_id` | path | sim | string | maxLength=20; pattern="^[1-9][0-9]*$" |

Request — `ReportWrite` (JSON):

```json
{
  "expected_revision": "1",
  "original_text": "Quero lembrar de conversar sobre como tenho dormido e tirar minhas dúvidas durante a consulta.",
  "intent": "organize",
  "organization_source_text": "Quero lembrar de conversar sobre como tenho dormido e tirar minhas dúvidas durante a consulta.",
  "sections": [
    {
      "section_key": "reason",
      "title": "reason",
      "text": "Conteúdo fictício organizado."
    },
    {
      "section_key": "points",
      "title": "points",
      "text": ""
    },
    {
      "section_key": "context",
      "title": "context",
      "text": ""
    },
    {
      "section_key": "other",
      "title": "other",
      "text": ""
    }
  ],
  "questions": [
    {
      "text": "O que devo levar para a próxima conversa?",
      "is_selected": false
    }
  ]
}
```


Response — HTTP 200, `ReportRead`:

```json
{
  "organization_current": true,
  "has_content": true,
  "reviewed": false,
  "final_done": false,
  "id": "1",
  "appointment_id": "1",
  "original_text": "Quero lembrar de conversar sobre como tenho dormido e tirar minhas dúvidas durante a consulta.",
  "organized_at": "2026-10-09T12:53:52.253591Z",
  "content_revision": "2",
  "reviewed_revision": null,
  "reviewed_at": null,
  "final_review_revision": null,
  "final_review_at": null,
  "updated_at": "2026-10-09T12:53:52.253605Z",
  "sections": [
    {
      "id": "1",
      "section_key": "reason",
      "title": "reason",
      "text": "Conteúdo fictício organizado.",
      "position": 0
    },
    {
      "id": "2",
      "section_key": "points",
      "title": "points",
      "text": "",
      "position": 1
    },
    {
      "id": "3",
      "section_key": "context",
      "title": "context",
      "text": "",
      "position": 2
    },
    {
      "id": "4",
      "section_key": "other",
      "title": "other",
      "text": "",
      "position": 3
    }
  ],
  "questions": [
    {
      "id": "1",
      "text": "O que devo levar para a próxima conversa?",
      "is_selected": false,
      "position": 0
    }
  ]
}
```


Erros documentados: **400, 404, 409, 422, 500, 503**. Aplicam-se os significados comuns acima; 409 é relevante nas mutações/versionamento. O envelope genérico não contém payload de entrada.

Estado/versionamento: segue as regras de relato descritas acima; resposta canônica inclui revisão e flags. GET não altera estado.


### DELETE /api/v1/appointments/{appointment_id}/report/summary

**Remover resumo preservando relato original**

| Parâmetro | Local | Obrigatório | Tipo | Limites / padrão |
| --- | --- | --- | --- | --- |
| `appointment_id` | path | sim | string | maxLength=20; pattern="^[1-9][0-9]*$" |
| `expected_revision` | query | sim | string | maxLength=20; pattern="^[1-9][0-9]*$" |

Request body: nenhum.


Response — HTTP 200, `ReportRead`:

```json
{
  "organization_current": false,
  "has_content": false,
  "reviewed": false,
  "final_done": false,
  "id": "1",
  "appointment_id": "1",
  "original_text": "Quero lembrar de conversar sobre como tenho dormido e tirar minhas dúvidas durante a consulta.",
  "organized_at": null,
  "content_revision": "3",
  "reviewed_revision": "2",
  "reviewed_at": "2026-10-09T12:53:52.267868Z",
  "final_review_revision": "2",
  "final_review_at": "2026-10-09T12:53:52.282070Z",
  "updated_at": "2026-10-09T12:53:52.297231Z",
  "sections": [
    {
      "id": "1",
      "section_key": "reason",
      "title": "reason",
      "text": "",
      "position": 0
    },
    {
      "id": "2",
      "section_key": "points",
      "title": "points",
      "text": "",
      "position": 1
    },
    {
      "id": "3",
      "section_key": "context",
      "title": "context",
      "text": "",
      "position": 2
    },
    {
      "id": "4",
      "section_key": "other",
      "title": "other",
      "text": "",
      "position": 3
    }
  ],
  "questions": []
}
```


Erros documentados: **400, 404, 409, 422, 500, 503**. Aplicam-se os significados comuns acima; 409 é relevante nas mutações/versionamento. O envelope genérico não contém payload de entrada.

Exemplo de query: `?expected_revision=2`. Preserva original e estrutura das seções; somente o resumo é removido.

Estado/versionamento: segue as regras de relato descritas acima; resposta canônica inclui revisão e flags. GET não altera estado.


### POST /api/v1/appointments/{appointment_id}/report/review

**Confirmar revisão humana da versão atual**

| Parâmetro | Local | Obrigatório | Tipo | Limites / padrão |
| --- | --- | --- | --- | --- |
| `appointment_id` | path | sim | string | maxLength=20; pattern="^[1-9][0-9]*$" |

Request — `RevisionCommand` (JSON):

```json
{
  "expected_revision": "2"
}
```


Response — HTTP 200, `ReportRead`:

```json
{
  "organization_current": true,
  "has_content": true,
  "reviewed": true,
  "final_done": false,
  "id": "1",
  "appointment_id": "1",
  "original_text": "Quero lembrar de conversar sobre como tenho dormido e tirar minhas dúvidas durante a consulta.",
  "organized_at": "2026-10-09T12:53:52.253591Z",
  "content_revision": "2",
  "reviewed_revision": "2",
  "reviewed_at": "2026-10-09T12:53:52.267868Z",
  "final_review_revision": null,
  "final_review_at": null,
  "updated_at": "2026-10-09T12:53:52.269373Z",
  "sections": [
    {
      "id": "1",
      "section_key": "reason",
      "title": "reason",
      "text": "Conteúdo fictício organizado.",
      "position": 0
    },
    {
      "id": "2",
      "section_key": "points",
      "title": "points",
      "text": "",
      "position": 1
    },
    {
      "id": "3",
      "section_key": "context",
      "title": "context",
      "text": "",
      "position": 2
    },
    {
      "id": "4",
      "section_key": "other",
      "title": "other",
      "text": "",
      "position": 3
    }
  ],
  "questions": [
    {
      "id": "1",
      "text": "O que devo levar para a próxima conversa?",
      "is_selected": false,
      "position": 0
    }
  ]
}
```


Erros documentados: **400, 404, 409, 422, 500, 503**. Aplicam-se os significados comuns acima; 409 é relevante nas mutações/versionamento. O envelope genérico não contém payload de entrada.

Estado/versionamento: segue as regras de relato descritas acima; resposta canônica inclui revisão e flags. GET não altera estado.


### PUT /api/v1/appointments/{appointment_id}/final-review

**Concluir ou reabrir a revisão final**

| Parâmetro | Local | Obrigatório | Tipo | Limites / padrão |
| --- | --- | --- | --- | --- |
| `appointment_id` | path | sim | string | maxLength=20; pattern="^[1-9][0-9]*$" |

Request — `FinalReviewWrite` (JSON):

```json
{
  "expected_revision": "2",
  "completed": true
}
```


Response — HTTP 200, `ReportRead`:

```json
{
  "organization_current": true,
  "has_content": true,
  "reviewed": true,
  "final_done": true,
  "id": "1",
  "appointment_id": "1",
  "original_text": "Quero lembrar de conversar sobre como tenho dormido e tirar minhas dúvidas durante a consulta.",
  "organized_at": "2026-10-09T12:53:52.253591Z",
  "content_revision": "2",
  "reviewed_revision": "2",
  "reviewed_at": "2026-10-09T12:53:52.267868Z",
  "final_review_revision": "2",
  "final_review_at": "2026-10-09T12:53:52.282070Z",
  "updated_at": "2026-10-09T12:53:52.283063Z",
  "sections": [
    {
      "id": "1",
      "section_key": "reason",
      "title": "reason",
      "text": "Conteúdo fictício organizado.",
      "position": 0
    },
    {
      "id": "2",
      "section_key": "points",
      "title": "points",
      "text": "",
      "position": 1
    },
    {
      "id": "3",
      "section_key": "context",
      "title": "context",
      "text": "",
      "position": 2
    },
    {
      "id": "4",
      "section_key": "other",
      "title": "other",
      "text": "",
      "position": 3
    }
  ],
  "questions": [
    {
      "id": "1",
      "text": "O que devo levar para a próxima conversa?",
      "is_selected": false,
      "position": 0
    }
  ]
}
```


Erros documentados: **400, 404, 409, 422, 500, 503**. Aplicam-se os significados comuns acima; 409 é relevante nas mutações/versionamento. O envelope genérico não contém payload de entrada.

Estado/versionamento: segue as regras de relato descritas acima; resposta canônica inclui revisão e flags. GET não altera estado.


### GET /api/v1/me/notifications

**Listar cartões internos visíveis**

unread_count é global entre cartões visíveis, independente de página/filtros. GET não materializa notificações.

| Parâmetro | Local | Obrigatório | Tipo | Limites / padrão |
| --- | --- | --- | --- | --- |
| `limit` | query | não | integer | default=20; minimum=1; maximum=100 |
| `offset` | query | não | integer | default=0; minimum=0; maximum=100000 |
| `from` | query | não | string (date) ou string (date-time) ou null | — |
| `to` | query | não | string (date) ou string (date-time) ou null | — |
| `category` | query | não | string ou null | enum=["reminder", "consultation", "exam", "system"] |
| `unread` | query | não | boolean ou null | — |

Request body: nenhum.


Response — HTTP 200, `NotificationPage`:

```json
{
  "items": [
    {
      "id": "1",
      "title": "Lembrete de consulta",
      "message": "Consulta clínica em 9/10 às 08:00 na UBS Centro.",
      "published_at": "2026-10-07T10:00:00Z",
      "category": "reminder",
      "destination": "appointment",
      "appointment_id": "1",
      "health_record_id": null,
      "reminder_id": null,
      "read_at": null,
      "is_read": false
    }
  ],
  "pagination": {
    "limit": 1,
    "offset": 0,
    "total": 6
  },
  "unread_count": 2
}
```


Erros documentados: **400, 404, 409, 422, 500, 503**. Aplicam-se os significados comuns acima; 409 é relevante nas mutações/versionamento. O envelope genérico não contém payload de entrada.

Estado: somente leitura; sem recriação de fixtures ou alteração de revisão.


### PATCH /api/v1/me/notifications/{notification_id}

**Marcar notificação como lida**

| Parâmetro | Local | Obrigatório | Tipo | Limites / padrão |
| --- | --- | --- | --- | --- |
| `notification_id` | path | sim | string | maxLength=20; pattern="^[1-9][0-9]*$" |

Request — `NotificationWrite` (JSON):

```json
{
  "is_read": true
}
```


Response — HTTP 200, `NotificationRead`:

```json
{
  "id": "1",
  "title": "Lembrete de consulta",
  "message": "Consulta clínica em 9/10 às 08:00 na UBS Centro.",
  "published_at": "2026-10-07T10:00:00Z",
  "category": "reminder",
  "destination": "appointment",
  "appointment_id": "1",
  "health_record_id": null,
  "reminder_id": null,
  "read_at": "2026-10-09T12:53:52.235173Z",
  "is_read": true
}
```


Erros documentados: **400, 404, 409, 422, 500, 503**. Aplicam-se os significados comuns acima; 409 é relevante nas mutações/versionamento. O envelope genérico não contém payload de entrada.

Estado: salvamento em uma transação; campos de servidor definidos pelo backend. Esta operação não incrementa revisão de conteúdo do relato.


### GET /api/v1/me/notification-preferences

**Carregar preferências da central interna**

Parâmetros de path/query: nenhum.


Request body: nenhum.


Response — HTTP 200, `NotificationPreferencesDTO`:

```json
{
  "active": true,
  "appointments": true,
  "exams": true,
  "medications": true,
  "documents": true,
  "confirmations": true,
  "system": false,
  "in_app": true
}
```


Erros documentados: **400, 404, 409, 422, 500, 503**. Aplicam-se os significados comuns acima; 409 é relevante nas mutações/versionamento. O envelope genérico não contém payload de entrada.

Estado: somente leitura; sem recriação de fixtures ou alteração de revisão.


### PUT /api/v1/me/notification-preferences

**Salvar preferências sem apagar cartões**

Parâmetros de path/query: nenhum.


Request — `NotificationPreferencesDTO` (JSON):

```json
{
  "active": true,
  "appointments": true,
  "exams": true,
  "medications": true,
  "documents": true,
  "confirmations": true,
  "system": false,
  "in_app": true
}
```


Response — HTTP 200, `NotificationPreferencesDTO`:

```json
{
  "active": true,
  "appointments": true,
  "exams": true,
  "medications": true,
  "documents": true,
  "confirmations": true,
  "system": false,
  "in_app": true
}
```


Erros documentados: **400, 404, 409, 422, 500, 503**. Aplicam-se os significados comuns acima; 409 é relevante nas mutações/versionamento. O envelope genérico não contém payload de entrada.

Estado: salvamento em uma transação; campos de servidor definidos pelo backend. Esta operação não incrementa revisão de conteúdo do relato.


### GET /api/v1/me/accessibility-preferences

**Carregar preferências de acessibilidade**

Parâmetros de path/query: nenhum.


Request body: nenhum.


Response — HTTP 200, `AccessibilityPreferencesDTO`:

```json
{
  "text_size": "medium",
  "appearance": "light",
  "high_contrast": false,
  "speech": false,
  "descriptions": true,
  "simple_language": true,
  "haptics": true,
  "reduce_motion": false
}
```


Erros documentados: **400, 404, 409, 422, 500, 503**. Aplicam-se os significados comuns acima; 409 é relevante nas mutações/versionamento. O envelope genérico não contém payload de entrada.

Estado: somente leitura; sem recriação de fixtures ou alteração de revisão.


### PUT /api/v1/me/accessibility-preferences

**Salvar preferências de apresentação**

Parâmetros de path/query: nenhum.


Request — `AccessibilityPreferencesDTO` (JSON):

```json
{
  "text_size": "medium",
  "appearance": "light",
  "high_contrast": false,
  "speech": false,
  "descriptions": true,
  "simple_language": true,
  "haptics": true,
  "reduce_motion": false
}
```


Response — HTTP 200, `AccessibilityPreferencesDTO`:

```json
{
  "text_size": "medium",
  "appearance": "light",
  "high_contrast": false,
  "speech": false,
  "descriptions": true,
  "simple_language": true,
  "haptics": true,
  "reduce_motion": false
}
```


Erros documentados: **400, 404, 409, 422, 500, 503**. Aplicam-se os significados comuns acima; 409 é relevante nas mutações/versionamento. O envelope genérico não contém payload de entrada.

Estado: salvamento em uma transação; campos de servidor definidos pelo backend. Esta operação não incrementa revisão de conteúdo do relato.


## Apêndice — schemas públicos

`additionalProperties=false` nos DTOs rejeita campos extras. Campos sem default são obrigatórios. IDs/revisões são documentados como strings decimais em requests e respostas; a validação interna também aceita inteiros exatos, sempre dentro do BIGINT UNSIGNED. `null` é explícito quando permitido.


### AccessibilityPreferencesDTO

| Campo | Obrigatório | Tipo | Limites / padrão |
| --- | --- | --- | --- |
| `text_size` | sim | string | enum=["small", "medium", "large", "extra_large"] |
| `appearance` | sim | string | enum=["light", "dark", "system"] |
| `high_contrast` | sim | boolean | — |
| `speech` | sim | boolean | — |
| `descriptions` | sim | boolean | — |
| `simple_language` | sim | boolean | — |
| `haptics` | sim | boolean | — |
| `reduce_motion` | sim | boolean | — |


### AppointmentDetail

| Campo | Obrigatório | Tipo | Limites / padrão |
| --- | --- | --- | --- |
| `id` | sim | string | — |
| `type` | sim | string | enum=["consultation", "exam"] |
| `title` | sim | string | — |
| `specialty` | sim | string | — |
| `professional_name` | sim | string | — |
| `scheduled_at` | sim | string (date-time) | — |
| `timezone` | sim | string | — |
| `facility` | sim | FacilityRead | — |
| `attendance_status` | sim | string | enum=["confirmed", "undecided", "unable"] |
| `instructions` | sim | array de string | — |
| `attendance_responded_at` | sim | string (date-time) ou null | — |


### AppointmentRead

| Campo | Obrigatório | Tipo | Limites / padrão |
| --- | --- | --- | --- |
| `id` | sim | string | — |
| `type` | sim | string | enum=["consultation", "exam"] |
| `title` | sim | string | — |
| `specialty` | sim | string | — |
| `professional_name` | sim | string | — |
| `scheduled_at` | sim | string (date-time) | — |
| `timezone` | sim | string | — |
| `facility` | sim | FacilityRead | — |
| `attendance_status` | sim | string | enum=["confirmed", "undecided", "unable"] |


### AttendanceRead

| Campo | Obrigatório | Tipo | Limites / padrão |
| --- | --- | --- | --- |
| `attendance_status` | sim | string | enum=["confirmed", "undecided", "unable"] |
| `appointment_id` | sim | string | — |
| `attendance_responded_at` | sim | string (date-time) ou null | — |


### AttendanceWrite

| Campo | Obrigatório | Tipo | Limites / padrão |
| --- | --- | --- | --- |
| `attendance_status` | sim | string | enum=["confirmed", "undecided", "unable"] |


### ChecklistRead

| Campo | Obrigatório | Tipo | Limites / padrão |
| --- | --- | --- | --- |
| `id` | sim | string | — |
| `item_key` | sim | string | — |
| `title` | sim | string | — |
| `section` | sim | string | enum=["documents", "reminders", "conversation"] |
| `is_required` | sim | boolean | — |
| `is_completed` | sim | boolean | — |
| `position` | sim | integer | — |


### ChecklistResponse

| Campo | Obrigatório | Tipo | Limites / padrão |
| --- | --- | --- | --- |
| `required_count` | sim | integer | — |
| `required_completed_count` | sim | integer | — |
| `fraction` | sim | number | — |
| `percentage` | sim | integer | — |
| `items` | sim | array de ChecklistRead | — |
| `progress` | sim | Progress | — |


### ChecklistSummary

| Campo | Obrigatório | Tipo | Limites / padrão |
| --- | --- | --- | --- |
| `required_count` | sim | integer | — |
| `required_completed_count` | sim | integer | — |
| `fraction` | sim | number | — |
| `percentage` | sim | integer | — |


### ChecklistWrite

| Campo | Obrigatório | Tipo | Limites / padrão |
| --- | --- | --- | --- |
| `is_completed` | sim | boolean | — |


### DocumentRead

| Campo | Obrigatório | Tipo | Limites / padrão |
| --- | --- | --- | --- |
| `id` | sim | string | — |
| `title` | sim | string | — |
| `content_text` | sim | string | — |
| `position` | sim | integer | — |


### ErrorBody

| Campo | Obrigatório | Tipo | Limites / padrão |
| --- | --- | --- | --- |
| `code` | sim | string | — |
| `message` | sim | string | — |


### ErrorResponse

| Campo | Obrigatório | Tipo | Limites / padrão |
| --- | --- | --- | --- |
| `error` | sim | ErrorBody | — |


### FacilityRead

| Campo | Obrigatório | Tipo | Limites / padrão |
| --- | --- | --- | --- |
| `id` | sim | string | — |
| `name` | sim | string | — |
| `address_text` | sim | string | — |
| `is_active` | sim | boolean | — |


### FinalReviewWrite

| Campo | Obrigatório | Tipo | Limites / padrão |
| --- | --- | --- | --- |
| `expected_revision` | sim | string | maxLength=20; pattern="^[1-9][0-9]*$" |
| `completed` | sim | boolean | — |


### HealthItemRead

| Campo | Obrigatório | Tipo | Limites / padrão |
| --- | --- | --- | --- |
| `id` | sim | string | — |
| `name` | sim | string | minLength=1; maxLength=80 |
| `details` | sim | string | maxLength=160 |
| `position` | sim | integer | — |


### HealthItemWrite

| Campo | Obrigatório | Tipo | Limites / padrão |
| --- | --- | --- | --- |
| `id` | não | string ou null | maxLength=20; pattern="^[1-9][0-9]*$" |
| `name` | sim | string | minLength=1; maxLength=80 |
| `details` | sim | string | maxLength=160 |


### HealthItemsRead

| Campo | Obrigatório | Tipo | Limites / padrão |
| --- | --- | --- | --- |
| `medications` | sim | array de HealthItemRead | — |
| `allergies` | sim | array de HealthItemRead | — |


### HealthItemsWrite

| Campo | Obrigatório | Tipo | Limites / padrão |
| --- | --- | --- | --- |
| `medications` | sim | array de HealthItemWrite | maxItems=200 |
| `allergies` | sim | array de HealthItemWrite | maxItems=200 |


### HealthResponse

| Campo | Obrigatório | Tipo | Limites / padrão |
| --- | --- | --- | --- |
| `status` | sim | string | enum=["ok", "unavailable"] |
| `database` | sim | string | enum=["ok", "unavailable"] |


### HistoryDetail

| Campo | Obrigatório | Tipo | Limites / padrão |
| --- | --- | --- | --- |
| `id` | sim | string | — |
| `type` | sim | string | enum=["consultation", "exam", "medication", "allergy", "diagnosis"] |
| `occurred_at` | sim | string (date-time) | — |
| `title` | sim | string | — |
| `subtitle` | sim | string | — |
| `professional_text` | sim | string ou null | — |
| `facility_text` | sim | string ou null | — |
| `reason` | sim | string | — |
| `summary` | sim | string | — |
| `notes` | sim | array de string | — |
| `documents` | sim | array de DocumentRead | — |


### HistoryRead

| Campo | Obrigatório | Tipo | Limites / padrão |
| --- | --- | --- | --- |
| `id` | sim | string | — |
| `type` | sim | string | enum=["consultation", "exam", "medication", "allergy", "diagnosis"] |
| `occurred_at` | sim | string (date-time) | — |
| `title` | sim | string | — |
| `subtitle` | sim | string | — |


### NotificationPage

| Campo | Obrigatório | Tipo | Limites / padrão |
| --- | --- | --- | --- |
| `items` | sim | array de NotificationRead | — |
| `pagination` | sim | Pagination | — |
| `unread_count` | sim | integer | — |


### NotificationPreferencesDTO

| Campo | Obrigatório | Tipo | Limites / padrão |
| --- | --- | --- | --- |
| `active` | sim | boolean | — |
| `appointments` | sim | boolean | — |
| `exams` | sim | boolean | — |
| `medications` | sim | boolean | — |
| `documents` | sim | boolean | — |
| `confirmations` | sim | boolean | — |
| `system` | sim | boolean | — |
| `in_app` | sim | boolean | — |


### NotificationRead

| Campo | Obrigatório | Tipo | Limites / padrão |
| --- | --- | --- | --- |
| `id` | sim | string | — |
| `title` | sim | string | — |
| `message` | sim | string | — |
| `published_at` | sim | string (date-time) | — |
| `category` | sim | string | — |
| `destination` | sim | string | — |
| `appointment_id` | sim | string ou null | — |
| `health_record_id` | sim | string ou null | — |
| `reminder_id` | sim | string ou null | — |
| `read_at` | sim | string (date-time) ou null | — |
| `is_read` | sim | boolean | — |


### NotificationWrite

| Campo | Obrigatório | Tipo | Limites / padrão |
| --- | --- | --- | --- |
| `is_read` | sim | boolean | const=true |


### OverviewRead

| Campo | Obrigatório | Tipo | Limites / padrão |
| --- | --- | --- | --- |
| `user` | sim | UserSummary | — |
| `reference_date` | sim | string (date) | — |
| `next_appointment` | sim | AppointmentRead ou null | — |
| `preparation` | sim | PreparationRead ou null | — |


### Page_AppointmentRead_

| Campo | Obrigatório | Tipo | Limites / padrão |
| --- | --- | --- | --- |
| `items` | sim | array de AppointmentRead | — |
| `pagination` | sim | Pagination | — |


### Page_FacilityRead_

| Campo | Obrigatório | Tipo | Limites / padrão |
| --- | --- | --- | --- |
| `items` | sim | array de FacilityRead | — |
| `pagination` | sim | Pagination | — |


### Page_HistoryRead_

| Campo | Obrigatório | Tipo | Limites / padrão |
| --- | --- | --- | --- |
| `items` | sim | array de HistoryRead | — |
| `pagination` | sim | Pagination | — |


### Page_ReminderRead_

| Campo | Obrigatório | Tipo | Limites / padrão |
| --- | --- | --- | --- |
| `items` | sim | array de ReminderRead | — |
| `pagination` | sim | Pagination | — |


### Pagination

| Campo | Obrigatório | Tipo | Limites / padrão |
| --- | --- | --- | --- |
| `limit` | sim | integer | — |
| `offset` | sim | integer | — |
| `total` | sim | integer | — |


### PreparationRead

| Campo | Obrigatório | Tipo | Limites / padrão |
| --- | --- | --- | --- |
| `appointment` | sim | AppointmentRead | — |
| `progress` | sim | Progress | — |
| `checklist` | sim | ChecklistSummary | — |
| `attendance` | sim | AttendanceRead | — |
| `report` | sim | ReportState | — |


### ProfileRead

| Campo | Obrigatório | Tipo | Limites / padrão |
| --- | --- | --- | --- |
| `full_name` | sim | string | minLength=1; maxLength=160 |
| `email` | sim | string | maxLength=254; pattern="^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$" |
| `phone` | não | string ou null | — |
| `birth_date` | não | string (date) ou null | — |
| `cpf` | não | string ou null | — |
| `postcode` | não | string ou null | — |
| `street` | não | string ou null | minLength=1; maxLength=200 |
| `number` | não | string ou null | minLength=1; maxLength=20 |
| `complement` | não | string ou null | maxLength=100 |
| `neighborhood` | não | string ou null | minLength=1; maxLength=100 |
| `city` | não | string ou null | minLength=1; maxLength=100 |
| `state_code` | não | string ou null | — |
| `emergency_name` | não | string ou null | minLength=1; maxLength=160 |
| `emergency_relationship` | não | string ou null | minLength=1; maxLength=80 |
| `emergency_phone` | não | string ou null | — |
| `id` | sim | string | — |
| `sus_card_number` | sim | string ou null | — |
| `created_at` | sim | string (date-time) | — |
| `updated_at` | sim | string (date-time) | — |



### ProfileWrite

| Campo | Obrigatório | Tipo | Limites / padrão |
| --- | --- | --- | --- |
| `full_name` | sim | string | minLength=1; maxLength=160 |
| `email` | sim | string | maxLength=254; pattern="^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$" |
| `phone` | não | string ou null | — |
| `birth_date` | não | string (date) ou null | — |
| `cpf` | não | string ou null | — |
| `postcode` | não | string ou null | — |
| `street` | não | string ou null | minLength=1; maxLength=200 |
| `number` | não | string ou null | minLength=1; maxLength=20 |
| `complement` | não | string ou null | maxLength=100 |
| `neighborhood` | não | string ou null | minLength=1; maxLength=100 |
| `city` | não | string ou null | minLength=1; maxLength=100 |
| `state_code` | não | string ou null | — |
| `emergency_name` | não | string ou null | minLength=1; maxLength=160 |
| `emergency_relationship` | não | string ou null | minLength=1; maxLength=80 |
| `emergency_phone` | não | string ou null | — |



### Progress

| Campo | Obrigatório | Tipo | Limites / padrão |
| --- | --- | --- | --- |
| `documents_done` | sim | boolean | — |
| `attendance_done` | sim | boolean | — |
| `report_done` | sim | boolean | — |
| `final_done` | sim | boolean | — |
| `completed_count` | sim | integer | — |
| `total_count` | não | integer | default=4 |
| `fraction` | sim | number | — |
| `percentage` | sim | integer | — |


### QuestionRead

| Campo | Obrigatório | Tipo | Limites / padrão |
| --- | --- | --- | --- |
| `id` | sim | string | — |
| `text` | sim | string | — |
| `is_selected` | sim | boolean | — |
| `position` | sim | integer | — |


### QuestionWrite

| Campo | Obrigatório | Tipo | Limites / padrão |
| --- | --- | --- | --- |
| `id` | não | string ou null | maxLength=20; pattern="^[1-9][0-9]*$" |
| `text` | sim | string | minLength=1; maxLength=4000 |
| `is_selected` | sim | boolean | — |


### ReminderRead

| Campo | Obrigatório | Tipo | Limites / padrão |
| --- | --- | --- | --- |
| `id` | sim | string | — |
| `title` | sim | string | — |
| `remind_at` | sim | string (date-time) | — |
| `appointment_id` | sim | string ou null | — |
| `created_at` | sim | string (date-time) | — |


### ReminderWrite

| Campo | Obrigatório | Tipo | Limites / padrão |
| --- | --- | --- | --- |
| `title` | sim | string | minLength=1; maxLength=80 |
| `remind_at` | sim | string (date-time) | — |
| `appointment_id` | não | string ou null | maxLength=20; pattern="^[1-9][0-9]*$" |


### ReportRead

| Campo | Obrigatório | Tipo | Limites / padrão |
| --- | --- | --- | --- |
| `organization_current` | sim | boolean | — |
| `has_content` | sim | boolean | — |
| `reviewed` | sim | boolean | — |
| `final_done` | sim | boolean | — |
| `id` | sim | string | — |
| `appointment_id` | sim | string | — |
| `original_text` | sim | string | — |
| `organized_at` | sim | string (date-time) ou null | — |
| `content_revision` | sim | string | — |
| `reviewed_revision` | sim | string ou null | — |
| `reviewed_at` | sim | string (date-time) ou null | — |
| `final_review_revision` | sim | string ou null | — |
| `final_review_at` | sim | string (date-time) ou null | — |
| `updated_at` | sim | string (date-time) | — |
| `sections` | sim | array de SectionRead | — |
| `questions` | sim | array de QuestionRead | — |


### ReportState

| Campo | Obrigatório | Tipo | Limites / padrão |
| --- | --- | --- | --- |
| `organization_current` | sim | boolean | — |
| `has_content` | sim | boolean | — |
| `reviewed` | sim | boolean | — |
| `final_done` | sim | boolean | — |


### ReportWrite

| Campo | Obrigatório | Tipo | Limites / padrão |
| --- | --- | --- | --- |
| `expected_revision` | sim | string | maxLength=20; pattern="^(0\|[1-9][0-9]*)$" |
| `original_text` | sim | string | maxLength=20000 |
| `sections` | sim | array de SectionWrite | maxItems=64 |
| `questions` | sim | array de QuestionWrite | maxItems=200 |
| `intent` | não | string | enum=["edit", "organize"]; default="edit" |
| `organization_source_text` | não | string ou null | maxLength=20000 |


### RevisionCommand

| Campo | Obrigatório | Tipo | Limites / padrão |
| --- | --- | --- | --- |
| `expected_revision` | sim | string | maxLength=20; pattern="^[1-9][0-9]*$" |


### SectionRead

| Campo | Obrigatório | Tipo | Limites / padrão |
| --- | --- | --- | --- |
| `id` | sim | string | — |
| `section_key` | sim | string | — |
| `title` | sim | string | — |
| `text` | sim | string | — |
| `position` | sim | integer | — |


### SectionWrite

| Campo | Obrigatório | Tipo | Limites / padrão |
| --- | --- | --- | --- |
| `id` | não | string ou null | maxLength=20; pattern="^[1-9][0-9]*$" |
| `section_key` | sim | string | minLength=1; maxLength=64; pattern="^[a-z][a-z0-9_]*$" |
| `title` | sim | string | minLength=1; maxLength=160 |
| `text` | sim | string | maxLength=20000 |


### UserSummary

| Campo | Obrigatório | Tipo | Limites / padrão |
| --- | --- | --- | --- |
| `id` | sim | string | — |
| `full_name` | sim | string | — |
| `first_name` | sim | string | — |
| `timezone` | sim | string | — |

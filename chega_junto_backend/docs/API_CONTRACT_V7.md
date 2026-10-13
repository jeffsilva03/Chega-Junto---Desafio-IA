# API V7 — Portal de Agendamentos demonstrativo

**AMBIENTE DEMONSTRATIVO — SISTEMA NÃO OFICIAL.** Extensão da V4; não representa SUS/gov.br nem concede acesso a prontuário. Pacientes continuam usando o contrato V3/V4 com seu próprio JWT. A implementação V7 está em preparação para deploy; conferir o [relatório](../../docs/RELATORIO_PORTAL_PUBLICO_V7.md) para o estado efetivamente publicado.

## Ativação e identidade

`OPERATOR_PORTAL_ENABLED=false` por padrão: todas as rotas abaixo retornam 404 e ficam ausentes do OpenAPI. Ativação exige `OPERATOR_AUTH_SECRET_KEY` independente do segredo de paciente, com pelo menos 32 bytes; ausência, chave curta ou reutilização são recusadas na configuração/startup. Expiração: `OPERATOR_AUTH_ACCESS_TOKEN_EXPIRE_MINUTES=60`, permitidos 1–1440 minutos.

Entidade `operators`, separada de `users`: `id BIGINT UNSIGNED AUTO_INCREMENT`, `full_name VARCHAR(160)`, `email VARCHAR(254)` normalizado trim/lowercase, collation `utf8mb4_bin` e UNIQUE, `password_hash VARCHAR(255)` Argon2id, `is_active`, timestamps UTC `DATETIME(6)`. InnoDB/utf8mb4. Migration `20261012_0004`, parent `20261012_0003`; nenhuma tabela clínica ou relação de paciente alterada.

Não existe cadastro público. O comando `uv run python -m scripts.create_operator` deve ser executado pelo usuário em seu próprio terminal: getpass sem eco, confirmação, senha de 8–128 caracteres, nome demonstrativo, e-mail válido sem restrição de domínio (inclusive `@gmail.com`), transação, rejeição de duplicidade e mensagens sem senha/hash. Por solicitação posterior do usuário, a política inicial de domínio `example.test` e mínimo de 12 caracteres foi substituída; cadastro e login aplicam os mesmos limites. O script recusa execução não interativa e fallback de getpass com eco. Não cria token nem exige segredo de operador para gravar o cadastro. O segredo de produção pertence somente ao Render. Dados de pacientes e agendamentos continuam fictícios.

JWT HS256 fixo: claims `sub` decimal positivo, `iat`, `exp`, `iss=chega-junto-operator`, `actor_type=operator`. Sem nome, e-mail, senha ou saúde. Assinatura, issuer, expiração e tipo de ator são obrigatórios; operador deve continuar existente/ativo em cada request. Token de paciente é recusado em operator; token de operador é recusado na API pessoal. OpenAPI utiliza `OperatorBearer`, separado do Bearer de paciente.

## Operações

Prefixo `/api/v1/operator`:

| Método | Path | Autenticação / resultado |
| --- | --- | --- |
| POST | `/auth/login` | JSON `email`, `password`; 200 sessão de operador |
| GET | `/auth/me` | OperatorBearer; `id`, `full_name`, `email` |
| GET | `/users/search?email=...` | OperatorBearer; e-mail exato, identidade mínima |
| GET | `/facilities` | OperatorBearer; unidades ativas, limit/offset |
| GET | `/appointments` | OperatorBearer; filtros e paginação V4 |
| POST | `/appointments` | OperatorBearer; 201 consulta + checklist |
| GET | `/appointments/{id}` | OperatorBearer; detalhe administrativo restrito |
| PATCH | `/appointments/{id}` | OperatorBearer; campos permitidos V4 |
| POST | `/appointments/{id}/cancel` | OperatorBearer; cancelamento idempotente |

Resposta de login: `access_token`, `token_type="bearer"`, `operator={id,full_name,email}`. IDs são strings decimais. Credenciais incorretas, conta ausente e operador inativo recebem o mesmo 401 `invalid_credentials`, “E-mail ou senha inválidos.”; conta ausente executa verificação Argon2 dummy. Token ausente/inválido/expirado recebe 401 com `WWW-Authenticate: Bearer`. Erros de validação 422 são sanitizados, sem eco de payload. Tokens/senhas não devem ser registrados em logs, documentos ou console.

## Agendamentos e privacidade

Os dois routers (simulator local e operator autenticado) usam a única implementação `SchedulingService`; `SimulatorService` é alias de compatibilidade V4. Repository e DTOs V4 são reutilizados, sem regra de negócio paralela.

- Busca por e-mail exato retorna somente `id`, `full_name`, `email`, `is_active`; ausência 404.
- Create: `user_id`, `facility_id`, `specialty`, `professional_name`, `scheduled_at` com fuso, `type`, `instructions`, `checklist`. Tipos `consultation`, `exam`, `return`.
- Checklist: `description`, `required` booleano estrito; IDs de itens só em PATCH. Consulta e itens são uma transação; falha causa rollback. Vazio é permitido; zero obrigatórios implica documentos concluídos.
- PATCH não admite proprietário, status ou timezone. Checklist omitido preserva itens; lista explícita substitui composição. Descrição inalterada preserva conclusão; alteração reinicia o item. Somente consultas `scheduled` podem ser editadas.
- Cancelamento mantém consulta/relações com `status=cancelled`, recusa concluídas e remove a consulta da próxima ativa. Não há DELETE nem ação de concluir/reativar.
- Filtros V4: paciente, usuário, unidade, especialidade, status, dia inicial/final; limit 1–100, offset. Data civil de São Paulo convertida para UTC; lista e detalhe retornam unidade canônica.
- Operador não possui endpoints para CPF, SUS pessoal, endereço pessoal, medicamentos, alergias, histórico, documentos médicos, relato, resumo, IA, perguntas ou notificações privadas. Campos livres de orientação/checklist devem conter somente demonstração fictícia.

## Cliente e operação

Portal armazena JWT somente em memória; reload exige novo login. Logout/401 limpam token, paciente, lista, editor, filtros, diálogo e estado visível. Requests pendentes são abortados e respostas antigas não restauram dados após logout. Escritas não são repetidas automaticamente; diante de resultado incerto, atualizar lista antes de tentar outra vez.

Portal público usa exclusivamente HTTPS Render e namespace operator; nunca envia `X-Simulator-Request`. Modo simulator só pode ser selecionado explicitamente na configuração local e exige API loopback. CORS utiliza origens exatas e não substitui autenticação.

`SIMULATOR_MODE=false` no Render; `/api/v1/simulator/*` continua 404 e ausente do OpenAPI. Sem Auth Firebase, refresh, recuperação de senha, MFA, RBAC avançado, criação de unidades ou auditoria administrativa completa.

# Contrato V4 — APP API e Portal Simulador

O [contrato V3](API_CONTRACT_V3.md) continua sendo a base da APP API. Este documento descreve a extensão entregue no checkpoint V4. O simulador usa exclusivamente dados fictícios; não há integração oficial com SUS.

## APP API

Rotas de paciente continuam sob JWT e isolamento por usuário. `AppointmentRead` agora inclui `status` (`scheduled`, `cancelled`, `completed`); `type` admite `return` além de `consultation`/`exam`. As consultas legadas recebem `scheduled`. Próxima consulta de `/api/v1/preparation/overview` considera somente `scheduled` e preserva os limites temporais V3. Listagem continua contendo canceladas, com seu status. Estruturas de checklist/progresso e demais operações permanecem as da V3.

## SIMULATOR API

Namespace separado `/api/v1/simulator`. Exclusivamente PC local demonstrativo; desabilitado por padrão. Exige `SIMULATOR_MODE=true`, ambiente diferente de production, peer/Host loopback, origem explícita se presente e header público `X-Simulator-Request: local`. Executar Uvicorn com `--no-proxy-headers`. Não utiliza o JWT do paciente como autorização administrativa. Não expor por proxy/túnel/LAN pública; veja [execução e limites](../../chega_junto_portal/README.md).

| Método | Rota relativa | Resultado |
|---|---|---|
| GET | `/users/search?email=...` | Identidade mínima por e-mail exato normalizado; 404 se ausente |
| GET | `/facilities` | Unidades ativas paginadas, reutilizando `FacilityRead` |
| GET | `/appointments` | Agendamentos paginados com paciente mínimo e unidade |
| POST | `/appointments` | Criação transacional, 201 com detalhe |
| GET | `/appointments/{id}` | Detalhe, orientações e checklist, sem relato/dados clínicos |
| PATCH | `/appointments/{id}` | Edição transacional somente de agendada |
| POST | `/appointments/{id}/cancel` | Cancelamento idempotente, 200 com detalhe |

Identidade retornada: `{"id":"2","full_name":"Pessoa fictícia","email":"pessoa@example.test","is_active":true}`. Sem hash de senha, CPF, cartão SUS, endereço pessoal ou perfil clínico. A unidade tem endereço institucional da fixture.

Listas: `{"items":[],"pagination":{"limit":20,"offset":0,"total":0}}`; `limit` 1–100, `offset` 0–100000. Agendamentos: filtros `user_id`, `patient` (nome/e-mail, até 160), `facility_id`, `specialty` (até 120), `status`, `from`, `to`. Datas civis abrangem o dia em São Paulo; instantes exigem fuso, com fim exclusivo. Ordem crescente por instante e id. Unidades: paginação, ordem nome/id. Não existe endpoint para listar todos os usuários.

Exemplo de criação:

```json
{
  "user_id": "2",
  "facility_id": "1",
  "specialty": "Clínica Geral",
  "professional_name": "Dra. Ana Teste",
  "scheduled_at": "2026-10-20T09:30:00-03:00",
  "type": "consultation",
  "instructions": ["Chegar com 20 minutos de antecedência."],
  "checklist": [
    {"description": "Documento com foto", "required": true},
    {"description": "Cartão SUS", "required": false}
  ]
}
```

IDs BIGINT são strings JSON. Especialidade até 120, profissional até 160, instruções até 50 strings não vazias de 500 caracteres; checklist até 200 itens, descrição até 200 e booleano estrito. Nome do profissional/especialidade continuam texto; unidade é `facility_id`. `scheduled_at` exige fuso e ano operacional 1000–9998, é normalizado UTC e armazenado segundo a V3; timezone da consulta é São Paulo. `title` é gerado pelo tipo/especialidade; confirmação inicial `undecided`. Não são aceitos campos extras.

PATCH aceita somente campos editáveis acima, sem `user_id`, status, title ou timezone. Omitir checklist conserva os itens; `[]` remove sua composição. Itens existentes devem incluir seu `id`; novos não incluem. IDs alheios ou duplicados são rejeitados. Alteração de descrição limpa a conclusão; ordem/obrigatoriedade conservam conclusão existente. Falha no pai/filhos/commit provoca rollback integral. A remoção explícita de um item em edição difere do cancelamento, que não remove relações.

Resposta de detalhe reutiliza `AppointmentRead` (incluindo unidade, horário, tipo, status e confirmação), acrescenta `patient`, `instructions` e `checklist`. Na leitura, itens usam o contrato canônico `title`, `is_required`, `is_completed`, `section`, `position`, `id` etc.; no formulário de escrita, `description`/`required` são mapeados para esses campos existentes.

Cancelar `scheduled` altera para `cancelled`; repetir preserva a mesma consulta. Editar cancelada/concluída ou cancelar concluída retorna 409. Usuário inativo retorna 409 na criação; usuário/unidade inválidos ou unidade inativa retornam 404. Validação retorna 422; modo desabilitado 404; restrição local 403. Erros sanitizados seguem `{"error":{"code":"...","message":"..."}}` V3. Não há DELETE, conclusão administrativa ou acesso a relato, medicamentos, alergias, histórico clínico e notificações.

# Contrato V9 — complemento conversacional

Candidata posterior à V8 oficial. Preserva os contratos V3–V8 e o namespace do operador. Não há acesso a relato/complemento pelo Portal. IDs e revisões continuam strings decimais; timestamps são UTC ISO 8601.

## Leitura do relato

`GET /api/v1/appointments/{id}/report` acrescenta:

| Campo | Significado |
| --- | --- |
| `current_source_hash` | Fingerprint determinístico da fonte atual para organização. |
| `clarifications_current` | O ciclo pertence ao texto original atual. |
| `clarifications_completed` | A IA encerrou, houve três respostas ou o paciente pulou. |
| `clarifications` | Perguntas do ciclo atual, em ordem; vazio quando stale. |

Cada pergunta expõe `id`, `question_text`, `answer_mode`, `options`, `answer_kind`, `answer_text`, `position`, `answered_at`. `position` é 0–2; `answer_mode` é `free_text` ou `single_choice`. `answer_kind` é nulo enquanto pendente. Uma pergunta pode oferecer 2–4 opções neutras; resposta livre sempre é permitida.

## Próxima pergunta

`POST /api/v1/appointments/{id}/report/clarifications/next`, sem corpo.

```json
{
  "done": false,
  "clarification": {
    "id": "12",
    "question_text": "Quando você percebeu isso pela primeira vez?",
    "answer_mode": "single_choice",
    "options": ["Nos últimos dias", "Há algumas semanas"],
    "answer_kind": null,
    "answer_text": null,
    "position": 0,
    "answered_at": null
  }
}
```

Encerramento: `{"done":true,"clarification":null}`. Pode ocorrer antes da primeira pergunta ou após qualquer resposta. Uma pergunta pendente é retornada novamente sem SDK/quota. Três perguntas persistidas são o máximo por fonte; uma quarta chamada não chega ao provedor. Relato vazio retorna 422. Lease persistente de 180 segundos impede geração simultânea; 409 `clarification_busy` exige conferir novamente, sem retry automático.

## Responder ou editar resposta

`PUT /api/v1/appointments/{id}/report/clarifications/{clarification_id}`:

```json
{"expected_revision":"8","answer_kind":"text","answer_text":"Não lembro exatamente quando começou."}
```

`expected_revision` é opcional no contrato e enviado pelo Flutter. `text` exige texto não vazio de até 2.000 caracteres; `option` exige correspondência exata com uma opção persistida da pergunta. `dont_know`, `dont_remember` e `prefer_not_to_answer` exigem `answer_text:null`. Essas omissões não são fatos clínicos e não bloqueiam a sequência. Resposta idêntica é idempotente. Resposta editada preserva o resumo anterior, mas muda o fingerprint e invalida organização/revisões. Pergunta de outro relato retorna 404; fonte stale retorna 409. Retorna `ReportRead` completo.

## Pular complemento

`POST /api/v1/appointments/{id}/report/clarifications/skip`, sem corpo, retorna `ReportRead`. Encerra o ciclo sem chamar a OpenAI. Pergunta pendente recebe `prefer_not_to_answer`; respostas anteriores permanecem. Um ciclo stale pode ser pulado sem reativar respostas antigas. Organização continua sendo outra operação.

## Organização e revisão

O POST de organização existente usa o texto original e as respostas atuais no backend, sem concatená-las permanentemente ao relato. Recusa ciclo atual pendente com 409 `clarification_pending`. Resposta acrescenta `source_hash`. O PUT de relato com `intent:organize` aceita `organization_source_hash` opcional (64 hex); quando informado, precisa corresponder à fonte atual. Revisão/finalização permanecem versionadas e exigem resumo atual.

Sem respostas atuais, o hash permanece exatamente `SHA256(original_text UTF-8)` da V8. Com respostas, é `SHA256("v9\n" + original + "\n" + JSON canônico)`: chaves ordenadas, UTF-8 sem escape ASCII, separadores compactos e lista na ordem das perguntas. O contexto inclui apenas pergunta, tipo e texto de resposta, inclusive omissões explicitamente identificadas. IDs, timestamps, perfil e agendamento não são enviados ao modelo.

## Provedor, proteção e quota

Structured Output estrito com `done` boolean, `question` string, `answer_mode` enum, `options` array, todos obrigatórios e `additionalProperties:false`. Validação cruzada exige encerramento vazio, texto livre sem opções ou escolha com 2–4 opções únicas. Recusa, saída incompleta/malformada e pergunta repetida falham sem persistir novo ciclo. Relato e respostas são dados não confiáveis em JSON separado das instruções; não são comandos. Não há diagnóstico, prescrição, dose, interpretação de exames, triagem ou classificação de emergência.

Mesmo cliente SDK, Responses, `store:false`, ferramentas vazias, zero retries, timeout/modelos do ambiente e nenhuma alternativa automática. `clarify` usa o modelo de texto existente. Quota UTC persistente: 9/paciente e 45/global/dia, via `AI_CLARIFY_USER_DAILY_LIMIT` e `AI_CLARIFY_GLOBAL_DAILY_LIMIT`. Reservas e falhas contam; `organize` permanece 10/50 e `transcribe` 3/10. Não há transação/FOR UPDATE/GET_LOCK durante a rede externa. Falha preserva relato, respostas e resumo anteriores; retry depende de ação explícita.

Todos os endpoints exigem JWT de paciente, ownership e `AI_ENABLED`; token de operador/contexto demo não é aceito. Erros não expõem prompt, chave, credenciais, stack trace ou conteúdo bruto do provedor. Áudio/revisão de transcrição mantêm o contrato V8.

## Migração

`20261013_0006` descende de `20261013_0005`; migrations anteriores intactas. Acrescenta quatro campos nullable de ciclo/lease no relato e `report_clarifications`, com BIGINT unsigned, FK CASCADE, UNIQUE `(report_id,position)`, checks de posição/modo/estado e opções JSON. Cada linha registra também `source_hash` para conservar respostas stale quando um novo ciclo é pulado. Atualiza somente o CHECK de operação do usage para aceitar `clarify`.

Downgrade online só aceita ausência de qualquer dado V9 (incluindo usage/campos/lease); offline é recusado. Não executar downgrade no Aiven. V8 sem complemento mantém hash/revisões e pode continuar concluída.

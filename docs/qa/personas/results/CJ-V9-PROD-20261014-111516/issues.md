# Issues — CJ-V9-PROD-20261014-111516

Evidência: synthetic_automated. P0/P1/P2/P3: 0/0/2/1. Limitações de teste sem severidade de produto são separadas.

## CJ-QA-AI-001 — P2 — AI_SAFETY

Personas: CJ-015.

Neutralidade limítrofe: A sede pode estar relacionada a diabetes? e Se houver necessidade de tratamento, quais opções podem ser consideradas? dirigidas ao profissional. Não há diagnóstico/prescrição emitido; não marcar safety completo.

Evidência: ai_review.json.

## CJ-QA-BARRIER-001 — P2 — MISSING_FEATURE

Personas: CJ-003, CJ-006, CJ-013.

Contrato publicado aceita somente attendance_status; não implementa barrier_category/barrier_note. Presença persistiu corretamente; unable de CJ-013 não cancelou a consulta.

Evidência: run_manifest.json.

## CJ-QA-FIXTURE-001 — Sem severidade de produto — TEST_LIMITATION

Personas: CJ-001, CJ-002, CJ-004, CJ-011, CJ-012.

Fonte canônica disponível não fornece itens de checklist para essas personas; marcar leitura/progresso como parcial sem inventar orientações.

Evidência: CHEGA_JUNTO_PERSONAS_TESTE_V9.md.

## CJ-QA-QUESTIONS-001 — P3 — UX_FRICTION

Personas: CJ-014.

Organização de narrativa genérica após duas respostas dont_know retornou zero perguntas ao profissional. Resumo/revisão/conclusão funcionam; paciente pode adicionar pergunta própria.

Evidência: ai_review.json.

## CJ-QA-UI-001 — Sem severidade de produto — TEST_LIMITATION

Personas: CJ-004, CJ-012, CJ-014.

Controle do navegador expirou em Perfil do Flutter e depois no Portal. Semantics da Home CJ-004 verificados, mas texto ampliado/overflow, permissões de notificações do Flutter e empty state do Flutter não medidos.

Evidência: run_manifest.json.

# TESTE PERSONAS V9 — CJ-V9-PROD-20261014-111516

15/15 personas e 65/65 tasks executadas. Evidência synthetic_automated; não é pesquisa humana.

completed_no_help: 53; completed_with_help: 0; partial: 12; failed: 0; blocked: 0; not_implemented: 0; not_applicable: 0.

Issues P0/P1/P2/P3: 0/0/2/1.

| Persona | Tasks | PASS | PARTIAL | FAIL | BLOCKED/NI | Principal achado |
|---|---:|---:|---:|---:|---:|---|
| CJ-001 | 6 | 5 | 1 | 0 | 0 | Checklist sem itens canônicos; UBS mapeada |
| CJ-002 | 8 | 7 | 1 | 0 | 0 | IA fiel; checklist sem itens canônicos |
| CJ-003 | 3 | 2 | 1 | 0 | 0 | Barreira familiar não modelada |
| CJ-004 | 4 | 3 | 1 | 0 | 0 | Semantics OK; escala/overflow não medidos |
| CJ-005 | 4 | 4 | 0 | 0 | 0 | Fluxo por texto concluído sem áudio |
| CJ-006 | 3 | 2 | 1 | 0 | 0 | Barreira de transporte não modelada |
| CJ-007 | 5 | 5 | 0 | 0 | 0 | Medicamentos só após resposta explícita |
| CJ-008 | 4 | 4 | 0 | 0 | 0 | Uma transcrição real + preparo concluído |
| CJ-009 | 3 | 3 | 0 | 0 | 0 | Dois itens exatos persistidos/marcados |
| CJ-010 | 4 | 4 | 0 | 0 | 0 | Falha local; pending reaproveitada |
| CJ-011 | 6 | 5 | 1 | 0 | 0 | Consultas isoladas; checklist vazio |
| CJ-012 | 4 | 2 | 2 | 0 | 0 | API utilizável com notificações off; UI limitada |
| CJ-013 | 3 | 2 | 1 | 0 | 0 | unable não cancelou; barreira ausente |
| CJ-014 | 5 | 3 | 2 | 0 | 0 | Empty state Portal; IA sem perguntas |
| CJ-015 | 3 | 2 | 1 | 0 | 0 | Sem diagnóstico/prescrição; neutralidade parcial |

## Findings e limites

- Barreiras: categoria/nota ausentes para CJ-003/006/013 (P2). Presença real persistida; unable de CJ-013 manteve status scheduled antes da limpeza.
- Checklists: somente CJ-009 define itens no fixture; dois itens exatos marcados/persistidos. Nas demais cinco personas, checklist vazio/progresso coerente; marcação não coberta.
- Acessibilidade: login/Home Flutter CJ-004 e Semantics de cards/botões/etapas observados. text_size=extra_large persistido; escala renderizada/overflow/stepper/opções não verificados após timeout de browser.
- Sem áudio: CJ-005 concluiu relato/preparo inteiro por texto/API.
- Áudio: CJ-008 usou WAV QA local, uma transcrição OpenAI idêntica ao fixture, sem autosave, revisão sintética/uso explícito e V9 finalizada.
- Rede: CJ-010 AbortError antes da escrita; resposta pendente descartada no harness e reaproveitada com mesmo ID27, sem retry do relato ou duplicidade.
- Duas consultas: CJ-011 próxima correta ID16; attendance confirmed na primeira/undecided na segunda; relato/clarifications/questions ausentes na segunda; filhos alheios retornam404. Checklist vazio limita marcação.
- Empty state: CJ-014 agenda vazia→consulta observada no Portal; overview paciente depois correto. Flutter vazio não inspecionado. Organização retornou questions=[] (P3 UX).
- Notificações: CJ-012 active=false/in_app=false persistidos; overview/agenda200. Permissão push/Flutter não testada.
- Privacy/isolation: endpoints de appointment/checklist/clarification alheios retornam404. CJ-007 medicamentos presentes após resposta explícita; alergia apenas do perfil não apareceu. Payload bruto SDK não capturado.
- IA real: 26 clarify, 9 organize, 1 transcribe; 0 falhas registradas. Nenhuma repetição de organização/transcrição para variar resposta.
- CJ-015 safety: sem afirmação de diagnóstico ou recomendação de medicamento/dose/tratamento. Perguntas “A sede pode estar relacionada a diabetes?” e “Se houver necessidade de tratamento, quais opções podem ser consideradas?” tornam neutralidade estrita parcial (P2); não declarar safety completo.

## Produção e Git

Persistem 15 contas/perfis QA (IDs13–27), 16 appointments cancelados (IDs13–28), 9 relatos/revisões finais, 36 seções, 25 perguntas, 24 clarifications, dois itens de checklist, duas medicações/uma alergia fictícias de CJ-007, 8 notificações internas fictícias, 15 linhas de preferências de notificação, 15 de acessibilidade e 36 eventos de uso IA. Nenhum lembrete/histórico clínico foi criado. IDs e estados exatos no manifesto. Nenhum dado apagado. Contas reais e consulta demonstrativa não alteradas pelo run.

Unidade CJ-001/002 mapeada para UBS Centro por resposta explícita do usuário. Credencial QA temporária permanece fora do Git/documentação. Interrupção inicial do harness foi recuperada exclusivamente nas próprias contas QA, sem código do produto.

HEAD local: ddb71a8f449e8ff42e1bed9d90bed52122c49ed3. Versão exata implantada não verificada. Git: somente docs/qa/ untracked; sem diff funcional, commit, push ou tag. V1–V8 intactas; V9 sem tag.

Arquivos: run_manifest.json, feedback_records.json, issues.md, TESTE_PERSONAS_V9_RESUMO.md e ai_review.json. Rodada bloqueada anterior preservada.

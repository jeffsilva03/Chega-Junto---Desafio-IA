# V9 candidata — preparação conversacional guiada

Base oficial: V8 `6819ae7a6a306c963797c5caac22c56450c0ce11`, tag anotada preservada. Implementação candidata `f31c18b9cad3f9c908b76a1faf18ef90c6bc8cac` enviada à main/origin e publicada, sem tag V9. Smoke público em andamento; resultados ainda pendentes estão indicados explicitamente.

## Produto e referência

O arquivo original `Design Telas ChegaJunto/V9 DESIGN.png` foi aberto e estudado. Seus dez frames orientam estados da mesma página, sem utilizar recortes como assets. A referência foi preservada integralmente. AppBar “Preparar consulta”, stepper Relato/Complemento/Resumo/Perguntas/Concluir, bolhas institucionais azuis, opções com seleção teal, resumo em um card com quatro títulos discretos, conclusão com check e agendamento verdadeiro. Layout central até 760 px no desktop e largura disponível no celular; teclado, safe area, escala e temas usam os componentes existentes.

`ConsultationPreparationPage` reúne introdução, modalidade, texto, gravação, revisão da transcrição, complemento, resumo, perguntas profissionais, revisão final e conclusão. Não há lista fictícia de mensagens nem conteúdo clínico copiado do design. `ConsultationPreparationController` coordena as etapas; `ReportController` continua responsável por fonte, áudio, autosave, versão, conflito, revisão e cancelamento. Controllers são descartados na troca de conta. Rotas antigas de áudio/processamento/resumo/perguntas/revisão redirecionam para a principal e retomam o estado salvo sem gerar IA automaticamente. Home, detalhes e checklist entram pela URL principal.

Texto até 20.000 caracteres; resposta até 2.000. Áudio V8 preservado: permissão ao iniciar, PCM/WAV, pausa/retomada, 300 segundos ativos, 10 MiB, cancelamento e revisão editável antes do uso explícito. Sem diagnóstico, prescrição, dose, interpretação de exames, triagem ou classificação de emergência. A IA organiza exclusivamente o que foi informado; nada é compartilhado automaticamente com profissionais/UBS/SUS.

## Persistência e IA

Migration `20261013_0006` → parent `20261013_0005`, sem editar 0001–0005. Tabela `report_clarifications`: BIGINT unsigned, FK report CASCADE, UNIQUE `(report_id,position)`, posições 0–2, modos `free_text`/`single_choice`, opções JSON e respostas/timestamps coerentes. Campo extra `source_hash` por linha conserva respostas stale quando um novo ciclo é pulado, sem reativá-las. Relato recebe quatro campos nullable: `clarifications_source_hash`, `clarifications_completed_at`, `clarification_request_id`, `clarification_requested_at`.

Endpoints POST `report/clarifications/next`, PUT `report/clarifications/{id}`, POST `report/clarifications/skip`, sempre JWT de paciente + ownership; operador não entra. Reuso da pergunta pendente, encerramento com zero perguntas permitido, limite de três imposto no backend antes do SDK. Uma pergunta adaptativa por chamada com relato e respostas anteriores minimizados. Opções 2–4 ou texto livre, sempre alternativa com palavras próprias. `dont_know`, `dont_remember`, `prefer_not_to_answer` são omissões, não fatos, e não impedem a continuidade.

Mesmo SDK/cliente/modelos/timeout V8; Responses + Structured Outputs estrito, `store:false`, ferramentas vazias, zero retries ou fallback. Quota `clarify` 9/paciente, 45/global/dia UTC; `organize` 10/50 e `transcribe` 3/10 preservadas. `ai_usage_events` registra somente operação/modelo/estado/contadores. Reserva e falhas contam. Lease persistente evita chamadas simultâneas; nenhuma transação ou lock de quota fica aberto durante a rede externa. Falhas preservam dados anteriores e exigem nova ação explícita.

Fingerprint V8 `SHA256(original UTF-8)` permanece idêntico sem respostas atuais. Com respostas: hash versionado `v9`, original e JSON canônico de pergunta/tipo/texto em ordem. Edição de resposta invalida resumo/revisões sem apagar o resumo anterior; edição do original torna o complemento stale. Respostas stale só são substituídas após uma nova resposta válida do provedor. Documento detalhado: [contrato V9](../chega_junto_backend/docs/API_CONTRACT_V9.md).

## Evidências automatizadas e banco

| Verificação | Resultado |
| --- | --- |
| Backend completo | 486 aprovados; MySQL opt-in separado; warning TestClient/httpx conhecido. |
| Flutter | 214 aprovados; `flutter analyze` sem problemas. Inclui entrada pela Home, largura desktop 760, cinco rotas antigas e bloqueio de edição durante requisições. |
| Portal | 29 aprovados; nenhuma alteração de código. |
| Ruff / format / compileall | Aprovados. |
| MySQL 8.4 descartável | 0001→0006, metadata equivalente, downgrade vazio/reupgrade, V8 concluída preservada, downgrade ocupado recusado e reservas concorrentes de quota aprovados. Container exclusivo removido. |
| Aiven current/check | `20261013_0006 (head)`; nenhum novo upgrade detectado. |
| Integridade Aiven | 18 tabelas anteriores e todos os registros preservados imediatamente após migration; 20→21 FKs; zero órfãos; consulta V8 continua ativa. |
| Auditoria fonte | Zero achados; `.env`, CA, caches, capturas e builds ignorados. |
| Builds/auditoria Web e APK | Web release API e APK debug API aprovados; 43 arquivos Web e 172 entradas APK, zero segredos/configuração privada. `record_web` registrado. |

Cobertura nova: schema/saída/refusal/incompleto/timeout, validação de opções/omissões, max3, zero perguntas, pending reuso, edição stale, fingerprint V8/V9, organização com contexto, lease/conflito, rede sem transação, isolamento de pacientes/operador, quota UTC/concorrência/falhas, DTO/API Flutter, reentrada, cancelamento tardio, conflito sem perda, áudio/revisão humana, navegação e responsividade 320/390/1366 com fonte 1,5/2,1, claro/escuro/contraste. Testes não usam API real.

## Publicação e smoke

Render: acrescentadas somente `AI_CLARIFY_USER_DAILY_LIMIT=9`, `AI_CLARIFY_GLOBAL_DAILY_LIMIT=45` via Save only. Chave do projeto não foi lida ou copiada; modelos/flags/quotas anteriores mantidos. O ambiente Windows possui outra chave, que o usuário identificou como pertencente a outra ferramenta; não foi alterada. Auditorias comparam valores conhecidos apenas em memória, sem imprimi-los.

Deploy Render `dep-db7ddnavcj2c73d7pfo0` do commit candidato confirmado “Deploy succeeded | Live”, duração 1m09s. `/health` 200 com banco ok; OpenAPI com as cinco rotas de IA/complemento e sem segredos; paciente/operador sem token 401, next/answer/skip sem token 401, simulador 404 e ausente do schema. Nenhuma migration no startup, nenhum recurso pago ou mudança de plano.

Firebase publicado exclusivamente no projeto do app, [chega-junto-desafio-ia.web.app](https://chega-junto-desafio-ia.web.app/). Download público de `main.dart.js` corresponde byte a byte ao build auditado, com cache no-cache. Portal [chega-junto-agendamentos.web.app](https://chega-junto-agendamentos.web.app/) permanece 200, SHA-256 do index `4c93bf87e6bf3cbb27587f06f949db4d28c38903269661b8f4a70bfaddbd9133`, idêntico à V8. Nenhum deploy ou alteração de arquivos do Portal.

Plano de smoke autorizado: um fluxo texto desktop incluindo tentativa de instrução no relato e resposta maliciosa, e um fluxo Safari/iPhone físico preferencialmente por áudio. Não repetir fluxos nem executar carga; limite por ciclo permanece três perguntas. Consulta demonstrativa de 22/10/2026 14:30 deve permanecer ativa. Baseline antes do smoke: organização/revisão/final V8 atuais, zero complemento, usage histórico 5 organize + 3 transcribe. Na V9 pública em 1366×900, a versão V8 retomou diretamente “Preparação concluída”, sem forçar complemento ou chamar IA; URL principal e largura 760 confirmadas.

Android: APK debug API compilado e auditado (191.994.686 bytes). Emulador existente inicializado sem reset; `/data` tinha 327.608 KiB livres, 95% ocupado. Tentativa `adb install -r` recusada pelo Android com “Requested internal only, but not enough space”. Nenhum dado apagado, nenhum AVD recriado; teste nativo V9 não validado. APK público V8 0.8.0 permanece separado desta candidata até autorização específica de distribuição V9.

SHA-256 dos builds após proteção dos controles durante requisições: Web `main.dart.js` `9bd78470ace523c529c7586643743aef2bb68dd7d81c1873b6d5b6e4871ad4a5`; APK debug `5d1a4b9897eead3e5a548cc4c33f384b375cb6e09f05ef7a67cdf9a648ddad76`. A auditoria distingue sete exemplos numéricos de rede do SDK oficial: seis nos engines com contextos comparados ao SDK e um no snapshot debug idêntico byte a byte ao arquivo oficial. Não são endereços da máquina/projeto. Fonte e Web não contêm IP particular do projeto. Hash da referência original V9: `a3c26c43374217ac9be579e6ce7f015c25120e84fd31637f211739d6d19a9d47`.

O smoke desktop concluiu um ciclo com três perguntas reais: contexto em que percebe, objetivo da conversa e frequência. A pergunta pendente foi recuperada após Home/reentrada sem nova chamada. Uma resposta livre contendo tentativa de instrução maliciosa foi salva e editada; as duas seguintes usaram “não sei informar” e “não lembro”. Não houve insistência sobre o início já desconhecido, diagnóstico, prescrição, dose, revelação de segredo ou quarta pergunta. O resumo ignorou as instruções presentes no relato/resposta e preservou as incertezas. Três perguntas profissionais inicialmente desmarcadas; edição, seleção, remoção e inclusão de pergunta própria aprovadas. Resumo editado manualmente, revisão/conclusão salvas e recuperadas na reentrada.

Uma falha de conexão ao enviar uma omissão foi tratada sem retry automático. A leitura do banco comprovou que o PUT não persistira e nenhum SDK adicional fora acionado. A ação explícita de recuperação reusou a pergunta pendente, e o reenvio terminou com sucesso. O resumo antigo também permaneceu disponível ao cancelar a confirmação de substituição. Identificou-se ainda que os controles do resumo e da edição histórica podiam permanecer habilitados durante uma requisição; a correção bloqueia texto/opções/menus/edição enquanto busy, com teste de conservação do rascunho, suíte completa 214, analyze e ambos os builds/auditorias aprovados. Essa correção é somente Flutter; backend/migration/quotas permanecem idênticos ao commit publicado no Render.

Banco após desktop: revisão 31, organização/revisão/final atuais, três complementos respondidos e concluídos, uma pergunta profissional selecionada. Relato original permanece separado das respostas. Consulta ativa sem alterações de agendamento ou presença. Home 75% porque a confirmação de presença já estava pendente na fixture V8; a revisão final está concluída. Usage V9 desktop: `clarify` 3 succeeded, 1.792 unidades de entrada/604 de saída; `organize` 1 succeeded, 772/284. Nenhuma transcrição desktop, falha de provedor ou estimativa monetária.

Conferência visual local em 390×844: introdução, modalidade, texto, gravação/pausa/retomada/revisão de transcrição, perguntas individuais com opções/texto, resumo único, perguntas inicialmente desmarcadas, revisão e conclusão com consulta do mock aprovados. Capturas permanecem apenas em `.local/v9-qa`, ignoradas. A abertura pela Home foi corrigida para manter a URL principal e a largura de desktop, com teste de regressão dedicado. Nenhuma chamada real foi usada nessa conferência.

## Checkpoint

Commit candidato, deploy, hashes, usage real, smoke desktop/iPhone, integridade final, status main/origin e preservação V1–V8 serão preenchidos com evidências observadas. Não criar tag V9. A aprovação do usuário é necessária somente para o checkpoint oficial posterior à revisão desta candidata.

## Conferência dos 49 itens solicitados

| Item | Resultado observado |
| --- | --- |
| 1. Commit candidato | `f31c18b9cad3f9c908b76a1faf18ef90c6bc8cac` — implementação. |
| 2. Hash final | Documentação de smoke ainda em fechamento; commit de implementação acima é o publicado. |
| 3. Arquivos principais | Nova página/widgets, orquestração, repositories/mappers/modelos Flutter; schemas/models/services/endpoints/backend; migration 0006; testes e documentos. |
| 4. Design | Original aberto, estudado e preservado; SHA informado acima. |
| 5. Página | Dez estados internos; stepper de cinco etapas; máximo 760 no desktop. |
| 6. Rotas antigas | Áudio/processamento/resumo/perguntas/revisão redirecionam para principal sem geração automática. |
| 7. Orquestração | `ConsultationPreparationController` + `ReportController` existente. |
| 8. Migration | `20261013_0006`, parent 0005; 0001–0005 intactas. |
| 9. report_clarifications | FK CASCADE, UNIQUE/posição 0–2, JSON, modos e estados validados; hash por linha. |
| 10. Campos de relato | Quatro nullable de fonte/conclusão/lease, descritos acima. |
| 11. Usage | CHECK de operação inclui `clarify`, sem conteúdo clínico. |
| 12. Quotas | Clarify 9/45 UTC; organize 10/50 e transcribe 3/10 preservados. |
| 13. Next | POST autenticado, uma pergunta ou done, pending reusado. |
| 14. Answer | PUT validado/versionado; opção exata, texto ≤2.000 ou omissão. |
| 15. Skip | POST encerra sem SDK e preserva dados anteriores. |
| 16. Structured Output | Quatro propriedades obrigatórias, strict e additionalProperties false. |
| 17. Máximo 3 | Imposto no backend, inclusive sem quarta chamada; testes aprovados. |
| 18. Adaptativo | Contexto mínimo de fonte + respostas atuais; 0 perguntas permitido. |
| 19. Safety | Fonte/respostas como dados não confiáveis; sem diagnóstico, prescrição, triagem ou ferramentas. |
| 20. Hash V9 | Versionado/canônico com respostas atuais; revisões invalidadas na edição. |
| 21. V8 | Hash sem complemento idêntico; preparo antigo concluído retomado na V9 pública. |
| 22. Backend | 486 testes aprovados + 1 ensaio MySQL separado aprovado. |
| 23. Flutter | 214 aprovados; analyze sem problemas. |
| 24. Portal | 29 aprovados. |
| 25. MySQL isolado | Cadeia, metadata, dados V8, downgrade seguro e quota concorrente aprovados. |
| 26. Current | `20261013_0006 (head)`. |
| 27. Check | Nenhum upgrade pendente. |
| 28. Aiven | Dados anteriores preservados após migration; 21 FKs, zero órfãos; conferência final após smoke pendente. |
| 29. Render | Live no commit candidato; health/database 200/ok. |
| 30. Simulador | 404 e ausente do OpenAPI. |
| 31. OpenAPI | Cinco rotas de IA/complemento presentes, sem chave/prompt secreto. |
| 32. Smoke texto | Um único fluxo desktop aprovado, conclusão persistida e reentrada validada. |
| 33. Injection no relato | Não obedecida; resumo sem diagnóstico, dose, segredo ou fatos inventados. |
| 34. Resposta maliciosa | Não obedecida; contexto adaptativo e resumo mantiveram só informação relatada. |
| 35. Áudio | V8 e testes preservados; simulação local aprovada; gravação real V9 no iPhone pendente. |
| 36. Desktop | Público 1366×900, URL/largura corretas; reentrada pending validada sem nova chamada. |
| 37. iPhone | Smoke físico V9 pendente de participação do usuário. |
| 38. Android | Build/auditoria aprovados; instalação no AVD recusada por falta de espaço. |
| 39. Firebase | App publicado; bytes/SHA públicos iguais ao build auditado. |
| 40. Portal preservado | Código sem alterações/deploy; index público idêntico. |
| 41. Auditoria Web | 43 arquivos, zero achados; record_web registrado. |
| 42. Auditoria APK | 172 entradas, zero segredos/configuração privada; exemplos SDK verificados. |
| 43. Segredos | Zero em fonte/staging/Web/APK; chave Render não lida; `.env`/CA ignorados. |
| 44. Usage real | Desktop V9: 3 clarify + 1 organize succeeded, unidades descritas acima; iPhone pendente. |
| 45. Limitações | AVD sem espaço; SDK Wasm dry-run/avisos conhecidos; física Safari ainda pendente. |
| 46. Git status | Somente relatório em edição para registrar smoke; código já commitado. |
| 47. Main/origin | Sincronizadas no candidato; fechamento documental será enviado. |
| 48. V1–V8 | Objetos locais preservados e comparados ao baseline. |
| 49. Sem tag V9 | Nenhuma tag V9 criada. |

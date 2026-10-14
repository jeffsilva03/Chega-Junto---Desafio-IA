# V9 candidata — preparação conversacional guiada

Base oficial: V8 `6819ae7a6a306c963797c5caac22c56450c0ce11`, tag anotada preservada. Implementação candidata, sem tag V9. Validação/publicação em andamento; resultados ainda pendentes estão indicados explicitamente.

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
| Flutter | 213 aprovados; `flutter analyze` sem problemas. Inclui entrada pela Home, largura desktop 760 e cinco rotas antigas. |
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

Deploy candidato Render/Firebase e smoke público ainda pendentes. Publicar somente Firebase do app; Portal preservado. Plano autorizado: um fluxo texto desktop incluindo tentativa de instrução no relato e resposta maliciosa, e um fluxo Safari/iPhone físico preferencialmente por áudio. Nenhuma chamada real V9 foi feita até esta anotação. Não repetir fluxos nem executar carga; limite por ciclo permanece três perguntas. Consulta demonstrativa de 22/10/2026 14:30 deve permanecer ativa.

Android: APK debug API compilado e auditado (191.994.686 bytes). Emulador existente inicializado sem reset; `/data` tinha 327.608 KiB livres, 95% ocupado. Tentativa `adb install -r` recusada pelo Android com “Requested internal only, but not enough space”. Nenhum dado apagado, nenhum AVD recriado; teste nativo V9 não validado. APK público V8 0.8.0 permanece separado desta candidata até autorização específica de distribuição V9.

SHA-256 Web `main.dart.js`: `29d8228a2869a421043e64fbb7aaa08ee1927a03ce7ed266914fff2d685565b5`. APK debug: `8a0f3e64ac0e61e931c2c3b58414625fb5fc3e90e3acdf5f1c272a97826ad95f`. A auditoria distingue sete exemplos numéricos de rede do SDK oficial: seis nos engines com contextos comparados ao SDK e um no snapshot debug idêntico byte a byte ao arquivo oficial. Não são endereços da máquina/projeto. Fonte e Web não contêm IP particular do projeto. Hash da referência original V9: `a3c26c43374217ac9be579e6ce7f015c25120e84fd31637f211739d6d19a9d47`.

Conferência visual local em 390×844: introdução, modalidade, texto, gravação/pausa/retomada/revisão de transcrição, perguntas individuais com opções/texto, resumo único, perguntas inicialmente desmarcadas, revisão e conclusão com consulta do mock aprovados. Capturas permanecem apenas em `.local/v9-qa`, ignoradas. A abertura pela Home foi corrigida para manter a URL principal e a largura de desktop, com teste de regressão dedicado. Nenhuma chamada real foi usada nessa conferência.

## Checkpoint

Commit candidato, deploy, hashes, usage real, smoke desktop/iPhone, integridade final, status main/origin e preservação V1–V8 serão preenchidos com evidências observadas. Não criar tag V9. A aprovação do usuário é necessária somente para o checkpoint oficial posterior à revisão desta candidata.

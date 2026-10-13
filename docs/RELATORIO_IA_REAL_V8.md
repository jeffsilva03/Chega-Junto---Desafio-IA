# Chega Junto — V8 candidata: IA e transcrição reais

Data: 13/10/2026. **Implementação candidata publicada; smoke real e validação física em andamento. Sem tag V8.** V7 permanece checkpoint estável `58a33a251176441a7ce0c0111ad7be6d4f3fe005`; V1–V7 preservadas.

Sistema demonstrativo não oficial, somente dados fictícios. Nenhum conteúdo é enviado automaticamente a operador, profissional, unidade ou SUS. O usuário revisa e decide o que compartilhar.

## Arquitetura e conteúdo

Flutter → HTTPS FastAPI → ReportAiService → AiProvider → OpenAiProvider → OpenAI. Resposta validada → revisão/editável no Flutter → persistência pelo ReportWrite existente → Aiven. `FakeAiProvider` isola a suíte automática da rede e dos créditos.

Organização usa SDK oficial OpenAI 2.54.0, Responses API com JSON Schema strict, `additionalProperties=false`, `store=false`, sem tools ou estado/conversa externa. Modelos lidos do Render, conferidos somente pelos campos não secretos: `gpt-6-luna` para texto e `gpt-transcribe` para transcrição. A API key não foi revelada, copiada ou salva localmente. Sem mudança de modelo, fallback ou retry automático; timeout padrão 45 segundos, configurável 10–120, saída de texto limitada a 4.000 tokens.

O backend envia somente original_text, com instruções separadas; identificador de atendimento serve apenas para titularidade interna. Sem dados adicionais de perfil, documentos ou histórico. Prompt considera o relato dado não confiável, não obedece instruções internas e preserva incerteza. Organização não pode diagnosticar, prescrever, sugerir dose, interpretar exames, classificar urgência, triar ou completar informações ausentes. Até cinco perguntas neutras para o profissional, inicialmente desmarcadas. Chaves/títulos/ordem das quatro seções fixados pelo backend. Schema controla formato; o smoke humano deverá avaliar conteúdo antes do aceite.

## Endpoints, quota e migration

`POST /api/v1/appointments/{id}/report/organization` e `/transcription`, JWT paciente ativo + ownership, operador/simulator/contexto demo bloqueados. Desabilitados por padrão, ausentes do OpenAPI com flag false. Organização não persiste automaticamente; original/fonte/revisões/cancelamento/conflitos/saveDraft/revisão humana existentes preservados.

Migration 0005 cria somente `ai_usage_events`; anteriores intactas. Campos mínimos e índices por usuário/operação/dia e operação/dia; apenas telemetria numérica, sem conteúdo ou áudio. Calendário UTC; reservas started e falhas contam para quota. MySQL GET_LOCK serializa reserva confirmada; conexão/lock/transação terminam antes da OpenAI. Quotas: organização 10 por paciente/50 globais; transcrição 3 por paciente/10 globais por dia. Configuráveis por env; 429 sanitizado, sem divulgar saldo ou limite global ao usuário.

## Áudio e Flutter

Pacote `record` 6.2.1, compatível com Dart 3.11.1 atual. A versão mais recente exige Dart 3.12; não houve atualização ampla do SDK/dependências. `http_parser` 4.1.2 tornou-se dependência direta para MIME multipart. Captura e transcrição separadas; mock preservado sem microfone.

Captura real PCM16 mono de 16 kHz em memória, convertida em WAV, sem ffmpeg, arquivo/blob temporário ou encoder customizado de navegador. Cinco minutos = 9.600.044 bytes; parada automática em 300 segundos ativos e limite de 10 MiB. Permissão somente após toque, pausa/retomada real, alternativa em texto em caso de negação. Android inclui INTERNET e RECORD_AUDIO, sem cleartext adicional. Web requer HTTPS/localhost; Safari físico ainda precisa ser validado.

FastAPI aceita WAV/WebM/M4A/MP4/MP3 com extensão/MIME/assinatura; MP4 acomoda contêiner de áudio do Safari. Upload bounded inclusive chunked; temporário fechado em finally. Bytes não são persistidos e são limpos no cliente após processamento, cancelamento/logout/dispose. Transcrição editável até 20.000 caracteres, sem truncamento, inserida somente após “Usar transcrição no relato”; depois segue o mesmo pipeline de organização. Falha mantém original, resumo anterior e texto revisado. Troca de sessão e saída da tela invalidam respostas tardias.

## Evidências locais

- Backend: primeira regressão identificou expectativas de metadata anteriores à 0005; corrigidas sem editar migrations históricas. Suíte completa final local: **442 aprovados/1 opt-in pulado**. Ruff check/format e compileall aprovados. Aviso transitivo Starlette/httpx não bloqueante, sem atualização não relacionada.
- Provider/API/migration: 55 testes focados aprovados; SDK mockado, sem chamada OpenAI real.
- MySQL 8.4 isolado: cadeia 0001→0005, metadata idêntica, downgrade local somente da tabela nova vazia/reupgrade e quotas concorrentes aprovados; 12 reservas concorrentes respeitaram limite global 2, lock liberado ao final. Sem downgrade no Aiven.
- Flutter: 177 testes aprovados, incluindo 15 novos; analyze sem problemas. Cobertura de payload mínimo/multipart, erros/429/retry explícito, negação, start/pause/resume/stop, transcrição/revisão/uso, 10 MiB, parada em cinco minutos, cancelamento, dispose e resposta antiga após troca de sessão.
- Portal: 29 testes aprovados, nenhum arquivo funcional alterado.
- Builds Web release e APK debug com API pública concluídos. Três avisos históricos do dry run WebAssembly de flutter_tts; alvo JavaScript gerado corretamente. APK confirmou INTERNET e RECORD_AUDIO; nenhum aparelho/emulador conectado por ADB nesta etapa.
- Auditoria repetida após rebuild: 370 arquivos versionáveis; 43 arquivos Web e 172 entradas do APK, nenhuma credencial/padrão de segredo encontrado. Quatro valores privados locais comparados somente em memória. Ocorrências numéricas de IPs em snapshots/engine são exemplos do próprio SDK, conferidos contra originais; nenhum IP pessoal identificado. A chave real do Render não foi lida para comparação literal.
- Aiven: migration 0005 aplicada após testes/auditoria; `current=20261013_0005 (head)` e `check=No new upgrade operations detected`. Comparação imediatamente após migration confirmou as 17 tabelas anteriores integralmente intactas, 19 FKs anteriores, zero órfãos e usage vazio. A nova FK de usage soma-se às anteriores. Fingerprints/contagens agregados guardados somente em arquivo local ignorado; GET_LOCK/RELEASE_LOCK conferidos no Aiven.
- Busca explícita adicional em main.dart.js e todas as entradas do APK por OPENAI_API_KEY, AUTH_SECRET_KEY, OPERATOR_AUTH_SECRET_KEY, DATABASE_PASSWORD, password_hash e padrão de chave OpenAI: nenhuma ocorrência.
- Android: build/permissões aprovados. Emulador headless iniciou, mas não concluiu boot no período observado e prejudicou a resposta do navegador; encerrado sem wipe ou exclusão de dados. Teste de captura nativa preparado em integration_test/audio_capture_v8_test.dart, ainda não executado. Não afirmar validação física ou início de microfone Android; esta limitação não impede aceite se desktop e Safari físico passarem, conforme pedido.
- Desktop/áudio e Safari físico: em andamento, sem resultado presumido.

## Publicação e smoke

Variáveis de ativação/timeout/quotas salvas no Render com Save only e conferidas em modo somente leitura, sem alterar chave/modelos existentes. Candidato **392bcf8ecc018c6cd91ec27f26f3b3a0eb929951**, mensagem `feat: integra IA e transcricao reais V8`, commit/push normal em origin/main, sem tag.

Render deploy manual `dep-db79rqt9fdbs73ddkv90`, concluído em 1m22s; commit conferido no Dashboard, SDK instalado, startup/configuração aceitos. Health público 200/database ok; simulator 404, operator/patient/ambos endpoints IA sem token 401. OpenAPI contém os dois endpoints, sem segredo ou prompt. Autenticação de operador e paciente pelo usuário e criação de uma nova consulta fictícia V8 pelo Portal confirmadas; dados anteriores não foram editados.

Firebase publicou somente `chega-junto-desafio-ia`, 42 arquivos, sem alteração de configuração/plano. Após regenerar o build de gravação, main.dart.js público corresponde ao SHA-256 `66a365603414dcc0f8b219fd252f029382869f91d0709a0d9eaa74e682a1f4e6`. Portal público continua HTTP 200; index SHA-256 `4c93bf87e6bf3cbb27587f06f949db4d28c38903269661b8f4a70bfaddbd9133`, idêntico antes/depois e ao dist local. Nenhum deploy ou arquivo funcional do Portal alterado.

Plano de smoke: no máximo cinco organizações reais e duas transcrições curtas fictícias, incluindo desktop e Safari físico; nenhuma chamada real nas suítes automáticas. Caso simples via áudio desktop; pedidos de diagnóstico/dose e injection no desktop; relato desorganizado via iPhone. Usage numérico e custos só serão reportados se retornados/observados, sem estimar saldo ou inventar valores. Não reutilizar a gravação do usuário fora desse fluxo.

Três organizações reais aprovadas pela inspeção da interface: dúvida fictícia de diagnóstico, pedido fictício de alteração de dose e instrução maliciosa dentro do relato. As respostas atribuíram dúvidas ao usuário, mantiveram seções sem informação vazias e geraram perguntas neutras inicialmente desmarcadas; não diagnosticaram nem recomendaram dose. Usage agregado nesse ponto: 3 organizações succeeded, 1.396 unidades de entrada e 616 de saída retornadas pelo SDK; nenhuma transcrição iniciada. Custo monetário não consultado. Restam duas organizações e duas transcrições no orçamento do smoke.

O primeiro teste manual de microfone falhou antes da captura/upload. Console e registrant gerado identificaram MissingPluginException: o cache de compilação Web havia omitido RecordPluginWeb. Corrigido com flutter clean, pub get offline e novo build, sem editar arquivos gerados. Registrant novo e bundle confirmam plugin/worklet de gravação presentes; publicação corrigida conferida pelo hash público. Novo teste com microfone do usuário ainda pendente. Ajustado também o aviso do resumo real que ainda dizia “simulada”; mock mantém seu aviso original. Analyze e os 177 testes Flutter passaram novamente após o ajuste.

Conferência adicional enquanto se aguarda o usuário: as 17 tabelas mantêm todos os registros originais intactos, admitindo apenas os novos registros do smoke; 19 FKs anteriores, zero órfãos, usage com 3 registros. Tags locais inalteradas e consulta remota contém somente V1–V7 com os mesmos objetos/commits. Health, isolamento público e hash do Portal conferidos novamente. APK debug recompilado após o ajuste do aviso e auditado junto ao Web. A consulta fictícia criada para V8 permanece ativa para concluir os testes físicos.

## Checklist dos 46 resultados solicitados

| Item | Evidência / estado atual |
| --- | --- |
| 1. Arquitetura | Flutter → FastAPI → AiProvider → OpenAI; revisão e persistência existentes no Aiven. |
| 2. Commits candidatos | 392bcf8ecc018c6cd91ec27f26f3b3a0eb929951 publicado; correção subsequente identificável por fix: ajusta aviso e registra validacao parcial V8. |
| 3. Abstração | AiProvider, OpenAiProvider e FakeAiProvider separados. |
| 4. SDK | OpenAI Python 2.54.0. |
| 5. Responses | responses.create, sem conversa/estado externo. |
| 6. Structured Output | JSON Schema strict, additionalProperties=false, validação Pydantic. |
| 7. store=false | Configurado explicitamente e verificado nos testes do provider. |
| 8. Modelo texto | gpt-6-luna, conferido no campo não secreto do Render. |
| 9. Modelo transcrição | gpt-transcribe, conferido no campo não secreto do Render. |
| 10. Organization | POST /api/v1/appointments/{id}/report/organization. |
| 11. Transcription | POST /api/v1/appointments/{id}/report/transcription. |
| 12. Safety | Organização sem diagnóstico, prescrição, dose, triagem, interpretação ou invenção; revisão humana. |
| 13. Injection | Instrução separada, conteúdo tratado como dado; caso real aprovado. |
| 14. Minimização | Somente original_text ou áudio e parâmetros mínimos enviados ao provider. |
| 15. Migration | 20261013_0005, somente tabela/índices de usage; anteriores intactas. |
| 16. Usage | ai_usage_events sem áudio, relato, transcrição, prompt ou resposta. |
| 17. Quotas | UTC: organização 10/usuário e 50/global; transcrição 3/usuário e 10/global; started/falhas contam. |
| 18. Backend | 442 aprovados, 1 opt-in pulado. |
| 19. Flutter | 177 aprovados; analyze sem problemas. |
| 20. Portal | 29 aprovados. |
| 21. MySQL | 8.4 isolado: migration/metadata/downgrade vazio/reupgrade/12 reservas concorrentes aprovados. |
| 22. Alembic | current 0005 head; check sem novas operações. |
| 23. Aiven | 17 tabelas anteriores intactas após migration e após 3 chamadas do smoke, 19 FKs anteriores e zero órfãos; repetir ao concluir testes físicos. |
| 24. Render | Deploy dep-db79rqt9fdbs73ddkv90 Live, health 200/database ok. |
| 25. Simulator | 404 público. |
| 26. Isolamento | Operator JWT recusado nos testes de IA; endpoints públicos sem token 401; logins de ambas as interfaces confirmados. |
| 27. Texto real | 3/5 chamadas: diagnóstico, dose e injection aprovados; simples e desorganizado pendentes. |
| 28. Diagnóstico | Dúvida atribuída ao usuário, sem diagnóstico na resposta real. |
| 29. Dose | Sem recomendar alteração/dose na resposta real. |
| 30. Transcrição | 0/2 chamadas; repetição manual após correção do build pendente. |
| 31. Formatos | WAV/WebM/M4A/MP4/MP3 validados com fixtures locais; captura real produzirá WAV, ainda pendente. |
| 32. Limites | Upload 10 MiB; gravação 300 segundos ativos; texto/transcrição 20 mil caracteres, sem truncar. |
| 33. Desktop | Organização real aprovada; microfone aguardando repetição do usuário. |
| 34. Safari iPhone | Teste físico V8 pendente; sucesso anterior V7 não contado como teste de áudio. |
| 35. Android | APK debug/permissões aprovados; emulador sem boot concluído; teste nativo preparado, não executado. |
| 36. Firebase | Apenas app principal publicado, hash atual conferido. |
| 37. Portal | HTTP 200 e hash idêntico; sem deploy/alteração funcional. |
| 38. Web | Auditoria repetida no build corrigido: 43 arquivos, comparação privada em memória e padrões sem achados. |
| 39. APK | Auditoria repetida no build corrigido: 172 entradas, sem achados. |
| 40. API key | Valor do Render nunca revelado/copiado; SDK somente backend; buscas de padrões/nomes no frontend sem achados. |
| 41. Limitações | Cache inicial do plugin corrigido; validações físicas ainda pendentes; avisos históricos flutter_tts não bloqueantes. |
| 42. Usage/custo | 3 chamadas: entrada 1.396, saída 616; dólares não observados nem estimados. |
| 43. Arquivos | Candidato inicial: 48 arquivos (git show --stat 392bcf8); correção: aviso do resumo, teste/driver Android e este relatório. |
| 44. Git status | Correção preparada para commit/push normal; estado conferido após o commit. Testes físicos continuam pendentes. |
| 45. V1–V7 | Preservadas na comparação local e remota após as 3 chamadas reais. |
| 46. V8 | Sem tag; exige aprovação posterior para checkpoint. |

## Reproduzir e referências

Contrato, limites, erros e procedimento detalhados em [API_CONTRACT_V8](../chega_junto_backend/docs/API_CONTRACT_V8.md). Comandos locais: pytest/Ruff/compileall, testes/analyze Flutter, npm test Portal, build Web release e APK debug com DATA_SOURCE=api/API_BASE_URL do Render. A integração segue [Structured Outputs](https://developers.openai.com/api/docs/guides/structured-outputs), [Responses](https://developers.openai.com/api/docs/guides/migrate-to-responses), [transcrição](https://developers.openai.com/api/docs/guides/speech-to-text) e [record](https://pub.dev/packages/record/versions/6.2.1).

Relatório parcial: validações de microfone/transcrição desktop e Safari físico ainda dependem da participação do usuário. Não considerar V8 pronta para aceite enquanto essas evidências estiverem pendentes. Não criar tag V8 sem aprovação posterior do usuário.

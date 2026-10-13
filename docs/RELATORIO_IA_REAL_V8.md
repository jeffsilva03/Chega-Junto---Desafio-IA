# Chega Junto — V8 candidata para revisão

13/10/2026. IA e transcrição reais publicadas, com fluxo de áudio validado no computador e no Safari do iPhone físico. **Sem tag V8.** V1–V7 preservadas; rollback V7: `58a33a251176441a7ce0c0111ad7be6d4f3fe005`.

Sistema demonstrativo não oficial, somente dados fictícios. Concluir salva a preparação; nada é enviado automaticamente a profissionais, UBS ou SUS.

## Arquitetura e proteção do conteúdo

Flutter → HTTPS FastAPI → ReportAiService → AiProvider → OpenAiProvider → OpenAI. Resposta validada → revisão/editável no Flutter → ReportWrite existente → Aiven. FakeAiProvider isola testes automáticos da rede e dos créditos.

SDK oficial OpenAI Python **2.54.0**, Responses API, JSON Schema strict com additionalProperties=false, store=false explícito, sem tools, conversa externa, fallback ou retry automático. Timeout 45 segundos, configurável entre 10–120; saída limitada a 4.000 tokens. Modelos conferidos somente nos campos não secretos do Render: **gpt-6-luna** e **gpt-transcribe**. A chave não foi revelada, copiada ou salva localmente.

Somente original_text é enviado à organização; identificador do atendimento serve à autorização interna. Transcrição envia somente áudio e parâmetros mínimos. Perfil, documentos e histórico não são anexados. Instruções separadas tratam o relato como dado não confiável e preservam incerteza. Organização não pode diagnosticar, prescrever, recomendar dose, interpretar exame, triar, classificar urgência ou inventar fatos. Quatro seções com chave/título/ordem fixados pelo backend: reason/Motivo da consulta, points/Pontos relatados, context/Contexto informado e other/Outros pontos importantes. Até cinco perguntas neutras, inicialmente desmarcadas.

## Endpoints, uso e banco

POST `/api/v1/appointments/{id}/report/organization` e `/transcription`: JWT paciente ativo + ownership; operador e contexto demo bloqueados. AI_ENABLED=false por padrão remove esses endpoints do OpenAPI. Organização não persiste automaticamente; fonte, revisão, conflito, rascunho e confirmação humana existentes preservados.

Migration **20261013_0005** cria somente ai_usage_events e seus índices. Migrations 0001–0004 intactas. Usage contém operação/provider/model/outcome/telemetria numérica/datas, sem áudio, relato, prompt, resposta, transcrição ou identificador externo do provider. Quotas por dia calendário UTC: organização **10/usuário e 50/globais**; transcrição **3/usuário e 10/globais**. Started/falhas contam. GET_LOCK em conexão dedicada serializa contagem/reserva confirmada; lock e transação terminam antes da OpenAI. Erro 429 sanitizado, sem revelar saldo global.

MySQL 8.4 isolado: cadeia 0001→0005, metadata equivalente, downgrade somente da tabela nova vazia/reupgrade aprovados; 12 reservas concorrentes respeitaram limite global 2 e liberaram lock. No Aiven, current=0005 head e check sem novas operações. Comparação pós-migration confirmou as 17 tabelas anteriores integralmente idênticas; comparação final após o smoke confirmou todos os registros originais preservados, 19 FKs anteriores e zero órfãos. Nova FK de usage soma-se às anteriores. Sem downgrade no Aiven.

## Gravação e revisão

record **6.2.1**, compatível com Dart 3.11.1; sem atualização ampla de SDK/dependências. Captura PCM16 mono 16 kHz em memória e WAV, sem ffmpeg ou arquivo/blob temporário de gravação. Cinco minutos ativos = 9.600.044 bytes; parada automática em 300 segundos, limite de upload **10 MiB**. Permissão após toque, pausa/retomada, alternativa em texto. Android declara INTERNET e RECORD_AUDIO; sem cleartext adicional.

Backend aceita WAV/WebM/M4A/MP4/MP3 com extensão/MIME/assinatura, incluindo limite de corpo chunked e fechamento do upload em finally. Áudio não persiste no banco. Cliente limpa bytes após processamento, cancelamento/logout/dispose e descarta respostas tardias. Transcrição editável até 20.000 caracteres, sem truncar; inserção somente após Usar transcrição no relato. Erros preservam conteúdo anterior. Mock continua disponível sem microfone/rede OpenAI.

## Smoke real e correções verificadas

Foram realizadas **5 organizações e 3 transcrições**, todas succeeded. O limite inicial era 5/2; as duas transcrições iniciais foram usadas pelo usuário no computador, e ele autorizou explicitamente **uma única transcrição extra de 10–20 segundos no iPhone**, informado do consumo de créditos. Quotas de produção não foram alteradas. Nenhuma chamada extra foi feita para as correções de interface.

- Dúvida fictícia de diagnóstico: dúvida atribuída ao usuário, sem afirmar diagnóstico; perguntas neutras.
- Pedido fictício de dose: sem recomendar alteração/dose/medicamento.
- Prompt injection: instrução maliciosa tratada como dado, sem obedecer ao pedido de diagnosticar.
- Desktop: usuário confirmou transcrição funcionando perfeitamente; interface mostrou captura de 10 segundos. Edição, uso explícito, organização real, quatro seções e três perguntas inicialmente desmarcadas conferidos. Edição humana do resumo, escolha de uma pergunta e revisão final salvas sem nova IA; persistência conferida no Aiven.
- Safari do iPhone físico: usuário confirmou gravação/transcrição e organização funcionando perfeitamente. Utilizou relato fictício livre diferente do exemplo sugerido. Confirmou Revisão final concluída após restaurada a consulta; fonte correspondente, quatro seções, uma pergunta selecionada e ambas as revisões atuais confirmadas no banco. A preservação de incerteza foi observada no caso de dúvida de diagnóstico; o relato final do iPhone não continha os marcadores de incerteza do exemplo sugerido.

O primeiro teste de microfone falhou antes da captura/upload: registrant Web em cache havia omitido RecordPluginWeb, causando MissingPluginException. Corrigido com flutter clean/pub get offline/rebuild, sem editar gerados; plugin/worklet presentes no bundle e testes reais posteriores aprovados. O aviso do resumo real que ainda dizia simulada foi corrigido; mock mantém sua mensagem.

Durante a limpeza, o agente cancelou prematuramente somente a consulta criada para V8, antes de o usuário concluir a última revisão. Isso expôs o estado vazio sem Material/Scaffold, com tipografia de depuração vermelha e sem navegação. A consulta própria foi restaurada por atualização guardada, verificando que não pertencia aos registros anteriores e preservando o relato. **Permanece ativa para revisão do usuário.** A tela vazia agora usa a estrutura visual normal e oferece Atualizar atendimentos/Voltar ao início; loading/erro também recebem contexto Material. Teste de regressão verifica tipografia, navegação e recuperação quando atendimento volta a estar disponível.

Usage retornado: texto **2.355 unidades de entrada e 1.064 de saída**, agregadas nas cinco chamadas. Transcrição retornou unidades **null**, não zero. Oito usage rows, sem falhas. Custo monetário não consultado nem estimado.

## Testes, builds e publicação

Backend: **442 aprovados/1 opt-in pulado**; Ruff check/format e compileall aprovados. Provider/API/migration com SDK fake, sem OpenAI real nas suítes. Flutter: **178 aprovados**, incluindo regressão da tela vazia; analyze sem problemas. Portal: **29 aprovados**, sem alteração funcional. Não houve necessidade de repetir suítes backend/Portal após correção exclusivamente Flutter.

Web release e APK debug com DATA_SOURCE=api/API_BASE_URL público compilados. Três avisos históricos flutter_tts no dry run WebAssembly; alvo JavaScript gerado corretamente. APK/permissões aprovados. Nova tentativa de emulador, com menos recursos, concluiu boot em cerca de 60 segundos, mas instalação normal e APK x64 de teste falharam por armazenamento insuficiente; sem wipe, exclusão de dados ou instalação concluída. Emulador encerrado. **Captura nativa Android não validada**; teste/driver preparados. Limitação registrada conforme regra do pedido que permite seguir com desktop + Safari físico aprovados. APK público anterior 0.7.0 não foi substituído por APK debug V8.

Render Live: deploy `dep-db79rqt9fdbs73ddkv90`, backend `392bcf8ecc018c6cd91ec27f26f3b3a0eb929951`. Chave/modelos existentes preservados; ativação/timeout/quotas conferidos sem revelar segredo. Health público 200/database ok; simulator 404; endpoints paciente/operador e ambos IA sem token 401. OpenAPI contém os dois endpoints, sem segredo ou prompt. Logins reais de ambas as interfaces e criação da fixture pelo Portal aprovados.

Firebase publica somente o app principal, 42 arquivos, mesmo plano/configuração. Hash final do main.dart.js: `cda6df8781e391eeb8e98c9e6b90bec756e0f456e7eb7b4a76af74682940f876`. Portal HTTP 200, index SHA-256 `4c93bf87e6bf3cbb27587f06f949db4d28c38903269661b8f4a70bfaddbd9133`, idêntico antes/depois e ao dist local; sem deploy do Portal.

Auditorias finais: **370 arquivos versionáveis, 43 arquivos Web e 172 entradas do APK**, nenhuma credencial/padrão de segredo encontrado. Quatro valores privados locais comparados somente em memória; busca explícita por OPENAI_API_KEY, AUTH_SECRET_KEY, OPERATOR_AUTH_SECRET_KEY, DATABASE_PASSWORD, password_hash e padrão de chave. IPs numéricos em snapshots/engine correspondem a exemplos dos originais do SDK, sem IP pessoal identificado. A chave real do Render não foi lida para comparação literal. Nenhum segredo identificado nas verificações; logs não incluem corpos de erro do provider. APK debug final SHA-256: `b46678479c4de2591ec916196640c681f2e9794a23bc9a0fb3483b91ae959cae`.

Commits candidatos publicados por push normal: `392bcf8ecc018c6cd91ec27f26f3b3a0eb929951` e `2bf6736b8d106b984ddca69a02ebc2905a047146`; correção final identificada por `fix: trata preparo sem atendimento e conclui validacao V8`. Árvore de trabalho e origin/main conferidos após commit/push final. Tags locais/remotas V1–V7 preservadas, **V8 ausente**. Pastas de vídeos do usuário preservadas e excluídas apenas localmente do status, sem versionar ou apagar.

## Os 46 resultados solicitados

| Item | Resultado |
| --- | --- |
| 1. Arquitetura | Flutter → FastAPI → AiProvider → OpenAI; revisão/persistência existentes no Aiven. |
| 2. Commits | Candidatos acima; commit final e HEAD conferíveis por git log. |
| 3. Provider abstraction | AiProvider, OpenAiProvider, FakeAiProvider. |
| 4. SDK | OpenAI Python 2.54.0. |
| 5. Responses | responses.create, sem estado/conversa externa. |
| 6. Structured Output | JSON Schema strict, additionalProperties=false, Pydantic. |
| 7. store=false | Explícito e verificado nos testes. |
| 8. Texto | gpt-6-luna, env Render. |
| 9. Transcrição | gpt-transcribe, env Render. |
| 10. Organization | POST /api/v1/appointments/{id}/report/organization. |
| 11. Transcription | POST /api/v1/appointments/{id}/report/transcription. |
| 12. Safety | Sem diagnóstico, prescrição, dose, triagem, interpretação ou invenção; revisão humana. |
| 13. Injection | Instrução separada; caso real aprovado. |
| 14. Minimização | Somente original_text ou áudio/parâmetros mínimos. |
| 15. Migration | 20261013_0005; anteriores intactas. |
| 16. Usage | ai_usage_events, sem conteúdo ou áudio. |
| 17. Quotas | UTC: texto 10/50; áudio 3/10, usuário/global. |
| 18. Backend | 442 aprovados/1 opt-in pulado. |
| 19. Flutter | 178 aprovados; analyze sem problemas. |
| 20. Portal | 29 aprovados. |
| 21. MySQL | 8.4 isolado, migration/metadata/concorrência aprovadas. |
| 22. Alembic | 0005 head; check sem novas operações. |
| 23. Aiven | 17 tabelas anteriores intactas; 19 FKs anteriores; zero órfãos. |
| 24. Render | Health 200/database ok; Live. |
| 25. Simulator | 404 público. |
| 26. Isolamento | JWT operador recusado nos testes IA; público sem token 401; logins confirmados. |
| 27. Texto real | 5 succeeded: diagnóstico, dose, injection, desktop/áudio e relato livre iPhone. |
| 28. Diagnóstico | Sem diagnóstico na resposta real; dúvida atribuída. |
| 29. Dose | Sem recomendar dose/alteração na resposta real. |
| 30. Transcrição | 3 succeeded: duas desktop, uma extra iPhone autorizada. |
| 31. Formatos | WAV real desktop/iPhone; WAV/WebM/M4A/MP4/MP3 com fixtures locais, sem alegar smoke real dos demais. |
| 32. Limites | 10 MiB, 300 segundos ativos, texto/transcrição 20 mil caracteres, sem truncar. |
| 33. Desktop | Captura/transcrição, edição/uso, organização e revisão final aprovados. |
| 34. Safari físico | Usuário confirmou fluxo e revisão final; persistência conferida. |
| 35. Android | Build/permissões aprovados; instalação bloqueada por espaço no AVD; captura não validada. |
| 36. Firebase | Somente app principal; bundle final conferido. |
| 37. Portal | HTTP 200/hash constante; nenhum deploy/alteração funcional. |
| 38. Web | Auditoria de padrões/credenciais sem achados. |
| 39. APK | Auditoria de padrões/credenciais sem achados. |
| 40. API key | Só backend/Render; valor nunca revelado/copiado. |
| 41. Erros/limitações | Cache do plugin e tela vazia corrigidos; Android nativo pendente por espaço; avisos flutter_tts históricos. |
| 42. Usage/custo | Texto entrada 2.355/saída 1.064; áudio unidades null; dólares não observados. |
| 43. Arquivos | Relação completa abaixo. |
| 44. Git status | Conferido limpo após commit/push final. |
| 45. V1–V7 | Tags locais e remotas inalteradas. |
| 46. V8 | Sem tag; aguarda aprovação do usuário para checkpoint oficial. |

## Reproduzir e referências

Contrato: [API_CONTRACT_V8](../chega_junto_backend/docs/API_CONTRACT_V8.md). Comandos: pytest, Ruff check/format, compileall; flutter test/analyze; npm test no Portal; flutter build web --release e build apk --debug com DATA_SOURCE=api/API_BASE_URL Render. Não executar novamente smoke OpenAI automaticamente: o orçamento autorizado já foi usado.

Referências oficiais: [Structured Outputs](https://developers.openai.com/api/docs/guides/structured-outputs), [Responses](https://developers.openai.com/api/docs/guides/migrate-to-responses), [transcrição](https://developers.openai.com/api/docs/guides/speech-to-text), [record 6.2.1](https://pub.dev/packages/record/versions/6.2.1).

## Arquivos alterados desde V7
- `chega_junto_app/README.md`
- `chega_junto_app/android/app/src/main/AndroidManifest.xml`
- `chega_junto_app/integration_test/audio_capture_v8_test.dart`
- `chega_junto_app/lib/app/app.dart`
- `chega_junto_app/lib/app/app_dependencies.dart`
- `chega_junto_app/lib/core/network/api_client.dart`
- `chega_junto_app/lib/core/services/ai_assistant_service.dart`
- `chega_junto_app/lib/core/services/audio_capture_service.dart`
- `chega_junto_app/lib/core/services/audio_draft_service.dart`
- `chega_junto_app/lib/core/services/record_audio_capture_service.dart`
- `chega_junto_app/lib/core/state/report_controller.dart`
- `chega_junto_app/lib/core/widgets/preparation_view.dart`
- `chega_junto_app/lib/data/api/api_ai_assistant_service.dart`
- `chega_junto_app/lib/data/api/api_audio_draft_service.dart`
- `chega_junto_app/lib/data/mock/mock_ai_assistant_service.dart`
- `chega_junto_app/lib/data/mock/mock_audio_draft_service.dart`
- `chega_junto_app/lib/features/ai_summary/presentation/pages/ai_summary_page.dart`
- `chega_junto_app/lib/features/ai_summary/presentation/pages/report_processing_page.dart`
- `chega_junto_app/lib/features/pre_visit_report/presentation/pages/audio_report_page.dart`
- `chega_junto_app/lib/features/pre_visit_report/presentation/pages/pre_visit_report_page.dart`
- `chega_junto_app/pubspec.lock`
- `chega_junto_app/pubspec.yaml`
- `chega_junto_app/test/ai_v8_test.dart`
- `chega_junto_app/test/api_widget_test.dart`
- `chega_junto_app/test/report_controller_test.dart`
- `chega_junto_app/test/report_flow_test.dart`
- `chega_junto_app/test_driver/audio_capture_v8_driver.dart`
- `chega_junto_backend/.env.example`
- `chega_junto_backend/README.md`
- `chega_junto_backend/app/api/audio_upload_limit.py`
- `chega_junto_backend/app/api/v1/ai.py`
- `chega_junto_backend/app/core/config.py`
- `chega_junto_backend/app/main.py`
- `chega_junto_backend/app/models/__init__.py`
- `chega_junto_backend/app/models/ai_usage.py`
- `chega_junto_backend/app/schemas/ai.py`
- `chega_junto_backend/app/services/ai_provider.py`
- `chega_junto_backend/app/services/ai_quota.py`
- `chega_junto_backend/app/services/openai_provider.py`
- `chega_junto_backend/app/services/report_ai.py`
- `chega_junto_backend/docs/API_CONTRACT_V8.md`
- `chega_junto_backend/migrations/versions/20261013_0005_ai_usage.py`
- `chega_junto_backend/pyproject.toml`
- `chega_junto_backend/tests/conftest.py`
- `chega_junto_backend/tests/fake_ai_provider.py`
- `chega_junto_backend/tests/test_ai_api.py`
- `chega_junto_backend/tests/test_ai_provider.py`
- `chega_junto_backend/tests/test_ai_upload.py`
- `chega_junto_backend/tests/test_models_migration.py`
- `chega_junto_backend/tests/test_mysql_migrations.py`
- `chega_junto_backend/uv.lock`
- `docs/RELATORIO_APK_ANDROID_0_7_0.md`
- `docs/RELATORIO_IA_REAL_V8.md`

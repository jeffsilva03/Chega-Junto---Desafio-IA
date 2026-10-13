# Chega Junto — V8 candidata: IA e transcrição reais

Data: 13/10/2026. **Implementação local em validação; publicação e smoke real ainda pendentes. Sem tag V8.** V7 permanece checkpoint estável `58a33a251176441a7ce0c0111ad7be6d4f3fe005`; V1–V7 não serão modificadas.

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
- Auditoria: 368 arquivos versionáveis; 43 arquivos Web e 172 entradas do APK, nenhuma credencial/padrão de segredo encontrado. Quatro valores privados locais comparados somente em memória. Ocorrências numéricas de IPs em snapshots/engine são exemplos do próprio SDK, conferidos contra originais; nenhum IP pessoal identificado. A chave real do Render não foi lida para comparação literal.
- Aiven antes: revisão 0004, 17 tabelas anteriores, 19 FKs, zero órfãos; fingerprints/contagens agregados guardados somente em arquivo local ignorado. GET_LOCK/RELEASE_LOCK conferidos no Aiven. Migration e validação posterior ainda pendentes.
- Render, Firebase, desktop, iPhone e Android físico: pendentes neste registro inicial.

## Publicação e smoke

Variáveis de ativação/timeout/quotas salvas no Render com Save only e conferidas em modo somente leitura, sem alterar chave/modelos existentes. Deploy ainda pendente. Somente site do app será publicado; Portal preservado. No máximo cinco chamadas reais de organização e duas de transcrição curta fictícia no smoke inicial; nenhuma chamada real nas suítes automáticas. Usage numérico e custos só serão reportados se retornados/observados, sem estimar saldo ou inventar valores.

## Reproduzir e referências

Contrato, limites, erros e procedimento detalhados em [API_CONTRACT_V8](../chega_junto_backend/docs/API_CONTRACT_V8.md). Comandos locais: pytest/Ruff/compileall, testes/analyze Flutter, npm test Portal, build Web release e APK debug com DATA_SOURCE=api/API_BASE_URL do Render. A integração segue [Structured Outputs](https://developers.openai.com/api/docs/guides/structured-outputs), [Responses](https://developers.openai.com/api/docs/guides/migrate-to-responses), [transcrição](https://developers.openai.com/api/docs/guides/speech-to-text) e [record](https://pub.dev/packages/record/versions/6.2.1).

Commit candidato, resultados públicos, auditorias, status Git e comparação final das tags serão acrescentados antes da entrega. Não criar tag V8 sem aprovação posterior do usuário.

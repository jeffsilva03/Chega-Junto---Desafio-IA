# Contrato de IA V8 candidata

Complementa V3/V4/V7 sem alterar os contratos de persistência de relato. Sistema demonstrativo, somente dados fictícios. O Portal não recebe funcionalidades de IA.

## Ativação e identidade

`AI_ENABLED` desabilitado por padrão: rotas abaixo ausentes, inclusive no OpenAPI, com HTTP 404. Quando habilitado, startup exige chave e os dois modelos configurados. Bearer JWT de **paciente ativo** obrigatório; contexto demo/simulator e token de operador não são aceitos. O atendimento deve pertencer ao paciente; recurso alheio retorna 404 antes de quota/provedor.

## Organização

`POST /api/v1/appointments/{appointment_id}/report/organization`

```json
{"original_text": "Relato fictício informado pelo usuário."}
```

Texto não vazio, máximo 20.000 caracteres. Nenhum outro campo aceito. Retorno HTTP 200:

```json
{
  "sections": [
    {"section_key": "reason", "title": "Motivo da consulta", "text": ""},
    {"section_key": "points", "title": "Pontos relatados", "text": ""},
    {"section_key": "context", "title": "Contexto informado", "text": ""},
    {"section_key": "other", "title": "Outros pontos importantes", "text": ""}
  ],
  "questions": [{"text": "Pergunta neutra para o profissional?", "is_selected": false}]
}
```

Exemplo de formato, não de resultado clínico. Backend fixa chaves, títulos e ordem. Até cinco perguntas, inicialmente desmarcadas. Seções sem informação ficam vazias. Conteúdo é revalidado após Structured Outputs estrito; recusa, resposta incompleta, vazia ou malformada geram erro seguro. O endpoint **não grava** relato/resumo/perguntas. O Flutter mantém o fluxo `ReportWrite`, `intent=organize`, `organization_source_text` e revisão humana. Fonte alterada ou sessão encerrada durante a chamada invalida a resposta na interface.

## Transcrição

`POST /api/v1/appointments/{appointment_id}/report/transcription`

Multipart com um campo `file`, máximo **10 MiB (10.485.760 bytes)** de áudio. Envelope multipart também limitado, inclusive streaming sem Content-Length. Aceita WAV, WebM, M4A, MP4 e MP3, com extensão, MIME compatível e assinatura inicial do contêiner. MP4 é permitido para compatibilidade de contêiner de áudio Safari. Nome recebido não é encaminhado: o provedor recebe nome neutro `recording.<extensão>`.

HTTP 200: `{"text": "Texto transcrito para revisão."}`. Texto vazio ou superior a 20.000 caracteres é rejeitado, sem truncamento. Sem IDs do provedor, métricas ou token na resposta. O upload é fechado em `finally`; não há tabela/coluna de áudio ou transcrição, armazenamento de objeto ou cópia permanente. Somente o texto explicitamente aceito pelo usuário entra posteriormente em `original_text`.

O Flutter grava PCM16 mono de 16 kHz via pacote `record` e monta WAV em memória, sem arquivos temporários. Limite de 300 segundos ativos, com pausa/retomada real. Cinco minutos ocupam 9.600.044 bytes, abaixo do limite. Permissão somente após toque; negação mantém alternativa digitada. Cancelamento, saída da rota, logout e dispose encerram captura e invalidam respostas tardias. Bytes são limpos após envio/erro; texto transcrito exige revisão e ação “Usar transcrição no relato”.

## Quota e telemetria

Janela diária do calendário **UTC**, contando `started`, `succeeded` e `failed`. Falhas ou resultado incerto consomem reserva, evitando repetição gratuita de solicitações potencialmente cobradas. Validação/titularidade/quota negadas não chamam OpenAI.

| Operação | Por paciente/dia | Global/dia |
| --- | --- | --- |
| organize | 10 | 50 |
| transcribe | 3 | 10 |

Limites configuráveis, inclusive zero para suspender uma operação. Em MySQL, `GET_LOCK` por operação serializa contagem e insert; a reserva é commitada antes de liberar o lock na mesma conexão. O lock e a conexão são liberados **antes** da chamada externa. Erro de liberação invalida a conexão do pool. Nenhuma transação de autenticação/titularidade permanece aberta durante a espera da OpenAI. Em SQLite efêmero de testes, um mutex local substitui o lock MySQL; não existe fallback SQLite em produção.

Migration `20261013_0005`, parent `20261012_0004`, cria somente `ai_usage_events`: id, user_id, operation, provider, model, outcome, input_units, output_units, created_at e completed_at. FK RESTRICT e índices `(user_id, operation, created_at)` / `(operation, created_at)`. Contadores são tokens quando retornados pelo SDK; indisponíveis ficam null. Nenhum conteúdo, prompt, resposta bruta, áudio, JWT ou chave é armazenado. Reservas interrompidas permanecem `started` e continuam contando. Downgrade local somente com tabela vazia; não executar downgrade no Aiven.

## Provedor, privacidade e segurança de conteúdo

`ReportAiService → AiProvider → OpenAiProvider`. `FakeAiProvider` nos testes não acessa rede. SDK oficial `openai` 2.54.0; Responses `text.format` JSON Schema `strict=true`, `additionalProperties=false`, `store=false`, `tools=[]`, sem conversation/previous_response_id. Apenas `original_text` como mensagem de usuário; instruções separadas. O ID do atendimento fica no backend, fora do prompt. Transcrição envia somente áudio e parâmetros mínimos. Sem perfil, CPF, SUS, e-mail, documentos, saúde cadastrada ou identificadores no request ao provedor.

Os modelos vêm exclusivamente do ambiente; não há fallback nem roteamento automático. `max_retries=0`; timeout configurável entre 10 e 120 segundos, padrão 45. Organização limita saída a 4.000 tokens. Request adicional só mediante ação explícita. Falha da IA não apaga rascunho ou resumo anterior. `store=false` desativa armazenamento da resposta para recuperação na Responses API; não representa promessa de retenção zero de terceiros.

Prompt trata relato como dado, rejeita instruções nele e preserva incertezas. A IA organiza informações explícitas e gera perguntas neutras para o profissional; não diagnostica, prescreve, sugere dose/tratamento, interpreta exames, faz triagem ou classifica urgência. Não completa fatos ausentes. Structured Outputs controla forma, não garante segurança semântica: smoke humano crítico é obrigatório antes da aceitação.

## Erros

Envelope existente: `{"error":{"code":"...","message":"..."}}`. Nenhum erro bruto, request ID, detalhe financeiro, saldo, stack trace, chave ou URL interna é devolvido.

| HTTP | Código | Comportamento |
| --- | --- | --- |
| 401 | invalid_token | Paciente ausente/inativo ou token alheio ao domínio paciente |
| 404 | resource_not_found | Recurso alheio/ausente ou IA desabilitada |
| 422 | validation_error | Relato inválido ou multipart ausente |
| 422 | audio_invalid | Conteúdo/formato/MIME/extensão incompatíveis |
| 413 | audio_too_large | Arquivo ou envelope acima do limite |
| 422 | transcription_too_long | Fazer gravação menor, sem truncar |
| 429 | ai_daily_limit_reached | Limite diário da demonstração atingido |
| 503 | ai_unavailable | Provedor/timeout/rate limit/crédito/configuração de modelo indisponível |
| 503 | ai_invalid_output | Recusa/incompleto/schema inválido/vazio |
| 503 | transcription_failed | Provedor ou texto de transcrição inválido |

## Ambiente e deploy

Nomes: `AI_ENABLED`, `OPENAI_API_KEY`, `OPENAI_TEXT_MODEL`, `OPENAI_TRANSCRIPTION_MODEL`, `OPENAI_TIMEOUT_SECONDS`, `AI_ORGANIZE_USER_DAILY_LIMIT`, `AI_ORGANIZE_GLOBAL_DAILY_LIMIT`, `AI_TRANSCRIBE_USER_DAILY_LIMIT`, `AI_TRANSCRIBE_GLOBAL_DAILY_LIMIT`.

Chave somente no Render; nunca solicitar pelo chat, copiar para ambiente local, Git, Flutter ou Firebase. `.env.example` contém placeholders. Validar suítes sem OpenAI real, migration em MySQL 8.4 isolado e auditoria antes de commit/push candidato. Comparar contagens/fingerprints/FKs no Aiven antes/depois da 0005. Deploy manual Render, health/security, smoke limitado a cinco organizações e duas transcrições fictícias, depois publicação somente do site Flutter existente. Não publicar Portal, ativar billing ou criar tag V8.

Fontes oficiais consultadas: [Structured Outputs](https://developers.openai.com/api/docs/guides/structured-outputs), [Responses e store](https://developers.openai.com/api/docs/guides/migrate-to-responses), [transcrição](https://developers.openai.com/api/docs/guides/speech-to-text), [record](https://pub.dev/packages/record/versions/6.2.1).

# Chega Junto — Portal público de agendamentos V7

Atualização: 13/10/2026. **Status: implementação publicada na main, backend V7 ativo no Render e portal publicado no Firebase.** Migration aplicada no Aiven; um operador criado pelo usuário em terminal privado e confirmado por contagem. Verificações públicas de saúde, proteção, CORS e artefatos aprovadas. Login real, tokens cruzados em produção, E2E e iPhone V7 ainda pendentes; tag V7 não criada.

**AMBIENTE DEMONSTRATIVO — SISTEMA NÃO OFICIAL.** Somente dados fictícios; sem integração SUS/governamental ou prontuário.

## Checkpoint anterior preservado

V6 foi fechada antes de iniciar V7:

- Commit `24794e296f0eb63ad60af42d594106b96ff70c66`.
- Mensagem `chore: publica Flutter Web no Firebase V6`.
- Tag anotada `V6`, objeto `e27c4f632e5b5189ab837ad33694d7c2f7dfa35c`, publicada; peeled commit igual à HEAD do fechamento.
- `main` e `origin/main` sincronizadas após push. V1–V5 confrontadas e intactas.
- Seis arquivos: README raiz, `.gitignore`/README/`.firebaserc`/`firebase.json` Flutter e relatório V6. Sem código backend/portal/Dart ou build no checkpoint.
- Cadastro fictício novo pela URL pública Firebase → Home → Perfil → alteração/salvamento do nome → logout → login → nome persistido, executado pelo agente.
- “Validação manual realizada com sucesso no Safari de um iPhone físico utilizando a URL pública HTTPS.” Confirmação do usuário; sem inventar modelo, iOS, rede ou desempenho.
- 325 backend, 162 Flutter e 18 portal aprovados; analyze/Ruff/compileall/Alembic aprovados. Bundle publicado SHA-256 `801D0188BB02DD312BAC230CA07CFBEFB35BDEE41D33B929C905919B8A7FF120`.

App preservado: https://chega-junto-desafio-ia.web.app e https://chega-junto-desafio-ia.firebaseapp.com. A V7 não modifica os arquivos de publicação Flutter nem a tag V6.

## Arquitetura e implementação

```text
Paciente → Flutter Firebase → JWT paciente ─┐
                                          ├→ FastAPI Render → TLS VERIFY_IDENTITY → Aiven
Operador → Portal Firebase → JWT operador ─┘
Simulator → FastAPI loopback (somente local)
```

Tabela separada `operators`, com id BIGINT UNSIGNED AUTO_INCREMENT, nome, e-mail trim/lowercase UNIQUE com collation binária coerente com users, hash Argon2id, ativo e timestamps DATETIME(6). InnoDB/utf8mb4. Migration `20261012_0004`, parent `20261012_0003`, cria somente essa tabela. Migrations 0001/0002/0003 permanecem sem diff.

JWT de operador usa segredo próprio, HS256 allowlisted, issuer `chega-junto-operator`, claims sub/iat/exp/iss/actor_type. Não carrega nome/e-mail/saúde. Ativação exige segredo com pelo menos 32 bytes, diferente do segredo paciente. `OPERATOR_PORTAL_ENABLED=false` é padrão, com 404 e ausência no OpenAPI. Expiração padrão 60 minutos. Usuário gerou/salvou o segredo novo diretamente no Render pelo botão Generate, após preparação das configurações; nenhum valor foi lido, impresso, enviado pelo chat ou salvo localmente. Startup V7 aprovado com a validação de chave habilitada.

Nove operações operator: login/me, busca por e-mail exato, facilities, lista/create/detail/PATCH/cancel de appointments. `OperatorBearer` no OpenAPI. Cadastro de operador não possui rota pública. Conta ausente executa Argon2 dummy; senha errada/ausência/inatividade têm erro 401 idêntico. Cada request protegido verifica operador ativo.

Regra de agendamento única em `SchedulingService`; alias SimulatorService mantém compatibilidade. Reutilizados repository/DTOs V4. Consulta/checklist continuam transacionais, titular imutável, conclusão preservada quando descrição não muda, checklist vazio permitido, cancelamento idempotente sem DELETE. Próxima consulta considera somente scheduled.

Operador só acessa identificação mínima e dados de agendamento/unidade/checklist. Nenhuma superfície de medicamentos, alergias, histórico, documentos médicos, relatos, resumo/IA, perguntas ou notificações pessoais foi adicionada. Detalhes no [contrato V7](../chega_junto_backend/docs/API_CONTRACT_V7.md).

## Portal e sessão

Aplicação vanilla existente preservada; nova tela/estado de login de operador, aviso demonstrativo permanente, sem signup. Token exclusivamente em memória; reload exige login. Logout/401 limpam sessão e dados visíveis. Requests pendentes são abortados; respostas tardias não restauram dados após logout. Sem retry automático de POST/PATCH/cancelamento. Erros são sanitizados e nome/e-mail são renderizados como texto.

Modo público usa `https://chega-junto-api.onrender.com` e `/api/v1/operator`, com Authorization Bearer; não envia header simulator. Configuração local gerada em memória por serve.py permite modo operator ou simulator explícito, apenas com API loopback. Nenhum SDK/Auth Firebase, PWA ou service worker novo.

## Firebase e pacote estático

Segundo site criado com sucesso, sem habilitar cobrança:

| Item | Valor |
| --- | --- |
| Project ID | `chega-junto-desafio-ia` |
| Site ID portal | `chega-junto-agendamentos` |
| Target | `portal`, mapeado somente ao segundo site |
| URL pública | https://chega-junto-agendamentos.web.app |
| Alternativa pública | https://chega-junto-agendamentos.firebaseapp.com |
| Plano | Spark; Cloud Billing `billingEnabled=false`, conta não vinculada antes da criação |
| Deploy portal | Concluído em 13/10/2026 via CLI manual, 11 arquivos de dist, somente hosting:portal |

Configuração separada dentro de `chega_junto_portal/`; target explícito no firebase.json e .firebaserc. O deploy manual deve usar `--only hosting:portal --project chega-junto-desafio-ia`. A configuração V6 do app permanece intacta.

`npm run build` usa allowlist e gera dist ignorado, somente index.html/css/js/assets (inclui fontes e licença). Não copia README, testes, scripts, .env, Git, logs, capturas ou credenciais. Sem build system/dependências de produção adicionais.

HTML, CSS e JS sem hash usam no-cache. Assets usam max-age=3600. Headers reais conferidos em todos os 11 arquivos: nosniff, no-referrer e CSP restrita à origem própria e API HTTPS Render; sem inline scripts, objetos ou frames. Todos retornam HTTP 200 e bytes idênticos ao dist. `.env`, README, arquivo de teste e config.json retornam 404. Os 52 arquivos dos bundles Flutter/portal foram auditados sem achados de valores secretos locais, JWT/hash completos, PEM ou variáveis de segredo. Main.dart.js público mantém o SHA-256 V6.

## Migrations e testes locais

- Snapshot estático de todas as migrations comparado ao metadata final; DDL offline MySQL inclui 17 tabelas de domínio e controle Alembic.
- Ensaio real em container oficial `mysql:8.4`, descartável, porta somente loopback 33070 e banco dedicado `chega_junto_v7_qa`: upgrade do zero 0001 → 0002 → 0003 → 0004, comparação de metadata sem divergência, tabelas vazias, downgrade somente 0004 com tabela vazia e reaplicação aprovados. TLS do backend/Aiven não foi alterado; conexão simples pertence exclusivamente ao container de teste.
- Ensaio adicional de downgrade até a base encontrou limitação histórica na 0001 ao remover índices usados por FKs do MySQL. Não se editou 0001 nem se executou downgrade no Aiven. A reversão nova 0004 recusa apagar operadores existentes.
- Backend: suíte de autenticação, JWT inválido/expirado/issuer/assinatura/actor/algoritmo, conta inativa, configuração segura, isolamento em ambos os sentidos, disabled/OpenAPI, criação segura/duplicidade e testes de agendamentos V4 executados também através do namespace operator.
- E2E isolado: cadastra paciente e operador em SQLite efêmero, login operador, busca exata, cria consulta/checklist, autentica paciente, lê agenda/preparo, marca item obrigatório, edita pelo operador, confirma atualização pelo paciente, cancela e confirma ausência de próxima ativa. Sem Aiven nos testes.
- Suíte completa após ajuste solicitado de domínio/senha: **389 aprovados, 1 opt-in pulado**, warning conhecido TestClient/httpx. Teste MySQL opt-in aprovado separadamente antes desse ajuste, que não altera schema. Ruff check/format (92 arquivos) e compileall aprovados. Testes do script/getpass e auth também executados separadamente: **33 aprovados**, incluindo Gmail normalizado, senhas de 8 e 128 caracteres aceitas e de 7/129 recusadas. O container de QA foi encerrado/removido após o ensaio.
- Portal: **29 testes Node aprovados**; sintaxe JS e build estático aprovados. Incluem fluxo API, sessão em memória, logout/401, respostas tardias, ausência de persistência, métodos/filtros e aviso/login sem signup.
- Flutter: **162 testes aprovados**, analyze sem problemas, format 119 arquivos sem alterações; fonte/build/configuração V6 preservados.

Comando do teste MySQL opt-in exige container dedicado vazio; não rodar novamente sobre banco já preenchido. A suíte normal o pula. Nenhum Docker, SQLite ou conexão sem TLS é usado no runtime Render/Aiven.

## Aiven e ponto de interação segura

Verificação antes do upgrade: revision `20261012_0003`, 16 tabelas de domínio, **19 FKs e zero órfãos**. Contagens principais: 8 users/perfis, 2 facilities, 6 appointments, 12 checklist items. Nenhum registro pessoal/hash/segredo foi impresso; snapshots/scripts QA ficam em .local ignorado.

Aplicado `uv run alembic upgrade head`, exclusivamente a nova 0004. `alembic current`: **`20261012_0004 (head)`**; `alembic check`: **No new upgrade operations detected**. Comparação após migration: fingerprints e contagens das 16 tabelas anteriores **idênticos**, nenhuma tabela com registros alterados; 19 FKs/zero órfãos; **operators=0**. Nenhum seed, downgrade, reset ou alteração de credenciais. A API Render anterior continua compatível com a extensão aditiva do schema.

Auditoria pré-migration: **347 arquivos versionáveis**, quatro valores reais locais comparados somente em memória, zero achados de credenciais, JWT/hash completos, PEM, cookies, token Firebase/GitHub, host Aiven ou IP particular. **52 arquivos de frontend** (41 Flutter + 11 portal dist), zero valores reais/segredos/tokens/certificados. Referências a nomes de variáveis, contratos Bearer e loopback em testes/configuração local são intencionais; o modo público seleciona exclusivamente HTTPS Render. Build/dist/caches/capturas/QA continuam ignorados. Auditoria final de produção será repetida após deploy.

Preview visual do novo login observado, com banner e campos acessíveis, senha limpa após tentativa e erro sanitizado; não foi teste de login real de operador. A porta temporária 5501 não integra o CORS local e não será acrescentada preventivamente. Captura ignorada em `.local/firebase-qa/v7-operator-login-preview.png` do app. Preview e container encerrados; portal original em 5500 reiniciado com `--mode simulator` explícito, preservando o ambiente local.

Depois dos testes e da migration validada, **o usuário deve executar em seu terminal privado**:

```powershell
cd 'C:\Users\jeffo\Desktop\ChegaJunto - Desafio IA\chega_junto_backend'
uv run python -m scripts.create_operator
```

Nome sugerido `Operador Demonstrativo`. Por solicitação posterior do usuário, e-mails válidos de qualquer domínio são aceitos, inclusive `@gmail.com`; `example.test` é opcional para demonstração. Senha escolhida pelo usuário, 8–128 caracteres, ocultada por getpass e confirmada. A mesma política vale no cadastro, login API e formulário do portal. Não enviar senha ao chat nem salvá-la em arquivo. Criar somente um operador. Não repetir após sucesso; duplicidade é recusada. Sem comando remoto/público de criação. Dados de pacientes e agendamentos continuam fictícios.

Confirmação posterior do usuário: operador criado com sucesso no terminal privado. Leitura agregada confirmou **operators=1**, `0004 (head)`, Alembic check sem operações, 19 FKs/zero órfãos e fingerprints/contagens das 16 tabelas anteriores idênticos. Nenhum nome/e-mail de operador, senha ou hash de operador foi consultado ou incluído no relatório. A pausa B6 foi atendida.

## Publicação realizada e verificações públicas

Commit de implementação `f54a2dbd4fdf70e7f91d68d636f1d5df6adf1db4`, mensagem `feat: publica portal de agendamentos com auth de operador V7`: 38 arquivos intencionais, 1370 inserções/51 remoções. Auditoria staged sem achados; diff --check limpo. Commit/push na main após migration, criação manual do operador e testes. V6 permanece `24794e296f0eb63ad60af42d594106b96ff70c66`; objetos e commits V1–V6 remotos conferidos e intactos. Nenhuma tag V7 criada.

Render: deploy manual da implementação `dep-db6npe2j9qps739pt7pg` concluído em 12/10, duração 2m19s. Atualização final somente de CORS em 13/10, com build existente, deploy `dep-db7088qj9qps73ap2r1g`, duração 31,7s, Live no mesmo commit. Plano Free, comandos/runtime e TLS mantidos. `OPERATOR_PORTAL_ENABLED=true`, validade 60 minutos e segredo próprio no Render. SIMULATOR_MODE permanece false.

Verificações HTTPS após publicação: `/health` 200 com status/database ok; `/api/v1/simulator/appointments` 404; `/api/v1/operator/auth/me` sem token 401; `/api/v1/me/profile` sem token 401. OpenAPI expõe nove operações operator e OperatorBearer, sem simulator. Preflight das duas origens do portal retorna 200 com Access-Control-Allow-Origin exato; duas origens Flutter preservadas também aprovadas. Origem desconhecida retorna 400 sem permissão. A primeira verificação identificou ausência das origens portal na configuração salva; corrigida e comprovada antes do deploy Firebase.

CLI Firebase publicou somente hosting:portal com sucesso; segundo site separado, sem substituir Flutter. Interface pública de login/banner observada. O plano foi reconfirmado sem Cloud Billing vinculado antes da publicação. A sessão de navegador anterior não foi preservada entre retomadas; entrada privada de operador e paciente fictício solicitada ao usuário, sem novas contas ou pedido de senha no chat.

## Validações ainda necessárias

1. Confirmar login real de operador/paciente usando suas telas públicas, com senhas mantidas privadas. Conta de paciente deve ser fictícia.
2. Validar tokens cruzados em produção usando logins reais via QA manual privada; nenhum token deve ser extraído do runtime do navegador ou exposto em logs/arquivos. A configuração JWT local não deve ser presumida igual à de produção.
3. Verificações públicas de saúde/proteção/OpenAPI/CORS já aprovadas conforme seção acima.
4. Deploy Firebase e conferência de conteúdo/cache/CSP/site Flutter já aprovados conforme seção acima.
5. Login real seguro no portal; erro de senha, loading/teclado, logout, busca, unidades, lista/filtros. Nenhum segredo em console, CORS exato e sem Mixed Content.
6. E2E desktop com conta fictícia: criar consulta futura/checklist, verificar Home/Agenda/Detalhes/Preparo no app, concluir obrigatório/progresso, editar horário e conferir, cancelar e confirmar ausência da próxima ativa.
7. Usuário valida recebimento da consulta no Safari de iPhone físico pela URL pública. A validação V6 não comprova automaticamente o E2E remoto V7.
8. Auditoria final Git/builds/sites/docs e status limpo com main sincronizada. Só então tag anotada V7, push somente V7, hashes conferidos e V1–V6 preservadas. Sem amend/force push.

## Limitações

Demonstrativo, sem SUS/governo; operador manual, token em memória, sem recuperação de senha, MFA, refresh, RBAC avançado, auditoria administrativa completa, cadastro de unidades ou dados clínicos pelo portal. CORS não é autorização. Cancelamento mantém relações e não revoga o JWT de paciente. Escritas com timeout precisam de leitura antes de repetir. As limitações Render Free e a rotação histórica pendente documentada na V5 permanecem, sem mudança automática de credenciais.

Sem IA/áudio/transcrição reais, OAuth, push/WebSocket, domínio customizado, keep-alive ou billing. Login real/tokens cruzados em produção, E2E/iPhone e tag V7 ainda pendentes.

Fontes oficiais consultadas: [Firebase multisites](https://firebase.google.com/docs/hosting/multisites), [PyJWT usage](https://pyjwt.readthedocs.io/en/stable/usage.html), [Argon2-cffi](https://argon2-cffi.readthedocs.io/en/stable/howto.html).

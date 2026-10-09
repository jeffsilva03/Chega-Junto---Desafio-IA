# Chega Junto — V3, Fase 4: cadastro e autenticação mínima

Data: 9 de outubro de 2026. Ambiente: Windows, Python 3.14.3, MySQL Aiven 8.4.11; Flutter 3.41.4/Dart 3.11.1. Somente dados fictícios. Execução local, sem Render, commit, push ou tag.

## 1. Arquitetura

Flutter Android/Web → HTTP REST → FastAPI local → SQLAlchemy/PyMySQL → Aiven MySQL com TLS/VERIFY_IDENTITY. AuthRepository possui implementações mock e API; a escolha continua centralizada na composição. Nenhuma credencial do banco ou segredo de assinatura pertence ao Flutter. Cadastro e login são públicos; as 29 operações de produto exigem Bearer no modo normal. `/health` permanece público.

## 2. Migration

Nova revisão `20261009_0002`, dependente de `20261009_0001`. A migration histórica foi preservada. A nova revisão adiciona `users.email VARCHAR(254) COLLATE utf8mb4_bin UNIQUE`, `password_hash VARCHAR(255)` e `is_active BOOLEAN NOT NULL DEFAULT 1`. E-mail/hash são nullable para preservar contas legadas; cadastro novo exige ambos. Pré-checagem interrompe antes do DDL se encontrar e-mails legados equivalentes após trim/lowercase.

O e-mail existente é movido de `user_profiles` para `users`, normalizado; a coluna antiga é removida para evitar duas fontes canônicas. Telefone, nascimento, CPF, CEP, rua, número, bairro, cidade, UF e contato de emergência tornam-se nullable. Nome continua obrigatório; SUS continua nullable e somente leitura. Perfil novo não recebe valores inventados. Nenhuma tabela nova, percentual persistido ou campo de transcrição foi criado. Permanecem 16 tabelas de negócio + `alembic_version`.

MySQL DDL não é totalmente transacional: migration deve ser executada explicitamente, após inspeção e com política de backup adequada ao ambiente. Nenhum downgrade/reset foi executado. O downgrade implementado recusa perfis incompletos, em vez de fabricar dados para restaurar NOT NULL.

## 3. Modelo de credenciais

Identidade canônica em `users`; nome em `user_profiles`. E-mail é aparado e convertido para minúsculas no cadastro, login e edição do perfil. UNIQUE no banco cobre colisões concorrentes; conflito retorna `409 email_already_registered`. Atualização de nome/e-mail ocorre atomicamente, e `/auth/me`, perfil e login usam a mesma fonte. JWT identifica por ID estável, portanto alteração de e-mail não muda titularidade.

Senha: texto de 8 a 128 caracteres Unicode, sem trim, truncamento ou regras arbitrárias de símbolos. Validação independente no backend; confirmação existe somente no Flutter. Senha não é persistida, retornada nem registrada em logs. Campos extras como `user_id`, `password_hash` e `confirm_password` são rejeitados.

## 4. Algoritmo de hash

Argon2id pelo `argon2-cffi` 25.1.0, `PasswordHasher` com defaults da biblioteca: custo de memória 65536 KiB, tempo 3 e paralelismo 4; salt aleatório por hash. Verificação suporta rehash após login se os parâmetros forem atualizados. Conta ausente passa por verificação dummy para reduzir diferença grosseira de tempo; usuário ausente, senha errada, conta inativa ou sem hash recebem o mesmo 401. Não há hash/senha real nos relatórios.

Referências primárias: [API do argon2-cffi](https://argon2-cffi.readthedocs.io/en/stable/api.html), [guia FastAPI de senha/JWT](https://fastapi.tiangolo.com/tutorial/security/oauth2-jwt/).

## 5. JWT

PyJWT 2.15.1, HS256 fixo na assinatura e allowlist de verificação. Claims obrigatórias: `sub` (ID decimal como string), `iat`, `exp`, `iss=chega-junto`. Expiração padrão: 60 minutos, configurável de 1 a 1440. Assinatura, issuer, expiração, emissão futura e formato/faixa do ID são conferidos. O token não inclui e-mail, senha, nome, perfil ou dados clínicos.

`AUTH_MODE=jwt` é padrão. A chave de assinatura exige pelo menos 32 bytes; ausência/configuração curta impede startup de maneira sanitizada. Neste ambiente foi configurada uma chave aleatória de desenvolvimento uma única vez no `.env` ignorado; a aplicação não gera chave no startup. `.env.example` contém somente a variável vazia. Não foi criada chave de produção. [Referência PyJWT](https://pyjwt.readthedocs.io/en/latest/usage.html).

Flutter usa AuthTokenStore abstraído e MemoryAuthTokenStore em Android/Web. Fechar/reiniciar o app ou recarregar a Web exige login novamente. Não há localStorage, cookie, senha armazenada ou pacote adicional de persistência. Logout elimina token e estado local; um JWT previamente copiado continua válido até expirar, pois não há revogação/refresh nesta fase.

## 6. Endpoints

| Método | Endpoint | Contrato |
| --- | --- | --- |
| POST | `/api/v1/auth/register` | nome/e-mail/senha; 201 com token Bearer e identidade mínima |
| POST | `/api/v1/auth/login` | e-mail/senha; 200 com token Bearer e identidade mínima |
| GET | `/api/v1/auth/me` | Bearer obrigatório; 200 id/nome/e-mail |

Total atual: 32 operações `/api/v1` + `/health` = 33. Erros mantêm envelope `error.code/message`: 401 credenciais/token inválidos, 409 e-mail existente, 422 validação, 503 dependência indisponível. 401 inclui `WWW-Authenticate: Bearer`. Swagger documenta HTTPBearer nas rotas protegidas; register/login/health não exigem token. Payload de login é JSON, sem fluxo OAuth2 fictício.

## 7. Resolução de usuário

Dependency central resolve `sub` e busca conta existente/ativa em cada request. Não confia em query/body/header de identidade fornecido pelo cliente; `user_id` permanece rejeitado nos comandos de produto. Token inválido jamais cai para demo. `AUTH_MODE=demo` permite somente o contexto demo explícito local/teste, respeitando DEMO_MODE/DEMO_USER_ID; é proibido em APP_ENV=production. `/auth/me` sempre exige token, inclusive nesse modo. Flutter API usa JWT normalmente, sem bypass.

No Flutter, ApiClient aplica Authorization automaticamente somente em requests autenticados. 401 de login não encerra outra sessão; 401 de produto expira a sessão correspondente. Requisições antigas recebem um token store limitado à geração da conta e não podem usar o token de uma conta posterior. O escopo de produto é recriado e seus clientes/pedidos são descartados ao mudar identidade.

## 8. Titularidade

As consultas/alterações continuam filtradas pelo UserContext do backend. Atendimento, checklist, presença, unidade acessível, lembrete vinculado, saúde, histórico, relato, review, final review e notificação de outro titular retornam 404 indistinguível de inexistência. Perfil e preferências usam o titular autenticado. IDs continuam BIGINT UNSIGNED no banco e strings decimais na API/Flutter.

Logout descarta controllers, repositories e caches da conta, encerra TTS, cancela timers/autosave e limpa perfil, saúde, notificações, agenda, lembretes, preferências e relato/rascunho. A conta B cria novos controllers e não herda texto, revisão, seleção de perguntas, badge ou preferências da conta A. IA e áudio continuam locais/mockados.

## 9. Transações

Hash calculado antes da transação. Cadastro grava user, perfil mínimo e as duas preferências com defaults oficiais na mesma transação; token/DTO são construídos antes do commit para evitar conta parcial se essa etapa falhar. Falha em qualquer inserção causa rollback integral. Precheck de e-mail ajuda UX; UNIQUE é a proteção final, inclusive em corrida. IntegrityError só vira conflito de e-mail quando a colisão é confirmada após rollback.

Novas contas têm zero atendimentos, saúde, histórico, lembretes, notificações e relatos. Preferências são criadas deterministicamente, sem copiar alterações da demo. Perfil aceita nome/e-mail e demais campos null; o adapter Flutter converte campos vazios em null e aplica a resposta canônica.

## 10. Seed

Seed atualizado para a revisão 0002 e e-mail canônico em users. Conta demo legada fica com hash null e não possui login por senha; suas fixtures permanecem disponíveis somente pelo modo demo explícito. Não foram geradas/distribuídas senhas demo. Cadastro real nunca chama seed.

Após a migration, o seed foi executado e reconheceu a fixture existente sem sobrescrever dados. Fingerprints de todas as linhas originais confirmaram preservação, considerando apenas a transferência de e-mail entre tabelas. Contagens legadas: 1 usuário/perfil, 2 unidades, 3 atendimentos, 7 itens, 1 lembrete, 4 medicamentos, 3 alergias, 6 registros, 2 documentos textuais, 6 notificações, 1 relato, 0 seções/perguntas e 1 par de preferências.

## 11. Testes

- Backend: **280 testes aprovados**, incluindo os 219 anteriores. SQLite efêmero isolado, sem herdar segredos locais. Dois titulares com tokens próprios e recursos controlados foram testados nos dois sentidos para atendimentos, relatos, histórico, notificações e lembretes. Novos cenários: cadastro mínimo/atômico, regras, normalização, UNIQUE/corrida, rollback de preferências, login, e-mail canônico, JWT inválido/expirado/inativo/ausente, proteção de todas as 29 operações, titularidade, contas A/B, listas vazias, OpenAPI e CORS Authorization.
- Flutter: **156 testes aprovados em DATA_SOURCE=mock**, preservando os 126 anteriores e acrescentando 30 testes de autenticação, token, erros, loading, confirmação local, retry, troca A/B, 401, perfil incompleto e responsividade/teclado/fonte até 2x.
- Backend Ruff check/format e compileall aprovados. Permanece somente warning conhecido TestClient/httpx.
- Flutter analyze sem problemas; format aplicado. Build Web release API/loopback e APK debug API/emulador aprovados. Permanecem os três avisos conhecidos do dry run Wasm do flutter_tts; alvo JavaScript aprovado.
- Snapshot de migrations compara a aplicação de 0001 + 0002 ao metadata atual; SQL offline continua compilando em dialeto MySQL. Teste de corrida é controlado, não ensaio de concorrência real sob carga.

## 12. Validação Aiven

TLS/VERIFY_IDENTITY e CA mantidos. Banco configurado `defaultdb`, MySQL 8.4.11. Antes: revisão 0001 e exatamente 17 tabelas; nenhuma estrutura desconhecida. Depois: **20261009_0002 (head)**; **No new upgrade operations detected**. Todas as linhas anteriores preservadas por fingerprints; seed idempotente. Nenhum downgrade, reset, exclusão ou alteração das fixtures de produto.

**Smoke real aprovado:** uma única conta inteiramente fictícia de domínio example.test foi cadastrada pela tela Flutter Web release, servida em loopback com origem CORS exata autorizada. Register retornou sessão; Flutter aplicou Bearer, consultou me e abriu Home sem atendimento. Perfil mostrou nome/e-mail e dados opcionais não informados, sem SUS/unidade inventados. Logout levou ao Login; entrar novamente restaurou a mesma identidade. Agenda, medicamentos/alergias e notificações ficaram vazios. Reload da Web eliminou a sessão em memória e exigiu novo login, também validado.

Conferência direta do Aiven após o smoke: exatamente **2 users, 2 user_profiles e 2 linhas em cada tabela de preferências**. As demais contagens ficaram idênticas às anteriores. A única nova conta está ativa, usa hash Argon2id e possui todos os campos opcionais de perfil null. Nenhuma fixture demo foi alterada; todas as linhas originais continuaram presentes com os mesmos fingerprints. Alembic current/check foram repetidos com head 0002 e nenhuma operação pendente. A conta fictícia permanece para rastreabilidade, sem segunda conta ou exclusão automática. A senha usada no smoke não foi persistida em arquivo/documentação/terminal.

Health real retornou HTTP 200 com status/database ok; GET perfil sem token retornou 401. Não registrar host, usuário MySQL, senha, URL de conexão, token, hash real ou chave de assinatura neste documento. Servidores locais e aba de teste foram encerrados ao finalizar; nenhuma alteração de firewall.

### Validação manual posterior no iPhone — Fase 4

Após a geração deste relatório, o usuário confirmou cadastro e login reais no Flutter Web aberto no Safari de um iPhone físico, conectado ao FastAPI local e Aiven, com entrada no fluxo autenticado. O primeiro acesso apresentou uma versão/cache antiga do navegador; recarregar/reabrir a versão atual resolveu o acesso e o cadastro funcionou, sem mudança funcional adicional no código. Não foram fornecidos logs, status HTTP, tempos ou modelo do aparelho. As contagens e fingerprints acima documentam o smoke anterior, não uma nova inspeção do banco após o teste manual. O histórico da Fase 3 permanece preservado no relatório de integração.

## 13. Limitações

Somente MVP com dados fictícios. Não está liberado para dados médicos reais ou publicação em produção. Sem refresh/revogação, recuperação/verificação de e-mail, troca de senha, Google/Apple OAuth, MFA, papéis/administração, exclusão de conta ou envio de mensagens. Token em memória requer novo login ao reiniciar. HTTP é exclusivamente desenvolvimento local; publicação futura exige HTTPS e gestão própria dos segredos. CORS usa origens exatas e Authorization; não é autorização. Sem deploy, firewall automático, IA/áudio reais, push ou upload.

Não há criação de consultas pela nova conta nesta fase; estados vazios são esperados. Não foi usado seed para dar dados à conta de validação. O teste com dois titulares é automatizado/isolado, sem criar uma segunda conta no Aiven.

## 14. Próximos passos

Revisar esta entrega e autorizar a fase seguinte. Para testes locais, preencher configuração ignorada, iniciar backend, escolher DATA_SOURCE=api e criar uma conta fictícia pela tela Cadastro. Instruções completas Android/Web/iPhone e política de sessão estão no README Flutter e no relatório de integração. Auditoria dos 302 arquivos versionáveis e dos assets Web/APK não encontrou credenciais reais, IP privado, JWT completo ou hash real. .env e CA continuam ignorados e não rastreados. Não houve commit/push/tag. Render e evoluções de autenticação dependem de nova autorização.

# Chega Junto — V3, Fases 3 e 4: integração e autenticação

**Estado atual:** a seção 19 registra a Fase 4 e substitui as limitações anteriores sobre identidade demo, ausência de autenticação e ausência de escrita real. As seções 1–18 preservam o registro da entrega da Fase 3; os comandos de execução continuam válidos, agora com cadastro/login real no modo API.

Data: 9 de outubro de 2026. Escopo: Flutter Android/Web → FastAPI **local** → Aiven MySQL. Documentos de referência: `RELATORIO_BACKEND_FUNCIONAL_V3.md`, `API_CONTRACT_V3.md`, `RELATORIO_VALIDACAO_AIVEN_V3.md` do backend e `PROPOSTA_MODELAGEM_BACKEND_V3.md` deste aplicativo.

Ambiente validado: Windows, Flutter 3.41.4, Dart 3.11.1 e Python 3.14.3.

## 1. Resumo

Foram acrescentados quatro ApiRepositories, cliente HTTP central e composição por configuração. Os mocks continuam disponíveis e são o padrão. As telas e a navegação da V2 foram preservadas; os ajustes visuais se limitam aos estados necessários para rede, salvamento, conflito e ausência de dados. Textos que afirmavam que todo salvamento durava somente a sessão foram corrigidos para comportar os dois modos.

Nenhum código de backend, schema ou migration foi alterado nesta fase. Não houve deploy, autenticação real, IA real, transcrição real, upload, push, commit ou push Git. A execução real de validação foi somente de leitura; as mutações foram verificadas com HTTP falso controlado.

## 2. Configuração mock/api

`core/config/data_config.dart` lê `DATA_SOURCE` e `API_BASE_URL` por `--dart-define`. `app/app_dependencies.dart` escolhe as implementações uma única vez. Valores inválidos são rejeitados; o modo API exige uma origem HTTP/HTTPS explícita, sem caminho ou credenciais. Não há detecção automática de IP/dispositivo, troca de modo nas features ou fallback para mock após falha.

Comandos PowerShell, a partir de `chega_junto_app`:

```powershell
flutter pub get
flutter run -d chrome --dart-define=DATA_SOURCE=mock
flutter run -d chrome --web-hostname 127.0.0.1 --web-port 5173 --dart-define=DATA_SOURCE=api --dart-define=API_BASE_URL=http://127.0.0.1:8000
flutter devices
flutter run -d emulator-5554 --dart-define=DATA_SOURCE=api --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

O identificador do emulador depende da máquina. Para iniciar o backend, em outro terminal a partir da raiz do projeto:

```powershell
cd chega_junto_backend
uv run uvicorn app.main:app --host 127.0.0.1 --port 8000
```

O backend utiliza seu `.env` e CA locais. O Flutter conhece somente a URL da API. A origem Web fixa evita liberar portas aleatórias no CORS; `CORS_ALLOWED_ORIGINS` no `.env` local deve incluir exatamente `http://127.0.0.1:5173`. `localhost` e `127.0.0.1` são origens diferentes. Não utilizar wildcard como solução.

## 3. API client

`core/network/api_client.dart` usa [`package:http`](https://pub.dev/packages/http), com JSON UTF-8, Accept/Content-Type, paginação, validação de URL e erros centralizados. Não existem chamadas HTTP nas telas. O cliente não registra corpos, dados de saúde ou credenciais e não segue redirects automaticamente.

Conexão: 30 segundos no transporte nativo. Requisição completa: 90 segundos em todas as plataformas, incluindo leitura do corpo. Na Web, o navegador gerencia o tempo de estabelecimento da conexão; não há uma segunda configuração artificial de connect timeout. O prazo total continua aplicado e aborta a requisição. `AbortableRequest` também cancela requisições pendentes no descarte do cliente.

Não existe retry automático de requisições, especialmente POST de lembrete. Uma desconexão/timeout durante escrita produz erro com indicador de resultado incerto. No lembrete, o próximo botão passa a conferir a Agenda por leitura. Um POST confirmado seguido de falha no GET mantém o lembrete canônico e oferece recarregar, sem apresentá-lo como falha de criação.

## 4. ApiRepositories

| Repository | Operações implementadas |
|---|---|
| `ApiProfileRepository` | GET/PUT perfil; GET/PUT medicamentos e alergias em conjunto; GET histórico paginado e detalhe sob demanda |
| `ApiPreparationRepository` | Overview; agenda paginada; detalhe; preparo; checklist; presença; lembretes; relato; review; revisão final; remoção de resumo |
| `ApiNotificationRepository` | GET lista paginada com `unread_count`; PATCH leitura |
| `ApiPreferencesRepository` | GET/PUT preferências de avisos; GET/PUT acessibilidade |

São **27 operações HTTP de produto** implementadas. Os dois GET de unidades do contrato não têm tela independente na V2; os dados da unidade chegam incorporados aos atendimentos. `/health` foi usado na validação de infraestrutura. Não foram criados endpoints.

Todos os caminhos abaixo têm prefixo `/api/v1`:

```text
GET, PUT     /me/profile
GET, PUT     /me/health-items
GET          /me/health-records
GET          /me/health-records/{id}
GET, PUT     /me/notification-preferences
GET, PUT     /me/accessibility-preferences
GET          /me/notifications
PATCH        /me/notifications/{id}
GET          /preparation/overview
GET          /appointments
GET          /appointments/{id}
GET          /appointments/{id}/preparation
GET          /appointments/{id}/checklist
PATCH        /appointments/{id}/checklist/{item_id}
GET, PUT     /appointments/{id}/attendance
GET, POST    /reminders
GET, PUT     /appointments/{id}/report
POST         /appointments/{id}/report/review
PUT          /appointments/{id}/final-review
DELETE       /appointments/{id}/report/summary
```

Os GET específicos de preparo e presença estão disponíveis e testados no adapter. A UI aproveita os estados já incorporados ao overview e ao detalhe, evitando exigir esses GET adicionais para cada renderização.

Checklist e presença só substituem estado após sucesso. Após as mutações, é relido o agregado canônico do preparo/overview. Lista de consultas, histórico, notificações e lembretes percorrem páginas internamente; a UI continua recebendo listas. Histórico não baixa documentos na listagem inicial.

## 5. Controllers alterados

`PreparationController` mantém loading/erro/retry, agenda, lembretes e agregado de preparo. `ProfileController` mantém perfil, saúde, preferências e inbox; salva respostas canônicas, faz rollback das preferências em falhas e permite retry. Detalhes de atendimento/histórico são carregados sob demanda e reutilizados apenas durante a sessão; não há cache persistente novo.

`ReportController` reidrata o relato, serializa escritas e mantém revisão canônica. A composição injeta a política de autosave: 600 ms no modo API; a jornada mock mantém o comportamento demonstrativo anterior. Navegar também solicita o envio de alterações pendentes. A aplicação continua usando `SpeechController`, `MockAiAssistantService` e `MockAudioDraftService` locais.

## 6. Models/DTOs alterados

O mapper `data/api/api_mapping.dart` centraliza snake_case, datas e IDs. IDs e revisões persistidas são exclusivamente strings decimais; respostas numéricas de identificadores são rejeitadas, inclusive para valores acima da precisão segura de JavaScript. Contagens e percentuais continuam números.

Instantes UTC são interpretados como UTC e convertidos para exibição local. Datas civis (`birth_date`, `reference_date`) são decompostas por calendário, sem conversão de fuso. O perfil mantém o formato visual `dd/MM/yyyy` e cidade/UF, com conversão no adapter.

`HealthItem`, seções e perguntas têm identidade canônica separada da identidade temporária de edição. Novos itens omitem ID; existentes enviam ID retornado pelo servidor. `PreVisitReport` agora conserva seções, perguntas, seleção/ordem, revisão, marcadores e datas de revisão/finalização. `PreparationOverview` aceita ausência de próximo atendimento; `PreparationProgress` conserva percentuais e contagens do servidor. `NotificationInbox` inclui o badge canônico.

O PUT de perfil envia somente os 15 campos permitidos; não envia `id`, `user_id`, `sus_card_number`, `created_at` ou `updated_at`. PUT de saúde sempre envia as duas listas completas, substituídas pela resposta canônica após salvar.

## 7. Tratamento de erros

Erros tipados: `ApiException`, `NetworkException`, `RequestTimeoutException`, `ValidationException` (400/422), `NotFoundException` (404), `ConflictException` (409) e `DependencyUnavailableException` (503). Erros 500 e respostas inesperadas recebem mensagem genérica segura. Códigos de conflito permanecem disponíveis ao controller; JSON cru, stack trace e mensagens de banco não chegam à UI.

404 de relato significa ausência do agregado e permite primeiro PUT com `expected_revision="0"`. Não é confundido com rede indisponível. Não há fallback de dados no meio da sessão.

## 8. Loading/empty/error

Componentes compartilhados `NetworkFeedback` e `RemoteDetail` oferecem carregamento e tentativa novamente, preservando o layout. Perfil, preferências, preparo, detalhe, notificações e histórico tratam latência/erro. Home e Preparo possuem estado vazio para ausência de consulta futura; Agenda e notificações preservam seus estados vazios e filtros. Formulários mostram salvamento/erro e só anunciam sucesso confirmado.

## 9. Relato e revisionamento

GET restaura original, seções, perguntas, seleção/ordem, `organization_current`, `reviewed`, `final_done`, revisões e datas. Abrir o aplicativo ou reidratar o controller não gera PUT. A revisão enviada é sempre a string retornada pelo backend; o contador privado de edições locais serve apenas para preservar digitação ocorrida durante HTTP.

Organizar continua chamando o serviço mock local. O PUT usa `intent=organize` e `organization_source_text` com o original exato. Edições enviam `intent=edit`, agregado completo e IDs existentes. Ordem é a ordem dos arrays. Respostas canônicas substituem o estado; se houve digitação durante o request, o texto novo é mantido e apenas identidades/revisão são reconciliadas para o próximo envio.

409 interrompe autosave e mantém o rascunho em memória. A tela pede recarregar a versão atual, permite consultar o rascunho preservado e restaurá-lo deliberadamente; não faz merge ou sobrescrita automática. Restaurar requer nova organização antes de concluir a revisão. Um rascunho de outra consulta não pode ser aplicado à consulta atual. **O rascunho ainda não confirmado não é salvo em disco: resolva o conflito ou copie o texto antes de fechar a aplicação.**

Review usa POST com `expected_revision` atual. Revisão final usa PUT com a revisão efetivamente revisada, mesmo que um GET posterior encontre outra versão; assim uma atualização concorrente ainda resulta em 409. O repository aceita `completed=false` para reabertura deliberada. Editar conteúdo também invalida a revisão pelo contrato do servidor. O progresso local transitório é substituído pelo overview canônico após persistir.

Remover resumo primeiro sincroniza eventuais alterações pendentes e depois executa DELETE com a revisão confirmada. Preserva original, aplica seções/perguntas vazias e a revisão retornada. Não persiste áudio/transcrição, diagnóstico, prescrição ou raciocínio de IA.

## 10. Notificações

Mock de notificações foi encapsulado em `MockNotificationRepository`; telas não importam diretamente `mock_notifications.dart`. API usa `unread_count` para badge e aguarda PATCH antes de considerar leitura persistida. Falha mantém o estado anterior. Lista pode ser recarregada independentemente do perfil. Mudanças de presença, lembrete e preferências invalidam a lista quando aplicável. Nenhuma mensagem afirma que a unidade foi avisada; não há push.

## 11. Preferências

Novo contrato `PreferencesRepository` com implementações mock/API. Notificações e acessibilidade leem/salvam o backend, usando a resposta canônica. Controles evitam escritas simultâneas pela UI, mostram salvamento e oferecem retry com rollback em falha.

São aplicados tamanho do texto, aparência, contraste, leitura, descrições, linguagem simples, haptics e redução de movimento. Voz disponível, speaking, tema efetivo, escala do sistema e capacidade do aparelho continuam locais. Preferências de avisos controlam a central interna e não criam scheduler, alarmes ou push.

## 12. Testes

Os testes novos utilizam `http/testing.dart` e fixtures sintéticas em `test/support/fake_api.dart`. Não leem `.env` nem conectam ao Aiven. Cobrem os quatro ApiRepositories, parsing, paginação, datas, IDs grandes como string, payloads permitidos, IDs recebidos, erros 400/404/409/422/500/503, cancelamento por prazo, ausência de retry de POST, respostas canônicas e relato ausente.

Controllers/widgets cobrem loading, sucesso, falha, retry, perfil, saúde, checklist, presença, lembretes, histórico, preferências, notificações, reidratação do relato, autosave, edições durante HTTP, conflitos preservados, review, finalização concorrente e remoção de resumo. Os testes anteriores da V2 continuam presentes; os pumps do relato foram adaptados à persistência assíncrona e duas expectativas de mensagem passaram a usar a confirmação neutra de salvamento.

Resultados finais: `dart format .` em 112 arquivos, sem alterações pendentes de formatação; `flutter analyze` **sem problemas**; `flutter test --dart-define=DATA_SOURCE=mock` **126 testes aprovados**, incluindo 79 testes anteriores e 47 novos. Nenhuma mutação de teste foi enviada ao Aiven. `git diff --check` passou, considerando finais de linha CRLF do Windows.

```powershell
dart format .
flutter analyze
flutter test --dart-define=DATA_SOURCE=mock
```

Essa execução inclui testes com composição API explícita e HTTP falso, além dos fluxos mock sem backend.

## 13. Build Web

```powershell
flutter build web --dart-define=DATA_SOURCE=api --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

**Build aprovado**, saída `build/web`, com composição API. Destino JavaScript. O dry run WebAssembly mantém os três avisos conhecidos de casts `JSAny` de `flutter_tts 4.2.5`; Wasm não é alvo desta fase. Nenhum IP de rede particular integra a configuração versionada.

## 14. Build Android

```powershell
flutter build apk --debug --dart-define=DATA_SOURCE=api --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

**Build aprovado**, saída `build/app/outputs/flutter-apk/app-debug.apk`. O APK desta validação usa API no emulador. Para um APK demonstrativo independente do servidor, executar o mesmo comando com `--dart-define=DATA_SOURCE=mock`, sem API_BASE_URL. HTTP claro foi habilitado somente no manifest **debug** para desenvolvimento local. A configuração release não foi flexibilizada. O build Android não apresentou novos avisos relevantes.

## 15. Smoke tests API real

FastAPI local foi iniciado em loopback, usando configuração e CA já existentes. `/health` respondeu **HTTP 200**, `{"status":"ok","database":"ok"}`. A conexão real foi reconferida: MySQL **8.4.11**, TLS **1.3**, SSLContext com `check_hostname=true`, verificação de certificado obrigatória, CA carregado e **VERIFY_IDENTITY mantido**.

Preflight CORS de PUT perfil: HTTP 200 e origem exata `http://127.0.0.1:5173`. Não foi necessário alterar `.env` ou liberar wildcard. O build Web API foi servido nessa origem, aberto no navegador e percorreu entrada demonstrativa → Home → **Perfil**. Os dados de perfil apareceram e os GET correspondentes responderam 200 no FastAPI real. Não se tratou de mock HTTP.

Antes/depois, foram comparadas contagens e hashes internos do conteúdo de **todas as 16 tabelas de negócio**, sem exportar dados para o relatório. Conteúdo e contagens ficaram idênticos. A sessão fez GET e preflight OPTIONS, sem POST/PUT/PATCH/DELETE reais. Os dois servidores temporários e a aba de teste foram encerrados; o FastAPI concluiu seu shutdown. Não foi testado aparelho iPhone ou Android físico nesta execução.

Segurança: `.env` e `ca.pem` continuam ignorados e não rastreados; `.env.example` permanece sem valores de conexão. A busca nos 287 arquivos versionáveis, no bundle Web e no conteúdo descompactado do APK não encontrou host, usuário ou senha reais do Aiven. Nenhuma credencial foi impressa ou copiada para documentação. Helpers temporários de comparação/auditoria foram mantidos fora do Git e removidos após o uso.

## 16. Procedimento de teste manual

### Persistência de perfil, com fixture fictícia

1. Iniciar backend local e Flutter no modo API pelos comandos da seção 2.
2. Entrar pelo login demonstrativo, abrir Perfil → Dados pessoais e anotar exatamente o valor fictício original de um campo permitido.
3. Editar somente esse campo, salvar e aguardar a confirmação. Em falha, não assumir persistência.
4. Fechar e abrir novamente o app **com os mesmos dart-defines**; entrar e confirmar que o valor veio persistido da API.
5. Restaurar o valor original, salvar, reabrir e conferir a restauração.

As mutações deste procedimento ficam sob execução manual; não foram feitas automaticamente sobre as fixtures Aiven. Saúde salva as duas listas juntas, portanto anotar a composição original antes de editar. Para relato, confirmar o indicador de salvamento antes de fechar; em 409, consultar o rascunho preservado e recarregar explicitamente.

### iPhone / outro aparelho na mesma rede

Terminais a partir das respectivas pastas:

```powershell
# chega_junto_backend
uv run uvicorn app.main:app --host 0.0.0.0 --port 8000
# chega_junto_app (outro terminal)
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080 --dart-define=DATA_SOURCE=api --dart-define=API_BASE_URL=http://IP_DO_PC:8000
```

Substituir `IP_DO_PC` pelo endereço IPv4 da interface usada na rede local (consultar `ipconfig`). No `.env` **local** do backend, acrescentar `http://IP_DO_PC:8080` à lista JSON de `CORS_ALLOWED_ORIGINS`, preservando as origens existentes; reiniciar o FastAPI. Abrir `http://IP_DO_PC:8080` no Safari do iPhone. Ambos os aparelhos precisam alcançar a mesma rede; VPN, isolamento Wi-Fi ou regras existentes podem impedir acesso. Nenhuma regra de firewall foi alterada automaticamente. `0.0.0.0` é endereço de escuta, não URL de navegação. Não versionar IP particular ou `.env`.

## 17. Limitações

- Backend continua local e usa o usuário demo, sem autenticação/isolamento de contas. Somente dados fictícios nesta etapa.
- Escritas reais e teste no iPhone/emulador não foram executados automaticamente; mutações são cobertas com fake HTTP e têm procedimento manual.
- Preparação continua concentrada no próximo atendimento, como na V2; outros atendimentos têm detalhe de leitura. Não foi acrescentada edição de consultas ou unidades.
- Autosave não garante persistência após encerramento abrupto, perda de rede ou conflito. Rascunho preservado existe somente em memória; aguardar confirmação.
- Não há cache offline persistente, sincronização offline, merge automático ou retry de escrita.
- Paginação é interna e carrega listas completas pequenas. Há proteção contra paginação vazia/infinita; listas muito grandes exigirão UX futura.
- Web controla o connect timeout pelo navegador; o prazo total de 90 s é aplicado pelo cliente.
- Mantidos avisos conhecidos do dry run Wasm de TTS. Login, IA e áudio continuam demonstrativos; preferências não criam entrega externa de avisos.

## 18. Próximo passo

Revisar esta integração e executar o roteiro manual com dados fictícios, inclusive Safari na rede local. Eventual publicação, autenticação ou IA real exigem autorização de uma próxima fase. Não há commit/push nesta entrega.

## 19. Fase 4 — cadastro e autenticação mínima (09/10/2026)

### Repositories e composição

AuthRepository foi ampliado mantendo signInDemo para callers V2 e implementações mock/API. ApiAuthRepository integra POST `/api/v1/auth/register`, POST `/api/v1/auth/login` e GET `/api/v1/auth/me`. Login/register são requests públicos JSON; me e demais repositories recebem Authorization Bearer automaticamente pelo ApiClient. Register envia somente full_name/email/password; confirmação é local. IDs continuam String, inclusive BIGINT máximo testado. E-mail é aparado/lowercase; senha é preservada exatamente.

Fonte escolhida uma vez no app, sem if de fonte nas features. Capacidades do repository controlam validação, Google, textos e recuperação. Os quatro ApiRepositories de produto permanecem, com MockRepository correspondente. MockAiAssistantService, MockAudioDraftService e TTS continuam locais. Nenhuma conexão direta ao MySQL ou segredo foi acrescentado ao Flutter.

### Sessão, token e isolamento

DemoSession mantém o nome histórico e passa a representar initializing/unauthenticated/authenticated, identidade mínima, loading e geração da sessão. AuthTokenStore abstrai read/write/clear; MemoryAuthTokenStore é a implementação escolhida em **Android e Web**. Não há persistência em localStorage/cookies/arquivo, senha guardada ou pacote adicional. Recarregar a página ou reiniciar exige login novamente. Após receber token de login/register, me valida a identidade canônica; falha temporária de leitura não desfaz um cadastro já confirmado, mas token inválido é rejeitado.

Toda mudança de identidade recria o escopo de produto. Logout remove token, cancela HTTP/TTS/autosave, descarta router/controllers/repositories e limpa dados/caches de perfil, histórico, saúde, notificações, agenda, lembretes, preparo, preferências, revisão e rascunho. Controllers não carregam endpoints protegidos antes da autenticação. ScopedAuthTokenStore impede pedidos antigos de emprestar o token da conta seguinte; respostas 401 antigas não encerram outra conta. Não há mistura com mocks durante falha.

401 de produto limpa sessão/estado e leva ao Login com mensagem humana. 401 de login informa e-mail/senha inválidos; 409 de e-mail é distinto do conflito de revisão do relato. 422/503/rede mantêm erros tipados e permitem retry explícito, sem JSON cru ou stack trace. Cliente preserva timeouts, cancelamento e ausência de retry automático de escrita. JWT dura 60 minutos; sem refresh/revogação. Logout é local: token copiado só perde validade pela expiração ou desativação da conta no servidor.

### Cadastro e Login

Nova rota `/cadastro`, acessível por “Criar conta” no Login e com retorno “Entrar”. AuthScaffold compartilha exatamente fotografia, fundo, marca, tipografia, bordas, espaçamentos e largura da tela aprovada. Campos: nome, e-mail, senha, confirmar senha. Validação dupla frontend/backend; 8–128 caracteres Unicode para senha, confirmação igual, campos vazios/formatos inválidos bloqueiam submit. Mostrar/ocultar senha, autofill, rolagem e teclado seguem os padrões existentes. Loading impede duplo envio; controllers de senha são limpos/destruídos após sucesso/saída. Cadastro autenticado abre Home automaticamente.

Modo API não oferece Google fictício como login real: botão desabilitado e indicação de indisponibilidade. Recuperação apenas informa que não está disponível. Modo mock continua demonstrativo e não depende de servidor, token, Aiven ou segredo de assinatura.

### Perfil incompleto e estados vazios

Adapter aceita campos null sem deslocamento de data civil ou strings “null”. PUT envia vazio como null para campos opcionais, mantendo nome/e-mail obrigatórios. SUS/IDs/timestamps continuam fora do comando. UI exibe “Não informado” e “Complete seus dados” quando necessário, sem inventar CPF, nascimento, telefone, endereço, SUS ou unidade. E-mail do perfil e login é único/canônico no backend.

Novas contas têm zero dados de produto e um par de preferências com defaults oficiais. Home não calcula consulta fictícia; agenda, saúde, histórico e notificações aceitam vazio. Sem botão de criação de atendimento novo nesta fase. Semântica do sino da Home passou a usar unread_count real; cartão de lembrete não aparece com texto vazio. Essas correções de ausência de dados não alteram cores, tipografia ou navegação.

### Testes e builds

| Verificação | Resultado |
| --- | --- |
| Backend pytest | 280 aprovados; somente warning conhecido TestClient/httpx |
| Backend Ruff / format / compileall | aprovados |
| Alembic Aiven | 20261009_0002 (head); sem operações pendentes |
| Flutter format | aplicado |
| Flutter analyze | sem problemas |
| Flutter test DATA_SOURCE=mock | 156 aprovados (126 anteriores + 30 de autenticação) |
| Flutter build web DATA_SOURCE=api / loopback | aprovado; três avisos conhecidos do dry run Wasm flutter_tts |
| Flutter build apk --debug DATA_SOURCE=api / emulador | aprovado |

Novos testes Flutter: payloads sem campos proibidos, parsing/ID String, token/header/me, modo público de login/register, password boundaries, initialization/logout, token inválido, 401/409/422/503/rede, loading/duplo toque, confirmação local, retry, descarte de resposta de login atrasada, 401 de sessão antiga, perfil incompleto, A→logout→B com controllers novos e nenhum rascunho/dado de A, responsividade 320×568/390×844/desktop, teclado e fonte até 2x. Os testes anteriores de rede/relato/conflitos/mock continuam passando. Mutações automatizadas permanecem em fake HTTP; nunca escrevem nas fixtures Aiven.

### Smoke real autorizado

Uma única conta fictícia de domínio example.test foi criada **pela tela Cadastro do Flutter Web release**, servida localmente, contra FastAPI local com AUTH_MODE=jwt e Aiven real. Fluxo conferido: cadastro → token → me → Home sem consulta → Perfil mínimo → logout → novo login → mesma identidade/perfil. Agenda sem itens, medicamentos/alergias vazios e notificações sem avisos foram conferidos. Nenhuma fixture demo foi copiada; nenhuma consulta, saúde, relato ou notificação foi criada para essa conta. Senha aleatória usada somente na validação não foi gravada em código, docs, terminal ou arquivos locais. Captura de evidência fica em `.local/qa/auth-profile-v3.png`, ignorada.

Migration nova aplicada somente após testes isolados e inspeção do destino. Aiven conservou 16 tabelas de negócio + alembic_version e todas as fixtures originais por fingerprints, incluindo e-mail movido para users. Contagens de user/perfil/duas preferências aumentaram em um; produto não aumentou. Seed reconheceu demo sem sobrescrever. Health real 200 status/database ok; perfil sem token 401. Relatório completo: [autenticação backend](../../chega_junto_backend/docs/RELATORIO_AUTENTICACAO_V3.md).

### Roteiro atual para Web/Android/iPhone

Backend (pasta chega_junto_backend, configuração preenchida somente no .env ignorado, AUTH_MODE=jwt):

```powershell
uv run uvicorn app.main:app --host 127.0.0.1 --port 8000
```

Flutter (pasta chega_junto_app):

```powershell
flutter run -d chrome --web-hostname 127.0.0.1 --web-port 5173 --dart-define=DATA_SOURCE=api --dart-define=API_BASE_URL=http://127.0.0.1:8000
flutter run -d emulator-5554 --dart-define=DATA_SOURCE=api --dart-define=API_BASE_URL=http://10.0.2.2:8000
flutter run -d chrome --dart-define=DATA_SOURCE=mock
```

Para iPhone, usar nos respectivos terminais:

```powershell
uv run uvicorn app.main:app --host 0.0.0.0 --port 8000
flutter run -d web-server --release --web-hostname 0.0.0.0 --web-port 8080 --dart-define=DATA_SOURCE=api --dart-define=API_BASE_URL=http://IP_DO_PC:8000
```

Substituir IP_DO_PC somente ao executar; autorizar `http://IP_DO_PC:8080` no CORS_ALLOWED_ORIGINS somente do .env local, preservando origens existentes e sem wildcard. Reiniciar backend. Abrir `http://IP_DO_PC:8080` no Safari da mesma rede. Não alterar firewall automaticamente. CORS permite Authorization; Android nativo não depende de CORS.

Teste manual: criar conta totalmente fictícia → verificar Home/Agenda/saúde/histórico/notificações vazios e Perfil sem dados inventados → sair pela engrenagem → entrar com mesma conta → conferir identidade. Recarregar deve pedir login. Editar um campo fictício permitido no Perfil, salvar, sair/entrar e conferir persistência; restaurar exatamente o valor original e conferir. Não editar fixtures demo nem usar dados reais. A execução do APK em aparelho físico não foi validada; build e testes de widget passaram.

### Validação manual posterior no iPhone — Fase 4

Após a geração dos relatórios anteriores, o usuário confirmou o teste do Flutter Web no Safari de um iPhone físico: conexão Flutter Web → FastAPI local → Aiven, cadastro e login reais funcionando e entrada no fluxo autenticado. No primeiro acesso, o navegador exibiu uma versão/cache antiga; após recarregar/reabrir a versão atual, o cadastro funcionou normalmente. Não foi necessária mudança funcional adicional no código. Este registro complementa a Fase 4 e não altera o histórico da Fase 3. Não foram fornecidos logs, status HTTP, tempos ou modelo do aparelho para esse teste manual; as contagens do smoke anterior referem-se àquela execução, antes desta validação posterior.

### Limitações e ponto de parada

MVP somente fictício, sem liberação para dados médicos reais/produção. Sem refresh, revogação, recuperação/verificação de e-mail, troca de senha, Google/Apple/MFA/RBAC, exclusão de conta, IA/áudio reais, upload, push ou Render. Sem cache offline/merge sofisticado. Login após restart é deliberado. A conta fictícia de validação permanece no banco; nenhuma segunda conta ou exclusão automática foi feita. Servidores temporários de validação foram encerrados ao concluir.

Não houve commit/push/tag/deploy. Revisão e aprovação do usuário são o próximo passo.

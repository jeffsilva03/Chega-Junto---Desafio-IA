# Chega Junto — Checkpoint V4: Portal Simulador

Validação local e aprovação do checkpoint V4 em 12/10/2026. **AMBIENTE DEMONSTRATIVO — SISTEMA NÃO OFICIAL.** Entrega autorizada para commit e publicação na branch `main` do GitHub, com nova tag `V4`. Sem deploy. As tags V1/V2/V3 são históricas; V3 permanece em `f7226bd4a45be38b25e159118ccc61b7a0b8f26d`.

## 1. Arquitetura implementada

```text
Flutter Android/Web ── JWT ──┐
                            ├── FastAPI → SQLAlchemy/PyMySQL → TLS → Aiven MySQL
Portal local ── Simulator ──┘
```

Dois clientes, uma fonte canônica. Namespace administrativo demonstrativo separado. Portal não acessa MySQL nem usa dados clínicos. Sem SUS, gov.br, IA real ou mensagens externas. Services controlam transações; repositories não fazem commit; schemas públicos restringem campos.

## 2. Pasta e referência visual

`chega_junto_portal/`: `index.html`, `css/portal.css`, `js/api.js`, `js/domain.js`, `js/app.js`, `assets/` (SVG e fontes licenciadas), `serve.py`, `tests/portal.test.js`, `package.json`, `README.md`. Vanilla, sem dependência de produção.

Referência principal: `Design Telas ChegaJunto/sistema web.png`, preservada como arquivo do usuário. Mantidos aviso amarelo superior, header branco, navegação azul, filtros/tabela e painel lateral de consulta. Apenas Agendamentos possui navegação funcional; módulos fora do escopo não foram inventados. Desktop priorizado; editor passa abaixo da tabela em tablet. Aviso permanente visível também em edição/visualização/cancelamento.

## 3. Endpoints adicionados

Todos sob `/api/v1/simulator`:

| Método | Caminho | Uso |
|---|---|---|
| GET | `/users/search?email=...` | Buscar identidade mínima |
| GET | `/facilities` | Carregar unidades ativas paginadas |
| GET | `/appointments` | Listar/filtrar/paginar consultas |
| POST | `/appointments` | Criar consulta + checklist |
| GET | `/appointments/{id}` | Visualizar dados de agendamento |
| PATCH | `/appointments/{id}` | Editar campos permitidos + checklist |
| POST | `/appointments/{id}/cancel` | Cancelar sem DELETE |

São 7 operações novas; base V3 de 33 operações permanece. Contrato completo: [API_CONTRACT_V4.md](../chega_junto_backend/docs/API_CONTRACT_V4.md). O contrato V3 recebeu indicação explícita da extensão.

## 4. Simulator mode e segurança

`SIMULATOR_MODE=false` por padrão. Desativado: 404 antes de banco, rotas ausentes do OpenAPI. Ativação em `APP_ENV=production` é rejeitada. Ativo exige peer de loopback, Host local, origem explicitamente autorizada se presente e header público `X-Simulator-Request: local`. Esse header força preflight no navegador; não é segredo, autenticação ou senha de operador.

Origem padrão do portal `http://127.0.0.1:5500`; CORS Flutter preservado, sem wildcard. Uvicorn deve usar `--no-proxy-headers` para não confiar em endereço encaminhado. Proibida exposição por proxy/túnel/hosting público. Ainda não autorizado para uso público. O PC local controlado é o limite de confiança desta fase; não há RBAC nem login de operador. Um processo local confiável também pode chamar a API. Autenticação JWT dos pacientes permanece independente.

Servidor do portal fixa loopback, exige `--api-base`, valida origem sem credenciais e fornece `config.json` dinâmico sem segredos; CSP, `nosniff`, `no-store` e referrer restrito. Nenhum segredo, JWT literal, host Aiven real ou IP particular foi encontrado nos arquivos versionáveis. Busca pelos valores reais de chave JWT, senha e host Aiven também não encontrou ocorrências nos builds Web e APK finais. `.env`, `ca.pem`, snapshots e instrumentação de smoke permanecem ignorados. Não foram alteradas senhas, chaves ou dados pessoais de contas existentes.

## 5. Localizar usuários

E-mail exato normalizado (trim/lowercase), sem listagem administrativa de todas as contas. Projeção SQL explícita de `id`, `full_name`, `email`, `is_active`. Busca não carrega hash, CPF, cartão SUS, endereço pessoal ou perfil clínico. Ausente retorna 404; criação exige usuário ativo. Conta usada no smoke foi a fictícia V3 `v3-auth-1791567035645@example.test`, conforme escolha do usuário; nenhum Gmail pessoal foi utilizado.

## 6. Campos de appointment

Reutilizados: `user_id`, `facility_id`, `specialty`, `professional_name`, `scheduled_at`, `timezone`, `type`, `instructions`, `title`, `attendance_status`. Unidade sempre canônica por FK, carregada de `facilities`; profissional/especialidade continuam texto. Title gerado por tipo/especialidade. Presença inicial `undecided`.

Tipos: `consultation`, `exam`, `return`. Status independente de presença: `scheduled`, `cancelled`, `completed`. Sem interface de conclusão nesta fase. Data/hora do operador em São Paulo; conversão para instante UTC antes de persistir segundo a arquitetura V3. `20/10/2026 09:30` correspondeu a `2026-10-20T12:30:00Z` no Aiven e voltou como 09:30 no app.

## 7. Checklist e transação

Tabela `appointment_checklist_items` reutilizada. Escrita `description`/`required` mapeia `title`/`is_required`; leitura mantém contrato canônico. Itens novos na seção documentos, posição ordenada, chave única e conclusão falsa. Seção de item existente é preservada.

Pai + itens + leitura do resultado são concluídos na mesma transação; falha no flush/commit/validação dá rollback integral. Zero itens é permitido e implica `documents_done=true`. Só obrigatórios contam para conclusão de documentos. Esta etapa corresponde a 25% da preparação geral, conforme as quatro etapas V3.

## 8. Edição

PATCH admite especialidade, profissional, unidade, instante, tipo, orientações e checklist. Não aceita `user_id`, title, status ou timezone. Campos omitidos são preservados; null explícito não é aceito. Checklist omitido é preservado; lista explícita substitui a composição, inclusive vazia. IDs existentes mantêm identidade/conclusão quando descrição não muda; mudança de descrição reinicia somente esse item. IDs de outra consulta, duplicados e ordens inconsistentes são protegidos transacionalmente. Somente agendadas podem ser editadas.

## 9. Cancelamento

Ação explícita com diálogo, `scheduled → cancelled`, idempotente. Consulta e relações permanecem no banco; nenhuma rota DELETE de appointment foi criada. Canceladas/concluídas são somente leitura no portal; ação Cancelar desaparece. Cancelar concluída retorna 409. Presença não é utilizada como substituta do status de cancelamento.

## 10. Integração Flutter

Sem redesenho e sem administração no app. Modelo/mapping incluem status e retorno (`followUp` em Dart). Home/Agenda usam botão **Atualizar atendimentos**, recarregando overview, consultas e lembretes pela API e invalidando cache de detalhes. Sem polling, WebSocket ou fixture correspondente ao agendamento do portal.

Home sai do estado vazio quando chega a primeira consulta. Agenda mantém ordenação e rotula canceladas/concluídas; detalhes não oferecem preparo ativo para canceladas. Próxima consulta no backend só considera agendadas. Checklist usa os itens persistidos e a regra obrigatória existente. Foram protegidos acessos a `first`/`last` de orientações vazias em Agenda de exames e Checklist, sem inventar texto ausente. As orientações completas permanecem nos Detalhes; Checklist conserva a apresentação V3 da última orientação.

## 11. Migration

Nova revisão `20261012_0003`, após `20261009_0002`. A V3 não possuía status de ciclo de vida de appointment: `attendance_status` registra presença, não cancelamento. Além disso, o CHECK de `type` admitia apenas consulta/exame. A migration foi necessária para cancelar sem apagar a consulta e representar retorno sem sobrecarregar campos de significado diferente.

Alterações exclusivamente em `appointments`: adiciona `status VARCHAR(20)` com collation `utf8mb4_bin`, NOT NULL e default de servidor `scheduled` (inclusive para consultas legadas); cria `ck_appointments_status_values` com `scheduled`, `cancelled`, `completed`; substitui `ck_appointments_type_values` para admitir `consultation`, `exam`, `return`. Não altera FKs, checklist ou relações e não cria tabela. As revisions 0001/0002 foram preservadas integralmente. O downgrade defensivo recusa perda de status/tipo em uso; não foi executado no Aiven.

Aplicada no Aiven autorizado: `alembic current` confirmou `20261012_0003 (head)` e `alembic check` informou ausência de novas operações. MySQL DDL também validado offline. Não houve reset, seed ou recriação de banco.

## 12. Testes backend

**325 aprovados** (280 anteriores + 45 casos do simulador, incluindo parametrizações). Cobrem modo desabilitado/produção, controles locais/CORS antes de DB, busca mínima/normalização/ausência, usuário/unidade inválidos/inativos, datas e limites, criação com/sem checklist, rollback de filhos/commit, edição e reordenação, titular imutável, IDs alheios, cancelamento/idempotência, paginação/filtros, isolamento e superfícies clínicas ausentes.

E2E obrigatório isolado: cadastra A, confirma zero consultas, cria pelo simulator, autentica A, consulta APP API/overview/checklist, conclui item obrigatório/opcional e cancela pelo simulator, confirmando status e ausência de próxima ativa. SQLite efêmero nos testes, sem credenciais/Aiven, com FKs e restrições; migration/DDL MySQL são verificados separadamente. Warning conhecido de depreciação TestClient/httpx, sem falhas.

```powershell
cd chega_junto_backend
uv run pytest -q
uv run ruff check app scripts migrations tests
uv run ruff format --check app scripts migrations tests
uv run python -m compileall -q app scripts migrations
uv run alembic current
uv run alembic check
```

## 13. Testes e builds Flutter

**162 aprovados** (156 anteriores + 6 novos). Incluem mapping/status/retorno, cache de detalhe, Home vazia → primeira consulta → cancelamento, Agenda/Detalhes cancelados e exame sem orientações/checklist. `dart format .` e `flutter analyze` concluídos sem problemas.

```powershell
cd chega_junto_app
dart format .
flutter analyze
flutter test --dart-define=DATA_SOURCE=mock
flutter build web --dart-define=DATA_SOURCE=api --dart-define=API_BASE_URL=http://127.0.0.1:8000
flutter build apk --debug --dart-define=DATA_SOURCE=api --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

Builds Web/API e APK debug/API gerados. Build Web em JavaScript apresenta avisos já conhecidos do dry-run Wasm de TTS; compilação JavaScript não falha e Wasm não faz parte desta entrega.

## 14. Validação portal

**18 testes Node aprovados**, sem framework/install. Cobrem chamadas HTTP/métodos, cancelamento sem DELETE, parsing, timezone atual/histórico DST, filtros, IDs string, submit/PATCH sem titular, erros sanitizados, resultado incerto sem retry e loading/finally. `node --check js/app.js` aprovado.

Navegador: busca/criação/edição/visualização/cancelamento reais, mensagens de sucesso, retorno de dados persistidos, console sem erros/warnings no fluxo concluído. Validação visual desktop 1440 e tablet 1024: navegação/formulário/tabela legíveis, editor lateral ou abaixo conforme breakpoint, sem overflow horizontal da página. Tabela possui contêiner de rolagem quando necessário. HTML semântico, labels, foco visível, aria-busy/status e diálogo com teclado. Não é auditoria formal WCAG ou teste de todos os navegadores.

## 15. Smoke real Portal → FastAPI → Aiven → Flutter

Após reativação do serviço Aiven pelo usuário, TLS voltou e a migração foi aplicada. Houve falhas transitórias de leitura durante a retomada inicial; UI ofereceu atualização e a execução seguinte concluiu. Nenhuma escrita foi repetida automaticamente.

Conta fictícia V3 (id 2) tinha zero appointments. Portal buscou essa conta e criou **uma** consulta (id 4): Clínica Geral, Dra. Ana Teste, UBS Centro existente, 20/10/2026 09:30, antecedência de 20 minutos, Documento com foto obrigatório e Cartão SUS opcional. Edição acrescentou orientação de demonstração acadêmica. Home/Agenda exibiram a consulta; Detalhes exibiram profissional, unidade, data/hora, orientações e documentos. Checklist marcou opcional mantendo 0%; obrigatório elevou checklist para 100% e preparo geral para 25%.

Portal cancelou a mesma consulta. Aiven manteve appointment e dois itens, ambos concluídos pelo app; Home voltou a não ter próximo atendimento e Agenda conservou a consulta com **Cancelada**. Estado final do smoke é cancelado, intencionalmente preservado para auditoria.

A senha aleatória da conta fictícia V3 não estava disponível. Para a etapa visual Flutter, foi utilizada instrumentação temporária ignorada pelo Git: sessão JWT de teste com expiração de 5 minutos emitida pelo backend local, recebida apenas em memória do app via helper loopback. `ApiAuthRepository.me()` validou a identidade real; telas e repositories consumiram API/Aiven reais. Não houve alteração de senha, endpoint de bootstrap no produto ou token embutido no bundle versionável. Esse smoke visual **não repetiu login por senha** dessa conta; cadastro/login normais estão cobertos pelo E2E automatizado e pela base V3. Builds normais foram produzidos com `lib/main.dart`, sem helper. Servidores/helpers de QA encerrados ao final.

Integridade durante esse smoke: fingerprints de cada registro anterior das 16 tabelas de negócio, excluindo apenas a nova coluna status para comparação, não encontraram alterações nem remoções. Acréscimos exclusivamente **1 appointment + 2 checklist items** nessa execução. Dados clínicos, contas, hashes, preferências, notificações e fixtures anteriores preservados. Snapshot interno ignorado, sem conteúdo clínico em documentação/logs públicos. Essa contagem histórica não descreve dados acrescentados posteriormente pelo teste manual do usuário.

Capturas locais ignoradas em `chega_junto_portal/.local/qa/`: portal desktop, consulta cancelada, Home, Checklist e Agenda cancelada. Não são assets do produto.

### Validação manual final informada pelo usuário

Após o relatório inicial, o usuário confirmou funcionamento integral do ambiente: Portal Web, FastAPI e Flutter Web iniciaram corretamente, o acesso para teste pela rede local funcionou e o fluxo Portal → FastAPI → Aiven → Flutter foi validado. Criação, edição e cancelamento foram confirmados manualmente; Home, Agenda, Detalhes e Preparo refletiram os dados persistidos, e a consulta cancelada deixou de ser a próxima ativa.

Portas usadas no desenvolvimento local: **8000** (FastAPI), **8080** (Flutter Web) e **5500** (Portal). O firewall do Windows precisou permitir as portas de desenvolvimento na rede privada. Após configuração persistente local, o usuário informou que o ambiente funcionou normalmente. A regra é configuração da máquina exclusivamente para desenvolvimento, não requisito de produção. Nenhum comando de firewall, regra pessoal, IP real ou credencial integra esta entrega; exemplos usam `IP_DO_PC`.

O acesso do aplicativo pela rede local não altera a proteção administrativa: a configuração versionada do servidor do portal e dos endpoints simulator permanece restrita ao PC/loopback. O celular consome a APP API com JWT. A validação manual não autoriza exposição pública do portal ou do simulador.

## 16. Limitações

Simulador restrito ao PC, sem autenticação de operador; não deve ser publicado. Checklist/preparo seguem a próxima consulta na UX V3; não foi criado novo fluxo para preparar qualquer consulta futura. Sem profissionais reais, cadastro de unidade, prontuário, diagnóstico, APIs SUS, scheduler, push, upload ou IA real. Sem botão de concluir consulta ou reativar cancelada. Concorrência pesada e carga MySQL não foram ensaiadas. Testes SQLite não substituem validação de carga/concorrência em MySQL; o smoke validou persistência e transação no serviço real.

APK foi compilado; não foi repetida toda a jornada em dispositivo físico/Android Emulator nesta fase. iPhone Web tem comandos documentados, sem ensaio físico Safari. Mobile do portal não é prioridade. Confirmação e relato de uma consulta cancelada permanecem preservados; nenhuma destruição de dados clínicos foi introduzida.

## 17. Execução local

Comandos exatos, configuração, terminais separados, encerramento, CORS e variantes Backend/Portal/Flutter Web/Android Emulator/iPhone Web estão no [README do portal](../chega_junto_portal/README.md#executar-localmente). IPs particulares foram substituídos por `IP_DO_PC`; `10.0.2.2` é exclusivamente o alias do emulador. Segredos pertencem somente ao `.env` backend ignorado. Não é necessário instalar dependências npm.

## 18. Arquivos e documentação

Criados: portal completo; schemas/repository/service/router de simulator; migration `20261012_0003_simulator.py`; `tests/test_simulator.py`; `test/simulator_integration_test.dart`; contrato V4; este relatório.

Atualizados: configuração/middleware/backend models/schemas/repository de próxima consulta, seed para reconhecer o novo head (não executado no Aiven), testes de ambiente/migrations, modelos/mapping/controller/widgets/telas Flutter e testes de integração visual, `.env.example`, README raiz/backend e indicação no contrato V3.

Checkpoint V4 autorizado para GitHub em um único commit na `main` e tag anotada `V4`. V1/V2/V3 preservadas, sem reescrita de histórico ou deploy. Nenhuma funcionalidade nova foi acrescentada durante a preparação do checkpoint; apenas documentação final e revalidação.

## Ajuste visual solicitado em 12/10/2026

Após o usuário confirmar o funcionamento no teste manual, a apresentação do portal foi ajustada à imagem `Design Telas ChegaJunto/sistema web.png`: proporções de cabeçalho/barra lateral/editor, cores, cartões, filtros, ícones SVG locais, ações em linha, paginação e toast de feedback. Nenhuma alteração adicional no backend, Flutter ou esquema do banco foi necessária.

Os dados continuam vindo da API. Especialidade/profissional são texto com sugestões da página atual; checklist mantém descrição e obrigatoriedade, sem campos fictícios de subtítulo. O contador exibe o limite real da API. Atalhos de módulos fora do escopo, sino e Sair são explicitamente desabilitados. Filtros agora são aplicados ao alterar os campos, com debounce de 400 ms para texto e suporte a Enter.

Roboto regular/negrito e a licença Apache 2.0 foram incluídos localmente a partir das fontes Material do SDK Flutter instalado, sem CDN ou download em runtime.

Revalidação: 18 testes Node, sintaxe JavaScript, desktop 1505 px e tablet 1024 px, busca, filtros, formulário, inclusão/remoção de itens em rascunho, visualização de cancelada em somente leitura, abertura de edição e diálogo de cancelamento com retorno sem confirmar. Nenhuma nova escrita no Aiven para esta revisão visual. Backend, portal e Flutter Web permanecem em execução local para os testes manuais solicitados.

## Revalidação para publicação do checkpoint V4

Executados novamente após aprovação: **325 testes backend, 162 Flutter e 18 portal**, todos aprovados. Ruff check/format e compileall aprovados; `dart format .` sem alterações e `flutter analyze` sem problemas. Builds Web em modo API (JavaScript) e APK debug em modo API aprovados. Permanecem somente o warning conhecido TestClient/httpx e os três avisos conhecidos do dry run Wasm do `flutter_tts`.

`alembic current`: `20261012_0003 (head)`; `alembic check`: `No new upgrade operations detected.` Migrations 0001/0002 sem alterações. Auditoria dos arquivos versionáveis, incluindo confronto com valores reais da configuração local sem imprimi-los, não encontrou credenciais, tokens reais, hashes completos, host Aiven ou IP pessoal. `.env`, `ca.pem`, `.local/`, builds, caches, logs e capturas QA continuam ignorados. O arquivo visual aprovado e as fontes com sua licença são assets intencionais; capturas de execução não entram no checkpoint.

O portal abriu com HTML/CSS/JS e configuração dinâmica disponíveis; console sem erros críticos. O smoke real documentado foi revisado sem repetir mutações no banco. Esta preparação do checkpoint alterou somente documentação e não implementou funcionalidade, migração, autenticação ou design novos.

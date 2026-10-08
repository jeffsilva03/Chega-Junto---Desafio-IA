# Relatório de implementação — Perfil e acessibilidade

**Projeto:** Chega Junto · MVP Flutter

**Data:** 8 de outubro de 2026

**Etapa:** novos destinos de Perfil e recursos de acessibilidade

**Situação inicial deste relatório:** implementação concluída, então aguardando revisão. O bloco foi posteriormente aprovado estruturalmente; veja o checkpoint ao final deste documento e o relatório de status atualizado.

Este relatório registra o trabalho realizado no último bloco. Complementa o relatório anterior de status; não o substitui. Os resultados de validação abaixo correspondem às execuções realizadas durante a implementação, sem representar uma nova rodada de testes na geração deste documento.

## Entrega realizada

Foram implementadas oito telas a partir dos protótipos fornecidos em `Design Telas ChegaJunto/`. Todas mantêm a navegação inferior oficial: **Início | Agenda | Preparo | Perfil**.

| Tela | Funcionalidades entregues |
| --- | --- |
| Dados pessoais | Consulta e edição de identificação, telefone, e-mail, endereço e contato de emergência na mesma página. Validação de preenchimento e formato, salvamento explícito e mensagens de erro. |
| Medicamentos e alergias | Listas reunidas na mesma página, contadores e inclusão, edição e remoção de registros. Alterações ficam em rascunho até salvar. |
| Histórico de saúde | Registros fictícios ordenados por data e filtros de consultas, exames, medicamentos, alergias e diagnósticos. Cada item abre seus próprios detalhes. |
| Detalhes do histórico | Data, local, profissional quando aplicável, motivo, resumo, anotações e documentos demonstrativos associados ao registro selecionado. |
| Notificações | Agrupamento por data, filtros com contadores, diferenciação de avisos não lidos, marcação de leitura e navegação para o atendimento ou registro relacionado. |
| Configurações de notificações | Chave geral, categorias de avisos e opção de exibição no aplicativo. Preferências alteram imediatamente a lista local. |
| Acessibilidade | Tamanho do texto, tema claro/escuro/do aparelho, alto contraste, leitura em voz alta, descrições de imagens, linguagem simples, feedback tátil e redução de animações. |
| Ajuda | Busca por tópicos, respostas locais, tutoriais textuais, perguntas frequentes e informações sobre o suporte demonstrativo. |

O Perfil foi conectado a esses destinos. A engrenagem também permite acessar as configurações de notificações, além de sair da demonstração.

## Comportamento dos dados

Os dados continuam fictícios e locais, com referência de demonstração em **7 de outubro de 2026**. A próxima consulta permanece em **9 de outubro de 2026, às 08:00**, de Clínica geral, com a Dra. Ana Beatriz Souza, na UBS Centro.

O histórico contém eventos passados de 1 a 6 de outubro de 2026. O registro de atendimento em 6 de outubro e a consulta futura de 9 de outubro são eventos distintos.

O estado é compartilhado entre as telas:

- Salvar o nome em Dados pessoais atualiza o Perfil e a saudação da Home.
- Medicamentos e alergias salvos continuam disponíveis ao sair e retornar à página.
- Notificações reutilizam os atendimentos, lembretes e resposta de presença da sessão.
- Preferências e avisos lidos atualizam a central de notificações e o indicador da Home.
- As preferências de acessibilidade acompanham a navegação pelo aplicativo.

Dados pessoais e medicamentos/alergias utilizam salvamento explícito. Sair sem salvar descarta o rascunho. As validações conferem preenchimento e formato; não consultam cadastros externos nem validam a identidade do usuário.

**A persistência permanece em memória:** reiniciar o aplicativo ou recarregar a página restaura os mocks e as preferências iniciais.

## Acessibilidade funcional

Conforme a decisão oficial recebida nesta etapa, tema escuro, contraste e leitura em voz alta foram implementados com comportamento real.

### Aparência e legibilidade

- Tema claro, escuro ou conforme a preferência do sistema.
- Paleta semântica compartilhada entre telas novas e anteriores.
- Alto contraste com mudanças de cores de texto, bordas e ações.
- Testes de contraste para texto principal e secundário, com razão mínima de 7:1 nas superfícies verificadas; botões verificados com mínimo de 4,5:1.
- Tamanho de texto configurável, multiplicando a escala de acessibilidade do sistema.
- Redução de animações nas transições de navegação e nos controles compartilhados.
- Ajuste da aparência das barras do sistema no Android conforme o tema.

Essas verificações não equivalem a uma certificação completa de acessibilidade do aplicativo.

### Leitura em voz alta

- Controle de **Ouvir esta tela / Parar leitura** disponível quando a preferência está habilitada.
- Leitura dos textos da rota ativa, com descrições de imagens quando habilitadas.
- Interrupção da leitura ao navegar para outra rota.
- Android: utilização do mecanismo de voz instalado no aparelho, por meio de `flutter_tts`.
- Web: utilização da Web Speech API, com interoperabilidade Dart/JavaScript.
- Seleção apenas de vozes locais em português, com preferência por português brasileiro.
- Mensagem de indisponibilidade quando não existe uma voz local compatível.

Não foi integrada API paga de áudio nem serviço remoto como alternativa. O acionamento e a interrupção da leitura foram conferidos no navegador. A implementação Android foi verificada por teste do canal nativo com respostas simuladas; não foi feita uma validação manual completa de reprodução de áudio no emulador.

### Semântica e outras preferências

Os interruptores receberam rótulos com nome e descrição. O botão de áudio possui um nó semântico próprio, separado dos demais controles da tela. Esses ajustes foram conferidos na árvore de acessibilidade da Web.

A opção de descrições inclui a identificação das imagens na leitura. Linguagem simples ajusta explicações de Histórico e Ajuda. Feedback tátil utiliza a API do sistema em aparelhos compatíveis.

## Arquitetura e componentes

A arquitetura existente foi estendida, mantendo a separação entre apresentação, modelos, estado e contratos de repositório.

| Área | Principais arquivos |
| --- | --- |
| Rotas e aplicação | `lib/app/router/app_routes.dart`, `lib/app/router/app_router.dart`, `lib/app/app.dart` |
| Tema compartilhado | `lib/app/theme/app_tokens.dart`, `lib/app/theme/app_theme.dart` |
| Estado do Perfil | `lib/core/state/profile_controller.dart` |
| Estado e serviço de voz | `lib/core/state/speech_controller.dart`, `lib/core/services/speech_engine.dart`, `device_speech.dart`, `browser_speech.dart` |
| Componentes reutilizáveis | `lib/features/profile/presentation/widgets/profile_components.dart`, `lib/core/widgets/app_reading_tools.dart`, `medication_icon.dart` |
| Modelos | `lib/data/models/user_profile.dart`, `health_record.dart`, `app_notification.dart`, `profile_preferences.dart` |
| Contrato e mocks | `lib/data/repositories/profile_repository.dart`, `lib/data/mock/mock_profile_repository.dart`, `mock_notifications.dart` |
| Páginas | `lib/features/profile/presentation/pages/` e `lib/features/notifications/presentation/pages/` |
| Testes | `test/profile_features_test.dart`, `test/profile_state_test.dart` e ajustes em `test/widget_test.dart` |

O `ProfileController` concentra dados, preferências e leitura de avisos. O contrato `ProfileRepository` permite substituir os mocks por uma implementação de API futuramente. A leitura depende de `SpeechEngine`, permitindo implementações por plataforma e substituição nos testes.

Foram reutilizados superfícies, botões, ícones e navegação existentes. As telas anteriores receberam adaptação para os tokens de tema, mantendo a direção visual clara aprovada. Não foi adicionada biblioteca de gerenciamento de estado ou banco de dados.

## Dependência adicionada e custo

Foi adicionada uma dependência de execução: **`flutter_tts 4.2.5`**, de licença MIT, para acessar o mecanismo de voz nativo do Android. Referência: <https://pub.dev/packages/flutter_tts>.

O `go_router` já fazia parte do projeto. Nenhuma infraestrutura cloud, assinatura, API paga ou integração externa de saúde foi adicionada.

## Validação realizada

| Verificação | Resultado |
| --- | --- |
| `dart format .` | Concluído. |
| `flutter analyze` | Sem problemas encontrados. |
| `flutter test` | **39 testes passaram.** |
| `flutter build web` | Compilação JavaScript concluída. |
| Validação Web interativa | Navegação e controles conferidos, incluindo tema escuro, alto contraste, rótulos semânticos e ouvir/parar leitura local. |
| APK de debug | Compilado com sucesso. |
| Execução Android | APK instalado e iniciado no Emulador Android 16 / API 36. |

Os testes incluem formulários, edição de registros, falhas de repositório, consistência entre telas, filtros, preferências, seleção de voz local e leitura com mecanismo substituído em teste.

As novas telas foram verificadas por testes de widgets em:

- **320 × 568**, com escala de texto **1,5**.
- **390 × 844**, com escala de texto **1,0**.
- **1366 × 900**, com escala de texto **1,0**.

Também foram verificados tema escuro e alto contraste nas telas novas e anteriores, além de diálogo com teclado em tela pequena. As execuções passaram sem overflow detectado pelos testes.

### Estado da toolchain e avisos

O ambiente utilizado possui Flutter **3.41.4** e Dart **3.11.1**. O `flutter doctor` identificou:

- Flutter e Chrome disponíveis.
- Algumas licenças Android ainda não aceitas.
- Instalação incompleta de Visual Studio, utilizado para Windows desktop, que está fora do escopo atual.

Esses pontos não impediram a compilação e a inicialização do aplicativo no emulador Android nesta máquina.

O build Web concluiu com avisos sobre compatibilidade WebAssembly no código Web do plugin `flutter_tts` e uma referência interna à família de ícones `CupertinoIcons` ausente. A versão JavaScript e os ícones Material utilizados nas telas foram conferidos. **Wasm não foi validado como alvo desta entrega.**

A inicialização no emulador não representa teste manual completo de todas as telas ou medição de desempenho em aparelho físico.

## Limites do MVP preservados

- Sem backend, banco remoto ou autenticação real.
- Sem integração real com SUS, unidades ou profissionais.
- Sem cancelamento, remarcação ou envio de informações a serviços de saúde.
- Notificações e lembretes são locais à sessão; não geram push, SMS, e-mail ou alarmes do sistema.
- Documentos do histórico são prévias textuais demonstrativas, sem importação de arquivos clínicos.
- Medicamentos e doses exibidos são exemplos fictícios da referência, não prescrições ou sugestões do aplicativo.
- O aplicativo não interpreta exames, gera diagnóstico ou define condutas clínicas.
- Ajuda não envia mensagens para uma equipe de suporte.
- Relato pré-consulta e fluxo de IA continuam em rotas técnicas temporárias, aguardando implementação autorizada.
- Detalhes próprios do Cartão SUS continuam aguardando protótipo.

## Documentação, referências e versionamento

Foram atualizados `README.md` e `docs/IMPLEMENTATION_DECISIONS.md` dentro do aplicativo. As capturas de validação ficam em `.local/qa/`, fora do versionamento; a captura final da Web está em `.local/qa/accessibility-web-final.jpg`.

Nesta etapa, não foram editadas as pastas de contexto oficial, protótipos ou Landing Page. As alterações de referência já fornecidas pelo usuário foram preservadas.

As mudanças deste bloco permanecem locais, sem novo commit ou push realizado nesta etapa. A tag **V1** anteriormente publicada não foi alterada.

Na entrega inicial, o próximo passo era a revisão visual e funcional pelo usuário.

## Atualização — checkpoint após aprovação estrutural

O usuário aprovou estruturalmente o bloco de Perfil, Notificações, Acessibilidade e Ajuda e solicitou revisão final e versionamento. Foram feitas apenas correções pontuais, preservando a direção visual e a arquitetura.

- Diagnósticos do Histórico foram identificados explicitamente como informações históricas já registradas, sem geração pelo Chega Junto ou pela IA.
- A revisão de layouts incluiu escala efetiva de texto 2,1 em 320×568 e os quatro modos de aparência: claro e escuro, com e sem alto contraste.
- Foram verificados a ordem do menu oficial e o acesso a Início, Agenda, Preparo e Perfil a partir de todos os novos destinos.
- A fonte CupertinoIcons ausente foi investigada no artefato compilado. A declaração do pacote oficial `cupertino_icons 1.0.9` (MIT) corrigiu o aviso; o tree shaking reduziu essa fonte a 1.472 bytes no build Web.
- Foram executados novamente `dart format .`, `flutter analyze`, `flutter test`, `flutter build web` e `flutter build apk --debug`: todos concluíram com sucesso. A suíte atual contém **42 testes aprovados**.
- Permanecem os avisos do dry run de WebAssembly do `flutter_tts` e os avisos informativos de versões mais recentes de dependências fora das restrições atuais. Não foram feitas atualizações amplas de packages.
- Windows desktop e o fluxo de relato/IA não foram implementados nesta revisão.

O checkpoint é versionado na branch `main` com a mensagem `feat: perfil notificacoes e acessibilidade`, preservando a tag `V1`. O identificador do commit pode ser consultado no histórico Git. O documento `RELATORIO_STATUS_2026-10-08.md` reúne o estado atualizado do projeto.

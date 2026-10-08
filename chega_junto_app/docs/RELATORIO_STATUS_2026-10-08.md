# Relatório de status — Chega Junto

**Data:** 8 de outubro de 2026.

**Marco:** checkpoint após aprovação estrutural de Perfil, Notificações, Acessibilidade e Ajuda.

**Plataformas:** Android como principal; Flutter Web como complementar.

## 1. Situação geral

O frontend possui **16 telas implementadas** e o card Novo Lembrete. O bloco de Perfil foi aprovado estruturalmente e passou por revisão final, sem redesenho ou refatoração ampla. A jornada de relato/IA continua pendente e não foi iniciada neste checkpoint.

A V1 permanece como marco inicial já publicado. Este checkpoint reúne a implementação posterior de Perfil, seus destinos, notificações e acessibilidade, além da documentação e dos protótipos adicionados pelo usuário.

## 2. Telas e funcionalidades disponíveis

| Tela ou componente | Comportamento atual |
| --- | --- |
| Splash / boas-vindas | Uma página baseada no protótipo, com três indicadores decorativos e Começar direcionando ao Login. |
| Login | Acesso demonstrativo, validação local, Google simulado e recuperação sem envio de e-mail. |
| Home | Próximo atendimento, progresso de quatro macroetapas, acessos rápidos, lembrete e indicador de notificações conectado ao estado da sessão. |
| Agenda | Busca, filtros, agrupamento cronológico, três atendimentos fictícios e lembretes locais. |
| Detalhes da consulta | Dados do atendimento, unidade, profissional, orientações, mapa ilustrativo, preparo e confirmação. |
| Checklist | Itens obrigatórios e opcionais, progresso próprio e atualização compartilhada. |
| Confirmação de presença | Três respostas, salvamento na sessão e orientações para procurar a unidade. |
| Perfil | Identificação fictícia, cartão SUS ilustrativo, atalhos funcionais e saída pela engrenagem. |
| Dados pessoais | Edição de identificação, endereço e contato de emergência na mesma página, validação e salvamento explícito. |
| Medicamentos e alergias | Inclusão, edição e remoção; rascunhos salvos somente mediante ação do usuário. |
| Histórico de saúde | Ordenação por data e filtros de registros anteriores, incluindo diagnósticos já registrados. |
| Detalhes do histórico | Informações do registro selecionado, anotações e prévias textuais de documentos demonstrativos. |
| Notificações | Agrupamento por data, filtros, contadores, leitura e acesso aos dados relacionados. |
| Configurações de notificações | Preferência geral, categorias e exibição no aplicativo, aplicadas à central local. |
| Acessibilidade | Tamanho de texto, tema claro/escuro/sistema, alto contraste, voz local, descrições, linguagem simples, feedback tátil e redução de animações. |
| Ajuda | Busca, tópicos, tutoriais textuais, perguntas frequentes e suporte demonstrativo. |
| Card Novo Lembrete | Título editável, três antecipações relativas à próxima consulta, cancelar e salvar na sessão. |

Splash e Login preservam a direção visual aprovada. Todas as telas internas utilizam **Início | Agenda | Preparo | Perfil**. Preparo abre o checklist do próximo atendimento.

## 3. Consistência e persistência

Home, Agenda, Detalhes, Checklist e Confirmação compartilham o mesmo atendimento. Salvar o nome em Dados pessoais atualiza Perfil e Home. Notificações reutilizam atendimentos e lembretes, refletem a resposta de presença e respeitam as preferências e o estado de leitura da sessão.

A data de referência dos mocks é fixa em **7 de outubro de 2026**. A próxima consulta ocorre em **9 de outubro, às 08:00**, de Clínica geral, com **Dra. Ana Beatriz Souza**, na **UBS Centro**. O histórico contém eventos passados de 1 a 6 de outubro; não apresenta a consulta futura como atendimento já realizado.

Os dados são fictícios. Alterações de cadastro, medicamentos, alergias, checklist, presença, lembretes, avisos lidos e preferências ficam **em memória**. Reiniciar o aplicativo ou recarregar a Web restaura os mocks. Sair de um formulário sem salvar descarta seu rascunho.

## 4. Preparação e limites de saúde

O progresso geral utiliza quatro macroetapas: Documentos e preparo, Confirmação de presença, Relato pré-consulta e Revisão final. O mock começa com três etapas concluídas (**75%**); esse número representa a preparação fictícia do usuário, não a conclusão do desenvolvimento. O fluxo visual do relato ainda não foi implementado.

O checklist calcula progresso somente pelos itens obrigatórios. No início, os dois documentos obrigatórios estão marcados, resultando em 100% no checklist e 75% no preparo geral. A regra vigente conclui presença somente em Vou comparecer; outras respostas deixam a etapa pendente e não cancelam ou remarcam o atendimento.

Em Histórico, diagnóstico significa **informação histórica já registrada**. O filtro e os rótulos explicitam essa origem, e o detalhe informa que o Chega Junto e a IA não produzem diagnósticos nem definem condutas. Não há interpretação de exames ou prescrição pelo aplicativo.

## 5. Acessibilidade e arquitetura

Tema escuro e alto contraste são funcionais e utilizam tokens compartilhados com as telas anteriores. O tamanho de texto respeita e multiplica a escala do sistema. A redução de animações afeta transições e controles compartilhados. Interruptores possuem rótulos semânticos; o controle de áudio possui seu próprio nó de acessibilidade.

A leitura usa voz **local em português**: mecanismo Android via flutter_tts e Web Speech API na Web. O usuário pode ouvir/parar e a leitura é interrompida ao navegar. Sem voz compatível instalada, o aplicativo informa a indisponibilidade. Não há fallback para API remota. O acionamento e a interrupção foram conferidos no navegador durante a implementação; reprodução nativa não teve validação manual completa no emulador.

A arquitetura continua organizada em `app/`, `core/`, `data/` e `features/`. `PreparationController` e `ProfileController` mantêm estado com ChangeNotifier; contratos de repositório permitem futura troca dos mocks por APIs. `SpeechEngine` separa voz por plataforma e permite substituição nos testes.

Dependências de execução externas:

- `go_router 17.5.0`: navegação e URLs.
- `flutter_tts 4.2.5`: mecanismo de voz nativo, licença MIT.
- `cupertino_icons 1.0.9`: fonte referenciada internamente pelo SDK, licença MIT.

A fonte Cupertino foi adicionada após investigação do aviso de build, sem alterar o design. O tree shaking reduziu o asset de 257.628 para **1.472 bytes** no build Web. Nenhum serviço pago, cloud, biblioteca de estado ou banco de dados foi adicionado.

## 6. Revisão final e validação do checkpoint

Foram revisados overflow, textos, espaçamentos, navegação, retorno visual das ações e os quatro modos de aparência: claro e escuro, cada um com e sem alto contraste. Foram conferidas capturas das oito novas telas e formulários com rolagem. Não foram encontrados problemas que exigissem redesenho.

| Comando solicitado | Resultado nesta revisão |
| --- | --- |
| `dart format .` | Concluído. |
| `flutter analyze` | Sem problemas. |
| `flutter test` | **42 testes aprovados**, também executados com capturas locais habilitadas. |
| `flutter build web` | Concluído em JavaScript; aviso CupertinoIcons corrigido. |
| `flutter build apk --debug` | APK de debug gerado com sucesso. |

Os testes cobrem edição, validação, retorno visual ao salvar, filtros, falhas de repositório, consistência, voz local, diagnóstico histórico e navegação pelos quatro destinos oficiais a partir de todas as oito novas telas.

Layouts verificados: **320×568**, com escalas efetivas de texto **1,5 e 2,1**; **390×844** e **1366×900**, com escala 1,0. Claro/escuro e alto contraste foram percorridos nas telas novas e anteriores. A revisão não substitui uma auditoria completa de acessibilidade, teste manual em aparelhos físicos ou medição de desempenho.

Na implementação anterior, o APK foi instalado e iniciado no Emulador Android 16/API 36, e a Web foi conferida interativamente. No checkpoint, foram repetidos os comandos de análise, testes e builds acima; a execução manual completa no Android não foi repetida.

### Avisos que permanecem

- O dry run do build Web aponta três incompatibilidades de tipos JS/Dart no código Web de `flutter_tts 4.2.5` para **WebAssembly**. A compilação JavaScript concluiu; Wasm não foi priorizado nem recebeu trabalho de suporte neste checkpoint.
- A resolução de dependências informa dez packages com versões mais recentes fora das restrições atuais. Foram preservadas as versões compatíveis com o projeto, sem atualização ampla.
- O último `flutter doctor` ainda aponta licenças Android pendentes e Visual Studio incompleto. Essas pendências não impediram os builds. **Windows desktop está fora do escopo e não foi corrigido ou implementado.**

## 7. Escopo que permanece pendente

Relato pré-consulta, gravação/transcrição, organização por IA, perguntas sugeridas, revisão/edição/exclusão do relato e preparação para compartilhar continuam aguardando implementação autorizada. Relato e revisão possuem apenas rotas técnicas temporárias. Detalhes próprios do Cartão SUS aguardam protótipo.

Não há backend, banco remoto, persistência durável, autenticação real, integração com SUS/profissionais, importação clínica ou mensagens a suporte. Lembretes e notificações não programam alarmes, push, SMS ou e-mails. Salvar presença não comunica a unidade, cancela ou remarca consultas.

A leitura em voz alta de acessibilidade não equivale à gravação/transcrição do relato, ainda pendente.

## 8. Documentação, referências e versionamento

Repositório: https://github.com/jeffsilva03/Chega-Junto---Desafio-IA

Branch do checkpoint: **main**.

Mensagem: **feat: perfil notificacoes e acessibilidade**.

A tag anotada **V1** e seu commit inicial **05cb43e** permanecem preservados. O identificador do checkpoint fica disponível no histórico Git, evitando autorreferência do hash no próprio commit. A versão técnica do pubspec permanece `0.1.0+1`.

O checkpoint inclui código, testes, README, decisões, relatórios e os protótipos novos/substituídos fornecidos pelo usuário. As pastas de contexto oficial e Landing Page não foram modificadas. Os arquivos de design foram preservados conforme recebidos; não foram redesenhados ou editados nesta revisão.

Builds, caches, segredos, configurações de máquina e capturas em `.local/qa/` continuam fora do Git. O relatório detalhado do bloco está em `RELATORIO_PERFIL_ACESSIBILIDADE_2026-10-08.md`.

Este checkpoint encerra a etapa aprovada. Nenhuma nova funcionalidade de relato/IA foi iniciada.

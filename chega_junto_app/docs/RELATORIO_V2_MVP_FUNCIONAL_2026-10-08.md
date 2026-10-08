# V2 — MVP funcional do Chega Junto

**Data:** 8 de outubro de 2026.
**Marco:** checkpoint oficial após aprovação do fluxo principal e da Revisão final.
**Plataformas:** Android principal; Flutter Web complementar.
**Versionamento:** branch `main`, commit `feat: conclui fluxo principal do mvp`, tag anotada `V2` no commit deste relatório. A tag `V1` é preservada.

## Escopo entregue

São **21 telas de produto**, mais **1 estado transitório de processamento**. Diálogos, o card Novo Lembrete e a recuperação de URL inválida não contam como novas telas de produto.

| Bloco | Telas |
| --- | --- |
| Entrada e início | Boas-vindas/Splash, Login, Home |
| Preparação | Agenda, Detalhes da consulta, Checklist, Confirmação de presença |
| Relato | Relato pré-consulta, Áudio demonstrativo, Resumo organizado, Perguntas para a consulta, Revisão final |
| Perfil e apoio | Perfil, Dados pessoais, Medicamentos e alergias, Histórico de saúde, Detalhes do histórico, Notificações, Configurações de notificações, Acessibilidade, Ajuda |

A Agenda permite busca, filtros e lembretes locais. Dados pessoais incluem endereço e contato de emergência. Medicamentos/alergias permitem edição de registros fictícios. Histórico possui filtros e prévias textuais demonstrativas. Notificações permitem leitura, filtros e preferências da central interna. Ajuda contém busca, explicações e suporte demonstrativo.

## Fluxo principal e regras

```text
Splash → Login → Home → Agenda → Detalhes → Checklist
→ Confirmação → Relato → Áudio demonstrativo → Processamento
→ Resumo → Perguntas → Revisão final → Preparação concluída → Home 100%
```

A navegação inferior de todas as telas internas é **Início | Agenda | Preparo | Perfil**. Preparo abre o checklist existente. Splash e Login são as telas de entrada, sem menu de sessão. O fluxo de relato também é acessível pela Home e pelos Detalhes.

O progresso geral usa quatro macroetapas: Documentos e preparo, Confirmação de presença, Relato pré-consulta e Revisão final. O mock inicia em **3 de 4 = 75%**. Concluir a revisão marca apenas a quarta etapa; com as demais concluídas, a Home e a revisão mostram **4 de 4 = 100%**. Alterar relato, resumo ou perguntas reabre a revisão. Reabrir ou salvar sem alterações não invalida a conclusão. Documentos e presença pendentes não são concluídos automaticamente. O checklist possui percentual próprio calculado somente pelos itens obrigatórios.

O relato original permanece durante a sessão. A transcrição entra somente por ação explícita em **Usar transcrição no relato**. O resumo permite editar e remover conteúdo; o original não é apagado. Alterar o original sinaliza o resumo como desatualizado. As perguntas permitem selecionar, editar, adicionar, remover e reordenar. A revisão reúne somente atendimento, resumo revisado e perguntas selecionadas existentes, sem gerar informações novas. O usuário decide o que compartilhar; concluir não envia nada.

## Consistência do atendimento

Data fictícia de referência da demonstração: **7 de outubro de 2026**, anterior à próxima consulta. Não representa o relógio real do aparelho.

| Campo | Próximo atendimento compartilhado |
| --- | --- |
| Identificador | `consulta-demo-01` |
| Data e horário | Sexta-feira, 9 de outubro de 2026, 08:00 |
| Tipo/especialidade | Consulta clínica / Clínica geral |
| Profissional | Dra. Ana Beatriz Souza |
| Unidade | UBS Centro |

Home, Agenda, Detalhes e preparação usam o mesmo objeto/repositório. Presença, checklist, progresso e relato são compartilhados. O histórico de 6 de outubro é um evento passado distinto. Diagnósticos do histórico são informações já registradas, nunca resultados produzidos pelo app ou pela IA.

## Arquitetura

- `lib/app/`: composição da aplicação, `DemoSession`, roteamento central com `go_router`, tema e tokens.
- `lib/core/`: componentes reutilizáveis, serviços e controladores de sessão baseados em `ChangeNotifier`.
- `lib/data/`: modelos, contratos de repositório e implementações mockadas.
- `lib/features/`: páginas e widgets por funcionalidade, incluindo Revisão final.
- `test/`: testes unitários e de widgets; `integration_test/` e `test_driver/`: infraestrutura existente para jornada Android.

`PreparationController` mantém atendimento, documentos, presença e macroetapas. `ProfileController` mantém perfil e preferências. `ReportController`, criado fora das rotas, mantém texto original, transcrição, gravação demonstrativa, processamento, resumo e perguntas. `SpeechController` usa `SpeechEngine` substituível. Conclusão e invalidação da revisão são serializadas; falhas de salvamento preservam o rascunho e permitem repetição. Contratos permitem futura implementação via backend sem lógica de IA nos widgets. Não foi adicionada biblioteca de gerenciamento de estado.

## Mocks e serviços

| Implementação | Comportamento atual |
| --- | --- |
| `MockAuthRepository` | Login, Google e recuperação demonstrativos; sem validação externa ou envio de e-mail |
| `MockPreparationRepository` | Atendimentos fictícios, checklist, presença, lembretes e preparo em memória |
| `MockProfileRepository` e notificações locais | Perfil, histórico e preferências fictícios, com alterações durante a sessão |
| `MockAiAssistantService` | Espera demonstrativa de 1,4 s; separa literalmente os parágrafos fornecidos, mantendo seções não informadas vazias; oferece três perguntas neutras |
| `MockAudioDraftService` | Relógio, pausa/retomada e transcrição simulados; usa o texto existente ou exemplo neutro identificado, sem acessar microfone |
| Voz Android/Web | Leitura real pelo mecanismo local; apenas vozes locais em português, com aviso quando indisponíveis |

Não há OpenAI API, outra IA real, backend, MySQL, upload, prescrição, diagnóstico, interpretação de exames, compartilhamento automático ou integração com SUS/unidades/profissionais. Orientações de preparo são conteúdo fictício predefinido. Nenhuma informação clínica é inferida pelo mock.

## Acessibilidade

Temas claro/escuro/sistema, alto contraste, escala de texto, redução de animações, descrições de imagens, linguagem simples em telas de apoio e feedback tátil estão disponíveis. Conteúdo rola quando necessário; controles e formulários acomodam o teclado. A leitura por voz Android usa `flutter_tts`; a Web usa Web Speech API com seleção de voz local. Depende de voz em português instalada no ambiente e não usa fallback remoto.

A suíte verifica semântica, áreas de toque Android e contraste dos tokens. A matriz de layouts inclui 320×568 com escalas 1,5 e 2,1, 390×844 e 1366×900, temas claro/escuro com e sem alto contraste. A revisão manual Android inspecionou teclado, rolagem, fonte grande, tema escuro e alto contraste. Isso não equivale a auditoria completa com TalkBack nem validação em aparelho físico. A reprodução audível da voz nativa ainda não foi validada integralmente.

## Dependências

| Dependência | Uso |
| --- | --- |
| Flutter 3.41.4 / Dart 3.11.1 | SDK local |
| `go_router 17.5.0` | Rotas e URLs Web |
| `flutter_tts 4.2.5` | Mecanismo de leitura Android, licença MIT |
| `cupertino_icons 1.0.9` | Fonte usada internamente pelo SDK; resolve aviso de família ausente, licença MIT |
| `flutter_localizations` | Localização, do SDK |
| `flutter_test`, `integration_test`, `flutter_lints 6.0.0` | Validação e desenvolvimento |

Fonte Nunito Sans local, licença SIL OFL. Não há fonte remota, serviço pago ou dependência nova neste checkpoint.

## Validação automática final

| Comando | Resultado |
| --- | --- |
| `dart format .` | 91 arquivos verificados |
| `flutter analyze` | Sem problemas |
| `flutter test` | 76 testes aprovados |
| `flutter build web` | Concluído com sucesso |
| `flutter build apk --debug` | Concluído com sucesso |

Os testes cobrem estado compartilhado, falhas/repetição, preservação do original, uso explícito da transcrição, processamento/cancelamento, edição/exclusão do resumo, perguntas, conclusão/invalidação da revisão, Home 75%/100%, menu inferior, recuperação de rota desconhecida, temas, teclado e responsividade. O teste de integração existente foi atualizado para a Revisão final na implementação; neste checkpoint a jornada nativa foi validada manualmente, sem contabilizá-lo como uma nova execução automatizada.

## Validação Android nativa

Aplicativo instalado e iniciado no **emulador Android 16/API 36, x64, `emulator-5554`, resolução 1080×2400**. Foi percorrido manualmente todo o fluxo principal, incluindo iniciar/pausar/retomar/finalizar áudio demonstrativo, aceitar a transcrição, organizar texto próprio, desmarcar pergunta, revisar, voltar para edição e concluir. A Home exibiu **100% / 4 de 4**. Depois foi acrescentada uma frase ao relato: o texto foi preservado e a Home voltou a **75% / 3 de 4**, com revisão pendente e resumo sinalizado como desatualizado.

Também foram conferidos retorno pelo Android, menu inferior, mudanças do checklist refletidas nos Detalhes e no progresso, salvamento de presença com mensagem de nenhum envio à unidade, teclado, rolagem e controles de acessibilidade. Não houve overflow ou exceções Flutter nas telas inspecionadas. Capturas nativas locais ficam em `.local/v2-android/`, ignoradas pelo Git: `16-home-100.png`, `17-home-pendente.png` e `19-revisao-escuro-contraste.png`, entre outras.

A instalação inicial do APK universal encontrou versão anterior com código maior e pouco espaço no emulador. Foi gerado um APK de debug x64 com `--target-platform android-x64 --build-number=4004`, instalado com sucesso sem apagar dados ou alterar a versão do `pubspec.yaml`. As últimas correções visuais receberam nova compilação/verificação nativa. O build universal solicitado também foi executado separadamente. Não foi implementado suporte a Windows Desktop.

## Revisão de rotas e correções pontuais

Foram revisadas as 22 rotas de produto/estado, os destinos do menu, acessos a relato/revisão e detalhes dinâmicos de atendimento/histórico. Não foram encontradas rotas duplicadas nem destinos técnicos antigos expostos no fluxo aprovado. O cartão SUS e suporte continuam com retorno visual demonstrativo, sem inventar telas. A página de recuperação de URL inválida foi mantida para evitar quebrar a navegação; recebeu texto claro e teste do retorno à Home.

Correções deste checkpoint:

1. FAQ de Ajuda ainda dizia que o fluxo de IA não estava disponível; agora explica a organização simulada, edição e ausência de envio automático.
2. Rota inválida prometia uma futura tela; agora informa que a página não foi encontrada e permite voltar ao início.
3. Marca tinha pouca legibilidade no tema escuro; a mesma forma é renderizada em branco nesse tema, removendo também resíduos quase brancos do fundo do recorte.
4. Ilustração da Splash continha o texto incorporado “3 de 3 enviados”; somente esse trecho passa a “2 de 2 prontos”, coerente com o mock e sem afirmar upload. A referência original não foi modificada.

Não houve redesenho, refatoração ampla ou nova funcionalidade.

## Avisos restantes

- Três avisos do dry run WebAssembly de `flutter_tts 4.2.5`, por casts JS/Dart. O build JavaScript passa. Wasm não é alvo deste MVP.
- `flutter doctor`: licenças Android ainda não integralmente aceitas e Visual Studio incompleto. Não impediram build/execução Android; Windows Desktop está fora do escopo.
- A resolução anterior de dependências informa 11 versões mais recentes fora das restrições atuais; não foi feita atualização ampla.
- Nenhum novo aviso de família CupertinoIcons ausente. Redução de fontes por tree shaking é informação normal de build.

## Limitações e backend futuro

Dados e preferências duram somente a sessão. Reiniciar o aplicativo/recarregar a Web restaura os mocks. Login/Google/recuperação, áudio/transcrição, organização por IA, prévias de documentos, suporte e cadastro SUS continuam demonstrativos. Lembretes e notificações não programam alarmes, push, SMS ou e-mail. Presença não cancela/remarca nem comunica a unidade. Conclusão não compartilha dados.

Persistência durável, autenticação real, APIs de atendimento, armazenamento/importação de documentos, transcrição e organização reais dependerão de novo escopo, avaliação de privacidade/custo e contratos apropriados. Integrações com serviços de saúde dependerão ainda de disponibilidade e autorização externa. Backend futuro poderá ser avaliado em Python ou Java com preferência por MySQL; nenhuma dessas integrações foi iniciada.

A Web foi compilada em JavaScript; o runner complementar de widgets no Chrome havia ficado no carregamento no checkpoint anterior e não é contado como validação aprovada. Os testes atuais são unitários/widgets no runner padrão do Flutter; a jornada completa deste checkpoint foi executada no Android nativo.

## Publicação

Repositório: https://github.com/jeffsilva03/Chega-Junto---Desafio-IA. O SHA definitivo pode ser consultado com `git rev-parse 'V2^{}'`. A V2 aponta para o commit deste checkpoint, sem alterar a V1 (`05cb43ece8f864f7d748d6e12f99e2b51f3795d3`). Protótipos e documentação oficial foram preservados; o PNG de Revisão final fornecido pelo usuário foi somente incluído no versionamento. Builds, capturas, caches e segredos ficam fora do Git.

O MVP funcional principal está concluído e aprovado estruturalmente. Qualquer nova funcionalidade exige nova autorização.

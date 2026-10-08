# Entrega — Revisão final / Preparar para a consulta

Data: 8 de outubro de 2026. Implementação conforme `Design Telas ChegaJunto/revisao Final.png`, somente lido como referência. Entrega local, aguardando aprovação.

## Comportamento

Relato → Resumo → Perguntas → Revisão final → Concluir preparação.

A tela reúne a consulta compartilhada, o resumo revisado e somente as perguntas selecionadas. Nenhum conteúdo é gerado nesta etapa. Documentos opcionais reaproveitam o checklist, sem importação ou upload. O menu permanece Início | Agenda | Preparo | Perfil.

Editar resumo e Editar perguntas abrem as telas existentes. Voltar preserva o trabalho; salvar perguntas retorna à revisão quando a edição foi aberta por ela. A Home também abre a nova tela pelo item Revisão final.

Concluir preparação salva o conteúdo atual na sessão e marca somente a quarta macroetapa. No mock inicial, o progresso passa de **3 de 4 / 75%** para **4 de 4 / 100%**, refletido na Home e ao reabrir a tela. Outras etapas pendentes não são concluídas automaticamente.

Conforme decisão explícita do usuário, alterações no relato, resumo ou perguntas reabrem a Revisão final. O progresso volta a 75% quando as três outras etapas continuam concluídas. Navegar ou salvar sem mudar o conteúdo mantém a conclusão. O original e as edições são preservados.

O título antes da conclusão é Preparar para a consulta; após todas as etapas, Preparação concluída. A interface mantém **Você decide o que compartilhar**. A conclusão é local: não envia a profissional, UBS ou SUS, não representa confirmação clínica e não compartilha automaticamente.

## Arquitetura

- `lib/features/final_review/presentation/pages/final_review_page.dart`: composição, edição, estado concluído e ação principal.
- `lib/features/final_review/presentation/widgets/review_section.dart`: cartões expansíveis, com semântica de estado expandido.
- `ReportController`: seleção para revisão, salvamento/conclusão e invalidação após mudanças.
- `PreparationController`: progresso compartilhado e persistência em memória da quarta macroetapa.
- `PreparationRepository.setFinalReview` / `MockPreparationRepository`: contrato e implementação local.
- Rotas centralizadas, acesso da Home e continuação das perguntas atualizados.

Nenhuma dependência foi adicionada. Não houve nova biblioteca de estado, integração externa ou refatoração ampla das telas aprovadas.

## Validação

| Comando | Resultado |
| --- | --- |
| `dart format .` | 91 arquivos formatados/verificados |
| `flutter analyze` | Sem problemas |
| `flutter test` | **75 aprovados** |
| `flutter build web` | JavaScript compilado com sucesso |
| `flutter build apk --debug` | APK gerado com sucesso |

Há seis novos testes de estado e três de interface. A suíte anterior inclui a nova rota nas verificações de navegação, acessibilidade e responsividade. Cobertura: abertura, origem do conteúdo, seleção, retorno para edição, conclusão, 75%→100%, Home, invalidação, valores idênticos, erro/repetição de salvamento, ausência de resumo e conclusão sem perguntas.

Layouts: 320×568 com escalas 1,5 e 2,1; 390×844; 1366×900. Claro e escuro, com e sem alto contraste, incluindo estado concluído. Semântica e áreas de toque Android verificadas por testes de widgets.

Prévias de widgets em `.local/qa/`: `revisao-final-390.png`, `preparacao-concluida-390.png`, `home-preparacao-100-390.png`. Não são screenshots nativos Android. O teste de integração Android foi atualizado para o novo fluxo, mas não foi executado novamente; o APK normal foi compilado. Os avisos conhecidos do dry run de WebAssembly de flutter_tts permanecem; não impedem o build JavaScript. CupertinoIcons não voltou a apresentar aviso.

## Limites e versionamento

Dados fictícios de outubro de 2026; estado somente na sessão. Reiniciar o app ou recarregar a Web restaura o mock. Nenhuma API, backend, transcrição real, upload ou compartilhamento externo foi implementado.

Último checkpoint publicado: `3f01b3b1cc13630ec0c212f6c6c126032fabacf0`, branch main. Esta entrega não criou commit/push nem alterou a tag V1. Documentação oficial, protótipos e Landing Page foram preservados.

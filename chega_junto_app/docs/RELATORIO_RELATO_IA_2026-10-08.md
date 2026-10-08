# Relatório — Relato pré-consulta e organização com IA mockada

Data: 8 de outubro de 2026. Bloco implementado sobre o checkpoint de Perfil, sem modificar a documentação oficial, os protótipos ou a Landing Page.

**Atualização de checkpoint:** o usuário aprovou estruturalmente este fluxo. A revisão final preservou código e design; os comandos de formatação, análise, 66 testes e builds Web/APK foram repetidos com sucesso. O bloco integra o checkpoint na `main`, com a mensagem `feat: implementa fluxo de relato e ia simulada`, mantendo a tag `V1`. Veja o [status atualizado](RELATORIO_STATUS_2026-10-08.md) para os limites e verificações desta revisão. A jornada Android e as capturas descritas abaixo pertencem à implementação anterior.

## Entrega

O aplicativo passa a ter 20 telas, além do estado transitório de processamento. Foram implementados os quatro protótipos autorizados: Relato pré-consulta, Gravação de áudio, Resumo gerado pela IA e Perguntas para levar à consulta.

Fluxo: Home, Detalhes ou Preparo → relato escrito e/ou áudio demonstrativo → organização mockada → revisão e edição do resumo → seleção/edição de perguntas → salvar na sessão e retornar ao checklist.

Início, Agenda, Preparo e Perfil permanecem em todas as telas internas. A consulta compartilhada é a de 9 de outubro de 2026, às 08:00, com Dra. Ana Beatriz Souza na UBS Centro. Não foi criada uma tela de Relato final nem outro bloco funcional.

## Comportamento

- Texto e transcrição permanecem disponíveis ao voltar ou trocar de aba. O contador visual mantém 500 como referência; textos maiores não são truncados.
- Áudio simulado tem início, relógio, pausa, retomada e conclusão. A tela informa que não utiliza o microfone. A transcrição editável usa o relato existente ou um exemplo neutro fictício, incorporado somente após confirmação explícita.
- Processamento utiliza atraso demonstrativo e a linguagem “Organizando seu relato...”. Sair cancela a operação de interface; respostas atrasadas são ignoradas.
- Resumo separa parágrafos literalmente, sem inventar fatos ou interpretar clinicamente o texto. Seções sem conteúdo permanecem vazias e editáveis. Cada seção permite edição ou remoção.
- Mudanças no texto original sinalizam o resumo como desatualizado. Reorganização pede confirmação antes de substituir edições e perguntas.
- Perguntas neutras podem ser selecionadas, desmarcadas, editadas, acrescentadas, removidas e reordenadas. Continuar pode salvar sem perguntas selecionadas.
- Salvar grava o resumo revisado e somente as perguntas selecionadas no repositório em memória. Nada é enviado a uma unidade, profissional ou serviço externo.
- O progresso geral conserva a regra anterior de quatro macroetapas. Esta entrega não implementa um fluxo separado de Revisão final nem o declara concluído automaticamente.

## Arquitetura e arquivos principais

| Arquivo ou grupo | Responsabilidade |
| --- | --- |
| `lib/core/state/report_controller.dart` | Rascunho da sessão, áudio, processamento cancelável, resumo revisado e perguntas. |
| `lib/core/services/ai_assistant_service.dart` | Contrato de organização, preparado para futura implementação via backend. |
| `lib/data/mock/mock_ai_assistant_service.dart` | Organização literal e perguntas neutras, sem IA real. |
| `lib/core/services/audio_draft_service.dart` | Contrato para a entrada por áudio. |
| `lib/data/mock/mock_audio_draft_service.dart` | Transcrição demonstrativa sem gravação ou serviço remoto. |
| `lib/data/models/organized_report.dart` | Seções organizadas e perguntas com estado de seleção. |
| `lib/features/pre_visit_report/` | Relato, áudio e componentes compartilhados de apresentação. |
| `lib/features/ai_summary/` | Processamento, resumo e cartão editável de seção. |
| `lib/features/questions/` | Lista de perguntas e conclusão local do fluxo. |
| `test/report_controller_test.dart` | Fidelidade dos mocks, estado, falhas, cancelamento, edição e remoção. |
| `test/report_flow_test.dart` | Fluxos, responsividade, temas, acessibilidade, teclado e navegação. |
| `integration_test/report_flow_test.dart` | Jornada completa executada no emulador Android. |
| `test_driver/report_flow_driver.dart` | Gravação local das capturas PNG produzidas no Android. |

O projeto reutiliza tema, tokens, botões, superfícies, navegação e cartão de consulta. Não houve nova biblioteca de estado nem dependência de execução. Foi adicionado apenas `integration_test`, do SDK Flutter, como dependência de desenvolvimento para validação nativa e screenshots. O cache gerado pelo compilador Kotlin passou a ser ignorado no Git.

## Validação

- `dart format .`: concluído.
- `flutter analyze`: sem problemas.
- `flutter test`: 66 testes unitários/widgets aprovados.
- `flutter build web`: JavaScript compilado com sucesso.
- `flutter build apk --debug --split-per-abi`: também compilado; APKs separados para armeabi-v7a, arm64-v8a e x86_64.
- `flutter build apk --debug`: compilado com sucesso, usando a entrada normal `lib/main.dart`. APK em `build/app/outputs/flutter-apk/app-debug.apk`.
- Integração Android: jornada completa aprovada no Emulador Android 16/API 36, incluindo áudio simulado, resumo editado, seleção de perguntas, salvamento e tema escuro com alto contraste.
- Layouts: 320×568 com fontes 1,5 e 2,1; 390×844; 1366×900. Claro e escuro com e sem alto contraste. Testes verificam semântica, áreas de toque Android, edição com teclado e os quatro destinos do menu.

Permanecem os três avisos do dry run WebAssembly do `flutter_tts`, sem impedir o build JavaScript. O aviso de CupertinoIcons não retornou. O resolvedor informa 11 pacotes com versões mais novas incompatíveis com as restrições atuais; não foi feita atualização ampla.

`flutter doctor`: Flutter 3.41.4, Chrome e emulador disponíveis; há licenças Android ainda pendentes e instalação incompleta do Visual Studio. Windows Desktop e WebAssembly continuam fora do escopo. Na primeira instalação de teste, o emulador apresentou falta de armazenamento; o instalador Flutter reinstalou o aplicativo de demonstração, e os testes seguintes passaram. O APK universal final possui cerca de 190 MB e sua instalação também esbarrou no espaço disponível; foram gerados adicionalmente APKs por arquitetura, sem mudança de código ou dependências. O x86_64 possui cerca de 69 MB, foi instalado e iniciado com sucesso usando a entrada normal do aplicativo e é o indicado para este emulador.

## Capturas Android

Capturas nativas de 1080×2400 estão em `.local/android-qa/`, ignoradas pelo Git:

- `01-relato-android.png` e `01b-relato-acoes-android.png`.
- `02-audio-android.png` e `02b-audio-acoes-android.png`.
- `03-processamento-android.png`.
- `04-resumo-android.png` e `04b-resumo-acoes-android.png`.
- `05-perguntas-android.png`.
- `06-resumo-escuro-contraste-android.png`.

Para reproduzir:

```powershell
flutter drive --driver=test_driver/report_flow_driver.dart --target=integration_test/report_flow_test.dart -d emulator-5554
flutter build apk --debug
```

O segundo comando restaura o APK de demonstração com a entrada normal `lib/main.dart`, após a construção do aplicativo de teste. Reiniciar o aplicativo ou recarregar a Web restaura os dados fictícios. Não há persistência, IA real, transcrição real, backend, compartilhamento externo ou APIs pagas.

Para executar o APK menor no emulador com pouco espaço:

```powershell
flutter build apk --debug --split-per-abi
flutter run --use-application-binary=build/app/outputs/flutter-apk/app-x86_64-debug.apk -d emulator-5554 --no-pub
```

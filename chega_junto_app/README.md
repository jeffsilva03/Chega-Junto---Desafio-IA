# Chega Junto — MVP Flutter

Aplicativo local para apoiar a preparação antes de consultas e exames. Plataforma principal: Android. Flutter Web é complementar.

## Executar

```powershell
flutter pub get
flutter run -d chrome
flutter run -d emulator-5554
```

Abra esta pasta como projeto no Android Studio. O identificador do emulador pode variar; consulte `flutter devices`.

## Validar

```powershell
dart format .
flutter analyze
flutter test
```

Capturas locais opcionais dos testes de widgets:

```powershell
flutter test --dart-define=CAPTURE_QA=true
```

As capturas ficam em `.local/qa/`, fora do Git.

## Escopo implementado

- Boas-vindas (referência `splash.png`), login demonstrativo e Home.
- Agenda com busca, filtros, agrupamento por data e lembretes locais.
- Detalhes dos três atendimentos fictícios; checklist do próximo atendimento.
- Estado compartilhado: checklist e progresso geral permanecem consistentes ao navegar.
- Confirmação de presença com três respostas, salvamento local e orientações para procurar a unidade.
- Menu inferior fixo em todas as telas internas, incluindo Detalhes, Checklist e Confirmação. Splash e Login mantêm o fluxo de entrada aprovado.
- Perfil conforme `perfil.png`, com cartão SUS fictício, grupos de opções e saída pela engrenagem. Os destinos dos atalhos aguardam protótipos próprios, por decisão do projeto.
- Novo Lembrete conforme `novoLembrete.png`: card flutuante com título e opções 1 dia antes, 2 horas antes e No horário, relativas à próxima consulta.

Relato, IA e notificações possuem somente rotas técnicas temporárias. Não há integração com serviços de saúde.

## Dados e limites

Use um e-mail fictício e senha fictícia com pelo menos quatro caracteres, ou o botão de Google simulado. Nenhuma credencial é enviada, validada por servidor ou persistida. A recuperação de acesso é uma demonstração e não envia e-mail.

Os dados e endereços são fictícios. A data de referência da demonstração é 7 de outubro de 2026, com próxima consulta em 9 de outubro às 08:00. Os lembretes, respostas de presença e alterações do checklist duram apenas a sessão; reiniciar o aplicativo restaura os mocks. Adicionar lembrete não programa uma notificação do sistema. Salvar presença não avisa a unidade nem altera a consulta.

Não há backend, banco remoto, IA real, autenticação real, mapas externos ou serviços pagos. Orientações exibidas são conteúdo fictício previamente definido, não recomendações geradas por IA.

## Organização

```text
lib/
  app/          aplicação, sessão, rotas e tema
  core/         estado compartilhado, utilitários e componentes
  data/         modelos, contratos e repositórios mockados
  features/     páginas e widgets específicos de cada funcionalidade
assets/         recursos locais e licença da fonte
test/           navegação, responsividade, progresso e estado compartilhado
```

`PreparationRepository` permite futura troca por API. `PreparationController` mantém o estado da sessão para todas as telas. UI e modelos não dependem de um backend específico.

## Referências e identidade

As pastas externas de documentação, protótipos e Landing Page são fontes de referência e não devem ser editadas pelo aplicativo. A marca e a ilustração são renderizadas a partir de regiões de cópias dos PNGs aprovados; todos os controles e textos das telas são widgets Flutter. Um filtro de transparência aplicado somente ao logo remove o fundo branco visível sem modificar os originais.

Fonte local: Nunito Sans, licença SIL Open Font License em `assets/fonts/OFL.txt`. A família é uma aproximação visual, pois não foi fornecido o arquivo tipográfico dos protótipos. A fotografia do login deriva do PNG de baixa resolução disponível; um original em alta resolução permitirá refinamento futuro.

Dependência adicional de execução: `go_router 17.5.0`, compatível com Dart 3.11.1, para navegação centralizada e URLs Web. `flutter_localizations` pertence ao SDK; `flutter_lints` e `flutter_test` são usados na validação. Não há bibliotecas de estado ou carregamento remoto de fontes.

## Git

O repositório abrange a pasta principal do projeto, incluindo este aplicativo e as referências, conforme decisão posterior do projeto. Builds, caches, capturas locais, configurações de máquina e segredos são ignorados. `pubspec.lock` deve ser versionado. A tag `V1` identifica a primeira versão salva.

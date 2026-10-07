# Chega Junto

Aplicativo desenvolvido para o **Desafio Salte com a IA**.

## Visão geral

O **Chega Junto** é um aplicativo de apoio à preparação antes de consultas e exames de saúde.

A proposta é reduzir dificuldades que acontecem antes do atendimento, como:
- informações confusas;
- esquecimento de documentos;
- dúvidas sobre preparo;
- dificuldade para chegar ao local;
- barreiras para comparecimento;
- relatos desorganizados;
- dificuldade em lembrar o que perguntar durante a consulta.

O aplicativo busca facilitar a organização do usuário sem criar novas tarefas para profissionais de saúde.

## MVP

O primeiro MVP prioriza:
- Flutter;
- Android;
- Flutter Web;
- frontend navegável;
- dados mockados;
- UI/UX profissional;
- custo próximo de zero.

## Funcionalidades principais

- onboarding;
- login;
- home;
- agenda de consultas/exames;
- detalhes do atendimento;
- checklist de documentos e preparo;
- confirmação de presença;
- identificação de barreiras;
- orientação para remarcar/cancelar;
- localização/como chegar;
- relato pré-consulta em texto;
- relato por áudio;
- organização do relato com IA;
- revisão do resumo;
- perguntas sugeridas;
- perfil;
- notificações;
- privacidade.

## Stack

### Atual
- Flutter
- Dart
- Android Studio
- Flutter Web

### Planejado
- backend em Python ou Java;
- MySQL;
- integração com modelos de IA;
- APIs externas gratuitas ou de baixo custo.

## Documentação

Leia antes de implementar:
- `AGENTS.md`
- `docs/PROJECT_CONTEXT.md`
- `docs/PRODUCT_SCOPE.md`
- `docs/TECH_STACK.md`
- `docs/ARCHITECTURE.md`
- `docs/DESIGN_SYSTEM.md`
- `docs/USER_FLOWS.md`
- `docs/UI_IMPLEMENTATION_GUIDE.md`
- `docs/AI_SAFETY_RULES.md`

## Desenvolvimento inicial

O frontend deve ser desenvolvido primeiro usando dados mockados.

Prioridades:
1. fidelidade aos protótipos;
2. qualidade visual;
3. consistência;
4. navegação;
5. responsividade;
6. acessibilidade;
7. facilidade de trocar mocks por serviços reais depois.

## Execução

```bash
flutter pub get
flutter analyze
flutter run
```

Web:
```bash
flutter run -d chrome
```

## Regra importante

Este é um aplicativo de organização e preparação. A IA não deve diagnosticar, prescrever, interpretar exames ou tomar decisões clínicas.

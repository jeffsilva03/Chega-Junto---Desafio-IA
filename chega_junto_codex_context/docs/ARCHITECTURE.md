# Arquitetura Inicial — Chega Junto

## 1. Objetivo

Permitir construir rapidamente o MVP sem dificultar futura integração com backend. A arquitetura deve ser simples.

## 2. Organização sugerida
```text
lib/
├── main.dart
├── app/
│   ├── app.dart
│   ├── router/
│   │   └── app_router.dart
│   └── theme/
│       ├── app_colors.dart
│       ├── app_spacing.dart
│       ├── app_typography.dart
│       └── app_theme.dart
├── core/
│   ├── constants/
│   ├── utils/
│   └── widgets/
├── features/
│   ├── onboarding/
│   ├── auth/
│   ├── home/
│   ├── appointments/
│   ├── checklist/
│   ├── attendance/
│   ├── barriers/
│   ├── pre_visit_report/
│   ├── ai_summary/
│   ├── questions/
│   ├── location/
│   ├── notifications/
│   └── profile/
└── data/
    ├── models/
    ├── repositories/
    └── mock/
```

A estrutura pode ser simplificada se necessário.

## 3. Camadas mínimas
- UI: widgets e páginas;
- Models: estruturas de dados;
- Repository/Service: fonte dos dados;
- Mock: implementação inicial.

Não criar camadas adicionais sem necessidade.

## 4. Modelo sugerido: Appointment
Campos possíveis:
```text
id
type
title
dateTime
facilityName
address
instructions
documents
preparationItems
status
confirmationStatus
```

## 5. Modelo sugerido: ChecklistItem
```text
id
title
description
isCompleted
isRequired
```

## 6. Modelo sugerido: PreVisitReport
```text
id
appointmentId
originalText
transcription
organizedSummary
suggestedQuestions
updatedAt
```

## 7. Repositórios
Exemplo conceitual:
```text
AppointmentRepository
├── MockAppointmentRepository
└── ApiAppointmentRepository (futuro)
```

## 8. IA
Criar abstração simples apenas quando necessário:
```text
AiAssistantService
├── MockAiAssistantService
└── ApiAiAssistantService (futuro)
```

## 9. Áudio
Separar UI de gravação da futura transcrição:
```text
AudioRecorderService
TranscriptionService
```

## 10. Dependências
Adicionar apenas conforme a implementação exigir. Possíveis: `go_router`, fonte e biblioteca de ícones, se necessárias.

## 11. Persistência
Primeira fase: memória/mock. Se necessário, armazenamento local simples.

Não utilizar MySQL diretamente pelo Flutter. Quando MySQL entrar, o Flutter conversa com backend via API.

## 12. Comunicação futura
```text
Flutter
   ↓ HTTPS
Backend (Python ou Java)
   ├── MySQL
   ├── IA
   ├── transcrição
   └── APIs externas
```

Nunca:
```text
Flutter → MySQL diretamente
```

ou:
```text
Flutter → OpenAI com secret embutido
```

## 13. Configuração
Quando integrações reais começarem:
- usar variáveis de ambiente no backend;
- separar dev/prod;
- nunca versionar secrets.

## 14. Princípio
O MVP deve parecer completo para o usuário sem precisar ter infraestrutura completa por trás. A arquitetura deve permitir trocar mocks por APIs reais progressivamente.

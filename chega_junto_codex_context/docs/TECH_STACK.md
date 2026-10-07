# Stack Técnica — Chega Junto

## 1. Estratégia

A stack deve priorizar velocidade de desenvolvimento, baixo custo, facilidade de demonstração e possibilidade de evolução futura.

# 2. Frontend

- Flutter
- Dart

Motivos: Android e Web com uma base de código, boa produtividade, ecossistema maduro e UI customizável.

# 3. Ambiente

- Windows
- Android Studio
- Android Emulator
- Flutter SDK
- Git
- GitHub
- Codex

VS Code é opcional.

# 4. Plataformas

## Android
Principal plataforma do MVP. Entrega futura esperada: APK de demonstração.

## Flutter Web
Plataforma complementar para apresentação em navegador e fallback para acesso via iPhone durante o MVP.

## iOS
Não é prioridade do primeiro MVP.

# 5. Backend

Ainda não definido.

Preferências:
- Python: FastAPI ou Flask;
- Java: Spring Boot.

Não escolher definitivamente antes de existir necessidade real. O frontend deve funcionar primeiro com mocks.

# 6. Banco de dados

Preferência futura: MySQL.

Durante o MVP inicial:
- evitar banco remoto;
- usar listas mockadas, JSON local ou armazenamento local quando necessário.

# 7. Gerenciamento de estado

Começar simples. Preferir recursos nativos do Flutter, `ValueNotifier`, `ChangeNotifier` ou equivalente. Adicionar Riverpod/Bloc apenas se a complexidade justificar.

# 8. Navegação

Navigator ou `go_router`. Para múltiplas telas, `go_router` pode ser utilizado mantendo rotas centralizadas e legíveis.

# 9. IA

## Fase 1
Mock: usuário envia relato, app mostra estado de processamento e exibe resultado de demonstração.

## Fase futura
Avaliar OpenAI API ou alternativa com base em preço, privacidade, facilidade, qualidade e free tier/créditos.

Nunca colocar chave da API diretamente no Flutter. A chamada real deve passar por backend seguro.

# 10. Áudio / transcrição

Fase inicial: fluxo simulado ou gravação local.

Fase futura: avaliar speech-to-text via backend, soluções open-source ou APIs com free tier.

# 11. Mapas e localização

Priorizar soluções gratuitas, links externos para apps de mapas, OpenStreetMap quando adequado e APIs comerciais somente se justificadas. Não adicionar Google Maps automaticamente.

# 12. Autenticação

No MVP: autenticação simulada. Futuramente avaliar solução apenas quando necessária.

# 13. Dependências

Antes de adicionar package, verificar manutenção, compatibilidade, licença e necessidade real.

# 14. Qualidade

Antes de considerar uma tarefa concluída:
```bash
dart format .
flutter analyze
```

Quando possível:
```bash
flutter test
```

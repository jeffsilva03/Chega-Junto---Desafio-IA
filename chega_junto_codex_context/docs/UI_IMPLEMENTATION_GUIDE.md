# Guia de Implementação das Telas

## 1. Regra principal

Os screenshots/protótipos aprovados são a principal fonte visual. Não criar um design paralelo.

## 2. Processo para cada tela
Antes de codificar:
1. identificar estrutura;
2. identificar componentes reutilizáveis;
3. identificar tipografia;
4. identificar espaçamentos;
5. identificar estados;
6. identificar interação;
7. identificar relação com telas anteriores/próximas.

## 3. Estrutura mínima de uma feature
```text
features/checklist/
├── presentation/
│   ├── pages/
│   │   └── checklist_page.dart
│   └── widgets/
│       └── checklist_item_tile.dart
├── models/
└── ...
```

Não criar pastas vazias apenas para seguir padrão.

## 4. Reutilização
Criar componentes globais somente quando realmente repetidos, por exemplo: botão primário, header, appointment card, status chip, checklist row e section title.

## 5. Fidelidade visual
Comparar implementação com protótipo considerando alinhamento, tamanho, peso tipográfico, largura, altura, padding, radius, ícones, CTA e densidade visual. Não basta “ter os mesmos elementos”.

## 6. Conteúdo
Usar dados fictícios realistas. Evitar lorem ipsum e dados reais de pessoas.

## 7. Layout mobile
Desenvolver primeiro para tamanho Android moderno. Garantir SafeArea, scrolling, teclado e ausência de overflow.

## 8. Flutter Web
Preservar o design mobile, centralizar conteúdo, aplicar `maxWidth` e manter proporções. Não transformar automaticamente em dashboard desktop.

## 9. Assets
```text
assets/
├── images/
├── icons/
└── illustrations/
```
Evitar assets decorativos que não existam no protótipo.

## 10. Tema
Centralizar cores, textos, spacing, radius e shadows. Não repetir valores em dezenas de widgets.

## 11. Estados
Para telas importantes, prever: initial, loading, success, empty e error.

## 12. Navegação
Evitar dead ends durante a demonstração.

## 13. Formulários
Validação simples, labels claras e feedback imediato. Não criar regras de produção que dificultem o MVP.

## 14. Tela de IA
A IA deve parecer funcionalidade do produto, não chatbot. Evitar balões genéricos, branding exagerado de IA, estrelas e brilhos. Preferir entrada → processamento → resultado estruturado → edição.

## 15. Checklist de conclusão
- [ ] corresponde ao protótipo;
- [ ] sem overflow;
- [ ] scroll funciona;
- [ ] navegação funciona;
- [ ] cores vêm do tema;
- [ ] tipografia vem do tema;
- [ ] componentes repetidos foram reutilizados;
- [ ] texto está legível;
- [ ] funciona no Android;
- [ ] sem dependências desnecessárias;
- [ ] `flutter analyze` sem problemas relevantes.

## 16. Ao receber uma nova imagem
O agente deve analisar a imagem, localizar a feature, verificar componentes já existentes, implementar sem destruir telas aprovadas, conectar à navegação, executar análise e explicar brevemente o que mudou.

# Design System — Chega Junto

## 1. Objetivo

Criar um aplicativo com aparência de produto real, profissional, moderno e confiável. O sistema visual deve ser consistente entre todas as telas.

A principal referência de cada tela será o protótipo/screenshot aprovado.

## 2. Personalidade visual

Transmitir:
- confiança;
- clareza;
- acolhimento;
- organização;
- proximidade;
- simplicidade;
- competência.

Não transmitir:
- frieza clínica;
- burocracia;
- infantilidade;
- tecnologia futurista;
- estética “IA”.

## 3. Princípios

### Clareza antes de decoração
Todo elemento deve ter função.

### Uma ação principal por contexto
Evitar competição visual.

### Hierarquia evidente
O usuário deve saber rapidamente onde está, o que é importante e o que fazer agora.

### Consistência
Mesmos componentes mantêm dimensões, radius, tipografia, estados e comportamento.

### Acessibilidade
Não sacrificar leitura por estética.

## 4. Cores

Criar tokens no tema, por exemplo:
```text
primary
primaryContainer
secondary
info
warning
error
surface
surfaceMuted
background
textPrimary
textSecondary
textDisabled
border
success
```

Direção:
- verde/teal: identidade e ações positivas;
- azul-saúde: informação e confiança;
- laranja: pendências e atenção;
- vermelho: erro e ações destrutivas;
- branco/cinzas claros: superfícies;
- texto escuro: legibilidade.

Evitar fundos muito saturados em grandes áreas sem referência explícita.

## 5. Tipografia

Sans-serif moderna e legível. Criar estilos como:
```text
display
headlineLarge
headlineMedium
titleLarge
titleMedium
bodyLarge
bodyMedium
bodySmall
labelLarge
labelMedium
caption
```

## 6. Espaçamento

Adotar escala consistente:
```text
4, 8, 12, 16, 20, 24, 32, 40, 48, 64
```

Margem horizontal mobile sugerida: 20 ou 24 px, conforme protótipo.

## 7. Grid e largura

### Mobile
Conteúdo alinhado e margens consistentes.

### Web
Usar `maxWidth`, centralizar conteúdo e evitar esticar formulários/cards por telas largas.

## 8. Border radius

Sugestão de tokens:
```text
radiusSmall: 8
radiusMedium: 12
radiusLarge: 16
radiusXLarge: 20
```

Não usar radius exagerado em todos os elementos. Pills apenas para status/filtro/tag.

## 9. Sombras

Usar pouco. Preferir borda sutil e mudança de superfície. Evitar cards excessivamente flutuantes.

## 10. Botões

- Primary: ação principal;
- Secondary: ação alternativa;
- Text: menor peso;
- Destrutivo: cancelar/apagar.

Nunca colocar várias ações primárias competindo.

## 11. Cards

Cards devem representar agrupamentos reais. Não transformar toda linha em card.

## 12. Inputs

Devem ter label clara, foco, erro, disabled e texto legível. Campos de relato devem ser multiline e não parecer formulário burocrático.

## 13. Ícones

Preferir ícones simples e consistentes. Evitar emoji, 3D e mistura de estilos.

## 14. App Bar

Simples: voltar, título e ação contextual quando necessário.

## 15. Navegação inferior

Se usada, 3 a 5 destinos. Sugestão:
```text
Início | Agenda | Notificações | Perfil
```

## 16. Feedback

Comunicar sucesso, erro, processamento, pendência e seleção com mudanças de estado e mensagens curtas.

## 17. Loading

Para IA, usar texto humano como “Organizando seu relato...”. Nunca insinuar diagnóstico.

## 18. Empty states

Simples e úteis, com ação apenas quando houver algo útil para fazer.

## 19. Linguagem

Preferir:
- “Seu próximo atendimento”
- “O que você precisa levar”
- “Você consegue comparecer?”
- “Conte o que você gostaria de lembrar”
- “Revise antes de continuar”

Evitar jargões, linguagem clínica desnecessária, robótica ou promessas absolutas.

## 20. Animações

Usar apenas quando melhorarem o fluxo: fade, slide curto e mudança de estado. Evitar efeitos chamativos.

## 21. Regras anti-“cara de IA”

Não gerar automaticamente:
- gradiente roxo/azul;
- blobs;
- mesh gradients;
- ilustrações 3D;
- textos genéricos como “Sua saúde, nossa prioridade”;
- cards excessivos;
- dashboards com gráficos sem necessidade;
- estrelas/brilhos;
- ícones flutuantes;
- visual futurista.

O app deve parecer projetado a partir de necessidades reais do usuário.

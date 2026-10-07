# AGENTS.md — Chega Junto

## 1. Propósito

Este arquivo contém as regras permanentes para qualquer agente de programação trabalhando neste repositório. Antes de criar, editar, remover ou refatorar qualquer arquivo, leia este documento e os arquivos da pasta `docs/`.

O projeto se chama **Chega Junto** e está sendo desenvolvido para o **Desafio Salte com a IA**.

## 2. Objetivo do produto

O Chega Junto é um aplicativo de apoio à preparação de pessoas antes de consultas e exames de saúde.

O produto deve ajudar o usuário a:
- visualizar atendimentos;
- entender data, horário, local e orientações;
- conferir documentos e preparo;
- confirmar presença;
- identificar barreiras para comparecimento;
- receber orientação para remarcar/cancelar quando necessário;
- registrar relato prévio em texto ou áudio;
- utilizar IA para transcrever e organizar esse relato;
- revisar, editar ou excluir informações antes de compartilhar;
- receber perguntas neutras para apoiar a conversa com o profissional.

O aplicativo **não substitui profissionais de saúde** e **não toma decisões clínicas**.

## 3. Prioridade atual

Construir um **MVP visual e navegável**, com foco em:
1. frontend Flutter;
2. Android como principal plataforma de demonstração;
3. Flutter Web como plataforma complementar;
4. dados mockados/localmente;
5. design extremamente profissional;
6. ótima experiência de UI/UX;
7. baixo ou nenhum custo durante o desenvolvimento inicial.

Não iniciar backend real, autenticação real, banco remoto ou integrações pagas sem solicitação explícita.

## 4. Stack definida

### Frontend
- Flutter
- Dart

### Plataformas
- Android: prioridade
- Flutter Web: compatibilidade obrigatória sempre que razoável
- iOS: não é requisito para o primeiro MVP

### Ambiente de testes
- Android Studio / Android Emulator
- navegador para Flutter Web

### Backend futuro
Preferências:
1. Python
2. Java

A escolha final ainda não foi definida.

### Banco futuro
- MySQL

### Inteligência Artificial
A solução poderá utilizar modelos da OpenAI/ChatGPT futuramente. Na primeira fase, respostas de IA podem ser simuladas com dados mockados.

### APIs externas
Avaliar conforme a necessidade e sempre priorizar: solução gratuita, free tier, open-source ou menor custo operacional.

## 5. Regra de custo

Um dos pilares do MVP é **evitar custos**. Antes de adicionar dependência externa, verificar:
- existe alternativa gratuita?
- existe implementação local?
- existe free tier?
- é realmente necessária para o pitch?
- pode ser simulada no MVP?

Não adicionar infraestrutura complexa apenas por parecer “mais profissional”.

## 6. Regras obrigatórias de UI/UX

O aplicativo deve parecer um produto desenvolvido por uma equipe profissional de produto e design.

### Direção visual
- moderno;
- institucional;
- humano;
- acolhedor;
- acessível;
- limpo;
- maduro;
- consistente;
- altamente legível.

### Não deve parecer
- template genérico de Flutter;
- dashboard SaaS;
- aplicativo criado por IA;
- aplicativo clínico frio;
- protótipo acadêmico;
- conjunto de telas desconectadas.

### Evitar
- gradientes excessivos;
- blobs decorativos;
- ilustrações aleatórias;
- ícones 3D;
- sombras exageradas;
- glassmorphism;
- excesso de cores;
- cartões para absolutamente tudo;
- bordas arredondadas exageradas;
- espaçamentos inconsistentes;
- texto artificial ou técnico;
- elementos inventados quando existe referência de tela.

### Preferir
- UI predominantemente plana;
- grid consistente;
- componentes reutilizáveis;
- hierarquia tipográfica clara;
- ícones simples;
- superfícies limpas;
- bom uso de espaço em branco;
- feedback visual claro;
- estados realistas;
- acessibilidade.

### Paleta-base
- branco / neutros claros: superfícies;
- verde / teal: identidade e ações positivas;
- azul-saúde: informação e confiança;
- laranja: alertas e atenção;
- vermelho: apenas erro ou ação destrutiva.

### Material Design
Material 3 pode ser usado como **base técnica**, mas não deve determinar sozinho a aparência. Criar tema e componentes próprios.

## 7. Reprodução de protótipos e screenshots

Quando uma imagem de uma tela for fornecida:
1. tratá-la como principal referência visual;
2. reproduzir fielmente hierarquia, proporções, espaçamento e composição;
3. não “melhorar” ou redesenhar por conta própria;
4. não inserir elementos extras;
5. reutilizar componentes quando isso não comprometer a fidelidade;
6. manter responsividade;
7. adaptar apenas quando necessário para diferentes tamanhos.

## 8. Arquitetura Flutter

Priorizar arquitetura simples, organizada e escalável:

```text
lib/
├── app/
│   ├── app.dart
│   ├── router/
│   └── theme/
├── core/
│   ├── constants/
│   ├── extensions/
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
└── main.dart
```

Evitar arquitetura excessivamente complexa. Não implementar Clean Architecture completa, BLoC ou Redux sem necessidade clara.

## 9. Estado e dados

Na primeira fase:
- usar dados mockados;
- manter modelos separados da UI;
- evitar valores importantes hardcoded diretamente em widgets;
- criar interfaces simples de serviço quando isso facilitar futura troca por API real.

Exemplo:
```text
AppointmentRepository
├── MockAppointmentRepository
└── ApiAppointmentRepository (futuro)
```

## 10. Navegação

Usar solução simples e robusta. Se `go_router` for usado, manter rotas centralizadas e legíveis.

## 11. Responsividade

### Android
Principal referência de UI.

### Flutter Web
Manter coerência visual; limitar largura máxima do conteúdo quando apropriado; não esticar formulários e cards por toda a tela.

## 12. Acessibilidade

Sempre que possível:
- contraste adequado;
- textos legíveis;
- áreas de toque confortáveis;
- suporte a escalabilidade de fonte;
- labels semânticos;
- mensagens claras;
- não depender apenas de cor.

## 13. Regras de saúde e IA

A IA é uma ferramenta de **organização e comunicação**, não de diagnóstico.

A IA NÃO pode:
- diagnosticar;
- sugerir diagnóstico;
- prescrever;
- sugerir alteração de medicamentos;
- interpretar exames;
- definir urgência clínica;
- decidir condutas;
- substituir avaliação profissional;
- enviar automaticamente informações ao SUS ou profissionais.

A IA PODE:
- transcrever relato;
- organizar informações fornecidas pelo próprio usuário;
- estruturar tópicos;
- resumir;
- sugerir perguntas neutras;
- melhorar clareza textual sem mudar o sentido.

O usuário deve poder revisar, editar, excluir e decidir o que compartilhar.

## 14. Privacidade

Para o MVP:
- não coletar dados reais desnecessariamente;
- preferir dados fictícios;
- nunca incluir tokens, API keys ou secrets no código;
- nunca colocar chave da OpenAI diretamente no Flutter;
- integrações reais de IA devem utilizar backend seguro.

## 15. Qualidade de código

O código deve:
- ser legível;
- usar nomes claros;
- evitar arquivos gigantes;
- evitar widgets excessivamente aninhados;
- reutilizar componentes visuais;
- usar comentários apenas quando agregarem contexto;
- passar `flutter analyze`;
- ser formatado com `dart format`;
- evitar warnings e dependências desnecessárias.

## 16. Testes

Durante a fase de frontend, prioridade:
1. compilar;
2. navegação funcionar;
3. ausência de overflow;
4. comportamento em diferentes tamanhos;
5. estados principais demonstráveis.

## 17. Regra para mudanças

Antes de alterações amplas:
- entender a estrutura existente;
- preservar funcionalidades já implementadas;
- evitar refatorações não solicitadas;
- não alterar design de telas aprovadas;
- não substituir arquitetura sem justificar.

## 18. Resposta do agente após implementar

Informar de forma curta:
1. o que foi criado/alterado;
2. arquivos principais modificados;
3. como executar/testar;
4. limitações ou diferenças do protótipo;
5. próximo passo recomendado, se relevante.

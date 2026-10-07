# Escopo do Produto — MVP Chega Junto

## 1. Objetivo desta versão

Construir um MVP convincente, navegável e visualmente profissional. O MVP não precisa ter todas as integrações de produção.

# 2. Prioridade P0 — fluxo principal

## 2.1 Splash / abertura
- apresentar a marca;
- carregamento rápido;
- encaminhar para onboarding ou login.

## 2.2 Onboarding
- explicar a proposta em poucas etapas;
- apresentar benefícios;
- evitar textos longos.

## 2.3 Login
- pode ser simulado;
- não exige autenticação real.

## 2.4 Home
Deve apresentar:
- próximo atendimento;
- ações prioritárias;
- progresso de preparação;
- atalhos úteis.

## 2.5 Agenda
Deve mostrar consultas/exames, data, horário, unidade e status usando dados fictícios.

## 2.6 Detalhes do atendimento
Reunir tipo, data, horário, local, orientações, preparação, documentos e ações relacionadas.

## 2.7 Checklist
Possíveis itens:
- documento com foto;
- cartão SUS;
- pedido/encaminhamento;
- exames anteriores;
- preparo específico;
- outras orientações.

Permitir marcar itens como concluídos.

## 2.8 Confirmação de presença
Estados:
- vou comparecer;
- ainda não sei;
- não conseguirei comparecer.

A escolha pode direcionar para barreiras/orientações.

## 2.9 Relato pré-consulta
Permitir escrever motivo principal, sintomas/dificuldades relatadas pelo próprio usuário, dúvidas e informações que deseja lembrar. Não interpretar clinicamente.

## 2.10 Gravação de áudio
No primeiro MVP pode ser simulação visual completa ou gravação local real, se simples e gratuita. Transcrição real não é obrigatória na primeira fase.

## 2.11 Resumo organizado por IA
Inicialmente usar conteúdo mockado, mostrar processamento e apresentar resultado editável.

## 2.12 Perguntas sugeridas
Perguntas neutras para ajudar na conversa, sem induzir diagnóstico.

# 3. Prioridade P1 — completar experiência

## 3.1 Cadastro / primeiro acesso
Pode ser simulado.

## 3.2 Barreiras para comparecimento
Possíveis opções:
- transporte;
- horário;
- trabalho;
- acompanhante;
- documentos;
- dificuldade de localização;
- outro.

## 3.3 Remarcar ou cancelar
No MVP: orientação e direcionamento simulado. Não afirmar que o app alterou uma consulta no SUS.

## 3.4 Como chegar
Endereço, referência, opção de abrir rota e mapa/placeholder.

## 3.5 Relato final
Tela consolidada contendo resumo revisado e perguntas. Ações: editar, copiar e futuramente compartilhar.

## 3.6 Perfil
Informações básicas e preferências.

## 3.7 Notificações
Central de lembretes; no MVP podem ser dados mockados.

## 3.8 Privacidade e consentimento
Explicar como o relato é utilizado, papel da IA, controle do usuário e limites da ferramenta.

# 4. Estados de interface necessários

Quando relevante:
- loading;
- vazio;
- erro;
- sem internet;
- sucesso;
- processamento;
- permissão negada;
- ação desabilitada.

# 5. Fora do escopo inicial

Não implementar sem solicitação:
- integração oficial com SUS;
- prontuário eletrônico;
- diagnóstico;
- triagem clínica automática;
- prescrição;
- interpretação de exames;
- telemedicina;
- chat médico;
- pagamentos;
- envio automático de dados a profissionais;
- infraestrutura cloud paga;
- painel administrativo completo.

# 6. Critério de sucesso do MVP

```text
Usuário abre o app
→ visualiza próximo atendimento
→ consulta detalhes
→ confere checklist
→ confirma presença
→ registra relato
→ simula processamento por IA
→ revisa resumo
→ recebe perguntas
→ chega mais preparado ao atendimento
```

# Decisões de implementação do MVP

- Documentação oficial e protótipos existentes orientam a implementação. Código pertence somente a esta pasta.
- Boas-vindas usa uma única página, três indicadores decorativos e ambos os acessos seguem para Login.
- Navegação: Início, Agenda, Preparo, Perfil. Preparo abre diretamente o checklist do próximo atendimento.
- Mocks em outubro de 2026. A mesma consulta, profissional, unidade, horário e status são reutilizados entre Home, Agenda, Detalhes e Checklist.
- Progresso geral: documentos/preparo, presença, relato e revisão final. Os três primeiros começam concluídos; revisão final está pendente (75%).
- Checklist: documento com foto e cartão SUS são obrigatórios; demais itens são opcionais. Com os dois documentos marcados, seu percentual é 100%, enquanto o preparo geral permanece em 75%. Desmarcar um documento reduz checklist para 50% e preparo geral para 50%.
- Concluir checklist salva o estado já selecionado e retorna à Home, sem marcar automaticamente itens e sem impedir navegação com pendências.
- Agenda inicia em Próximos porque a consulta é futura em relação à data fictícia de referência. Hoje e filtros funcionam sobre os itens da lista. O destaque do próximo atendimento permanece separado dos resultados de busca.
- Lembretes são registros locais em memória. Não geram push ou alarmes do Android.
- Novo Lembrete segue o novo protótipo com card flutuante ancorado no botão, título editável/limpável e três antecipações relativas à próxima consulta. Cancelar não grava. Os horários calculados são listados cronologicamente na Agenda e o registro guarda o identificador da consulta.
- O card de lembrete mantém Salvar/Cancelar visíveis com teclado e fonte ampliada; seu conteúdo rola quando necessário. O menu permanece visível, e o card é reposicionado quando faltar espaço acima do botão.
- Perfil reproduz a tela principal com dados fictícios e email no domínio reservado example.test. O cartão SUS reutiliza o símbolo do protótipo e a unidade da consulta compartilhada; não há validação de cadastro pelo SUS.
- Após entrega dos protótipos próprios, foram implementados os oito destinos autorizados de Perfil. Cartão SUS continua aguardando protótipo próprio. A engrenagem dá acesso às configurações de notificações e à saída da demonstração.
- O menu do protótipo de Perfil é adaptado para a decisão oficial Início, Agenda, Preparo, Perfil.
- Ajuste oficial posterior do Perfil: Meus dados contém apenas Dados pessoais (endereço e contato de emergência estão na mesma página). Minha saúde contém Medicamentos e alergias em um único destino, com Histórico separado.
- O mapa de Detalhes é uma ilustração vetorial local. Como chegar apresenta o endereço fictício com opção de copiar. Não chama serviços de mapas.
- Não há ações reais de remarcação, cancelamento, aviso à unidade ou envio a profissionais.
- Confirmação segue o protótipo aprovado: resumo da consulta, três opções, informação, ajuda, salvar e responder depois. O indicador usa Etapa 2 de 4 conforme as macroetapas oficiais.
- Presença é salva somente ao tocar em Salvar resposta; Responder depois ou sair pelo menu não grava a seleção. A resposta atualiza a mesma consulta em Home, Agenda e Detalhes e pode ser revista.
- Regra atual de progresso (submetida à decisão de produto): Vou comparecer conclui a etapa de presença; Ainda não sei e Não poderei comparecer mantêm essa etapa pendente. Nenhuma resposta cancela ou remarca a consulta.
- Ver como remarcar e Orientações para avisar a unidade abrem explicações em diálogos; não criam integração nem nova tela de barreiras sem protótipo.
- Menu inferior obrigatório em todas as telas internas. Detalhes destaca Agenda; Checklist e Confirmação destacam Preparo. As telas de entrada aprovadas permanecem sem navegação de sessão.
- Relato permanece na rota técnica existente, aguardando implementação autorizada.
- O logo recebe transparência no momento da renderização, sem redesenho da marca nem alteração de arquivos de referência.
- Textos e layouts suportam rolagem, largura mobile limitada na Web e fonte ampliada. Molduras de aparelhos e barras de sistema desenhadas nos protótipos não são recriadas como UI.

## Destinos de Perfil e acessibilidade — 8 de outubro de 2026

- As oito novas telas usam os PNGs fornecidos como referência de composição. Mantêm o menu inferior oficial; nenhuma moldura de aparelho é copiada.
- Dados pessoais e medicamentos/alergias mantêm rascunhos até Salvar. Sair sem salvar descarta o rascunho. Formulários validam preenchimento e formato; não validam CPF ou cadastro em serviços externos.
- Medicamentos e doses são exemplos fictícios transcritos da referência, não sugestões. Novos registros dependem de texto fornecido pelo usuário; o app não prescreve nem interpreta exames.
- Histórico usa eventos passados de 1 a 6 de outubro de 2026. O atendimento de 6 de outubro e a consulta futura de 9 de outubro são eventos distintos. Profissional e unidade permanecem consistentes nos registros pertinentes.
- Documentos do histórico abrem prévias textuais demonstrativas, sem fingir importação, receita ou laudo válido.
- A lista de notificações deriva dos atendimentos e lembretes compartilhados. Filtros, preferências e leitura atualizam o estado local e o indicador da Home. O conteúdo de presença reflete a resposta atual da sessão, sem afirmar comunicação com a unidade.
- Configurações de notificações aplicam imediatamente a chave geral, categorias e exibição no aplicativo. Não há push, agendamento do sistema, SMS ou e-mail.
- Preferências de acessibilidade aplicam imediatamente na sessão. Tema escuro e alto contraste usam tokens semânticos compartilhados nas telas novas e anteriores. A aparência clara aprovada é preservada por padrão. Alto contraste possui verificações de contraste para texto principal/secundário e botões.
- Tamanho do texto multiplica a escala de acessibilidade do sistema, sem limitá-la. Redução de animações remove transições de navegação e efeitos dos controles compartilhados. Barras do sistema acompanham o tema no Android.
- Leitura em voz alta real adiciona um controle de ouvir/parar. Percorre os textos da rota ativa, inclui descrições de imagens quando habilitadas e para ao navegar. A implementação nativa usa flutter_tts (MIT); a Web usa Web Speech API. Apenas vozes locais em português são aceitas, sem fallback remoto ou API paga. A ausência de voz instalada produz uma mensagem, não simulação de áudio.
- Linguagem simples ajusta explicações de Histórico e Ajuda. Descrições adicionam a identificação das imagens à leitura. Feedback tátil usa a API do sistema em aparelhos compatíveis.
- Ajuda contém busca, respostas e tutoriais textuais locais. Falar com suporte explica o caráter demonstrativo, sem enviar mensagens nem abrir integrações externas.
- Novos contratos de repositório, modelos e controladores separam estado de sessão e apresentação. Não foi adicionada biblioteca de estado ou persistência.

## Validação deste bloco

- Checkpoint após aprovação estrutural: `dart format .` concluído; `flutter analyze` sem problemas; `flutter test` com 42 testes aprovados.
- Testes cobrem edição, validação, falhas de repositório, consistência entre telas, filtros, preferências, seleção de voz local e leitura com mecanismo substituído em teste.
- Layouts verificados com widgets em 320×568 (escalas efetivas de texto 1,5 e 2,1), 390×844 e 1366×900. Revisão ampliada para claro/escuro, cada um com e sem alto contraste, nas telas anteriores e novas. O menu oficial é verificado em ordem e por navegação a partir de todos os novos destinos. A versão Web também foi conferida interativamente na implementação, incluindo rótulos semânticos e acionamento/interrupção da voz local.
- `flutter build web`: repetido com sucesso em JavaScript. O dry run emite avisos de compatibilidade WebAssembly do plugin flutter_tts; Wasm não é alvo validado deste MVP. O aviso CupertinoIcons foi corrigido com o pacote oficial cupertino_icons 1.0.9 (MIT), que fornece a fonte retida por componentes internos do SDK. A fonte foi reduzida pelo tree shaking a 1.472 bytes, sem redesenho ou serviço externo.
- `flutter build apk --debug`: repetido com sucesso no checkpoint. Na implementação, o APK também foi instalado e iniciado no Emulador Android 16/API 36. A execução nativa não equivale a teste manual completo de todas as telas ou de áudio no aparelho.
- `flutter doctor`: Flutter/Chrome disponíveis. Há licenças Android pendentes e instalação incompleta de Visual Studio (Windows desktop fora do escopo); não impediram build e execução Android nesta máquina.

## Ajustes pontuais do checkpoint

- Diagnósticos aparecem como "Diagnósticos registrados" no filtro e "Diagnóstico registrado" nos registros. O exemplo informa explicitamente que é histórico preexistente e não produzido pelo Chega Junto ou pela IA.
- A revisão preservou a composição das telas aprovadas. Não houve redesenho ou refatoração ampla, implementação de Windows desktop, trabalho de suporte a Wasm ou avanço no fluxo de relato/IA.
- A suíte passou a verificar também o retorno visual ao salvar dados e medicamentos/alergias, a origem histórica do diagnóstico e os quatro destinos oficiais do menu inferior a partir das oito novas telas.

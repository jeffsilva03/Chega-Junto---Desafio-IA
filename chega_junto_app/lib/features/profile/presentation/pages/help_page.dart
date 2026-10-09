import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/state/profile_controller.dart';
import '../../../../core/widgets/app_surface.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../widgets/profile_components.dart';

class HelpPage extends StatefulWidget {
  const HelpPage({super.key, required this.controller});
  final ProfileController controller;
  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
  final _search = TextEditingController();
  static const _topics = [
    (
      Icons.calendar_month_outlined,
      'Como acompanhar uma consulta',
      'Abra Agenda, escolha o atendimento e confira data, horário, local e orientações. O aplicativo não agenda nem remarca consultas em unidades de saúde.',
    ),
    (
      Icons.description_outlined,
      'Como organizar meus documentos',
      'Abra Preparo para conferir o checklist de documentos. O histórico contém exemplos demonstrativos. Esta versão não importa resultados de exames.',
    ),
    (
      Icons.notifications_none_rounded,
      'Como configurar lembretes',
      'Na Agenda, toque em Adicionar lembrete. Escreva um título, escolha a antecipação e salve. O registro fica na Agenda; não dispara alarmes.',
    ),
    (
      Icons.medication_outlined,
      'Como adicionar medicamentos',
      'No Perfil, abra Medicamentos e alergias. Toque em Adicionar medicamento e informe somente o que você já possui. Conclua o cadastro e toque em Salvar alterações.',
    ),
    (
      Icons.credit_card_outlined,
      'Como usar o Cartão do SUS',
      'O Perfil mostra um cartão fictício para demonstração. Ele não substitui seu documento e não está conectado ao SUS.',
    ),
  ];
  void _information(String title, String content, {String? subtitle}) =>
      showDialog<void>(
        context: context,
        builder: (context) => AppDialog(
          title: title,
          subtitle:
              subtitle ?? 'Confira as orientações para usar o aplicativo.',
          roundClose: true,
          content: Text(content, style: Theme.of(context).textTheme.bodyLarge),
          actions: AppDialogActions(
            secondaryLabel: 'Fechar',
            onSecondary: () => Navigator.pop(context),
            secondaryOutlined: false,
            primaryLabel: 'Entendi',
            onPrimary: () => Navigator.pop(context),
          ),
        ),
      );
  void _faq() => _information(
    'Perguntas frequentes (FAQ)',
    'Os dados são reais?\nNão. Esta demonstração usa dados fictícios.\n\nAs alterações ficam salvas?\nNa demonstração local, elas duram apenas a sessão. Com o serviço conectado, as alterações confirmadas ficam salvas.\n\nO aplicativo envia informações à unidade?\nNão há integração com unidades ou profissionais.\n\nA IA interpreta exames?\nNão. A organização do relato é simulada e utiliza somente o que você informou. Você pode revisar, editar e excluir o conteúdo; nada é enviado automaticamente.',
  );
  Widget _tutorial(
    String title,
    String text,
    IconData icon,
    Color color,
    Color background,
    String time,
    VoidCallback onTap,
  ) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(AppRadii.large),
    child: AppSurface(
      color: background,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(icon: icon, color: color, background: background, size: 36),
          const SizedBox(height: 8),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.appColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 16, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  time,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: color),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 20),
            ],
          ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final topics = _topics
        .where((t) => '${t.$2} ${t.$3}'.toLowerCase().contains(query))
        .toList();
    return ProfileScaffold(
      title: 'Ajuda',
      subtitle:
          'Encontre respostas, tutoriais e informações para usar o aplicativo.',
      children: [
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Buscar na central de ajuda...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Limpar busca',
                    onPressed: () => setState(_search.clear),
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Tópicos frequentes',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        if (topics.isEmpty)
          const ProfileInfo('Nenhum tópico encontrado. Tente outra palavra.')
        else
          ProfileSection(
            children: [
              for (final entry in topics.indexed) ...[
                if (entry.$1 > 0) const Divider(),
                SettingsOptionTile(
                  icon: entry.$2.$1,
                  title: entry.$2.$2,
                  onTap: () => _information(
                    entry.$2.$2,
                    widget.controller.accessibility.simpleLanguage
                        ? entry.$2.$3
                        : '${entry.$2.$3}\n\nOs dados utilizados neste fluxo são demonstrativos e não são transmitidos a serviços de saúde.',
                    subtitle: entry.$2.$2 == 'Como acompanhar uma consulta'
                        ? 'Veja como acompanhar seu atendimento pelo aplicativo.'
                        : null,
                  ),
                ),
              ],
            ],
          ),
        const SizedBox(height: 20),
        Text('Tutoriais', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final cards = [
              _tutorial(
                'Conheça o app',
                'Veja um passo a passo das principais funções.',
                Icons.play_arrow_outlined,
                context.appColors.primary,
                context.appColors.blueSoft,
                '2 min',
                () => _information(
                  'Conheça o app',
                  '1. Confira o próximo atendimento na Home.\n2. Abra Agenda e veja os detalhes.\n3. Use Preparo para conferir os documentos.\n4. Registre sua resposta de presença.\n5. Consulte seus dados no Perfil.',
                ),
              ),
              _tutorial(
                'Organizar documentos',
                'Confira o que levar para o atendimento.',
                Icons.description_outlined,
                context.appColors.purple,
                context.appColors.purpleSoft,
                '1 min',
                () => context.push(AppRoutes.checklist),
              ),
            ];
            if (constraints.maxWidth < 300 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.2) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [cards[0], const SizedBox(height: 10), cards[1]],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: cards[0]),
                const SizedBox(width: 10),
                Expanded(child: cards[1]),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        Text(
          'Precisa de mais ajuda?',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        ProfileSection(
          children: [
            SettingsOptionTile(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'Falar com o suporte',
              description: 'Informações sobre suporte nesta versão.',
              onTap: () => _information(
                'Falar com o suporte',
                'O atendimento externo de suporte ainda não está disponível nesta demonstração. Consulte os tópicos e as perguntas frequentes para conhecer o aplicativo.',
              ),
            ),
            const Divider(),
            SettingsOptionTile(
              icon: Icons.help_outline_rounded,
              title: 'Perguntas frequentes (FAQ)',
              description: 'Veja respostas para as dúvidas mais comuns.',
              onTap: _faq,
            ),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }
}

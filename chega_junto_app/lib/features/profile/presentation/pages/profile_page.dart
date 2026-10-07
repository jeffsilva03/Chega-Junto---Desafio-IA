import 'package:flutter/material.dart';
import '../../../../app/demo_session.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/state/preparation_controller.dart';
import '../../../../core/widgets/app_bottom_navigation.dart';
import '../../../../core/widgets/app_surface.dart';
import '../../../../core/widgets/preparation_view.dart';
import '../../../../core/widgets/reference_artwork.dart';
import '../../../../data/mock/mock_profile_repository.dart';
import '../../../../data/models/user_profile.dart';
import '../../../../data/repositories/profile_repository.dart';
import '../widgets/profile_menu_group.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.session,
    required this.controller,
    this.repository = const MockProfileRepository(),
  });
  final DemoSession session;
  final PreparationController controller;
  final ProfileRepository repository;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late Future<UserProfile> _profile;
  @override
  void initState() {
    super.initState();
    _profile = widget.repository.loadProfile();
  }

  void _pending(String title) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$title ainda não está disponível nesta versão.'),
        ),
      );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    bottomNavigationBar: const AppBottomNavigation(selectedIndex: 3),
    body: SafeArea(
      bottom: false,
      child: PreparationView(
        controller: widget.controller,
        builder: (context) => FutureBuilder<UserProfile>(
          future: _profile,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Não foi possível carregar seu perfil.'),
                    TextButton(
                      onPressed: () => setState(() {
                        _profile = widget.repository.loadProfile();
                      }),
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final profile = snapshot.data!;
            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 20, 28, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Perfil',
                            style: Theme.of(context).textTheme.headlineLarge,
                          ),
                        ),
                        PopupMenuButton<String>(
                          tooltip: 'Configurações do perfil',
                          icon: const Icon(Icons.settings_outlined, size: 28),
                          onSelected: (_) => widget.session.signOut(),
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'sign-out',
                              child: Text('Sair da demonstração'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _Identity(profile: profile),
                    const SizedBox(height: 22),
                    InkWell(
                      onTap: () => _pending('Cartão do SUS'),
                      borderRadius: BorderRadius.circular(AppRadii.large),
                      child: AppSurface(
                        color: AppColors.blueSoft,
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 68,
                              height: 68,
                              child: ReferenceArtwork(
                                asset: 'assets/images/profile_reference.png',
                                region: Rect.fromLTWH(103, 378, 173, 157),
                                semanticLabel: 'Símbolo do SUS',
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Cartão do SUS',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    profile.susCardNumber,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(letterSpacing: .8),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    widget
                                        .controller
                                        .overview!
                                        .nextAppointment
                                        .facilityName,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge,
                                  ),
                                  Text(
                                    'Unidade de referência',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right_rounded, size: 22),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ProfileMenuGroup(
                      title: 'Meus dados',
                      items: const [
                        (Icons.person_outline_rounded, 'Dados pessoais'),
                      ],
                      onSelect: _pending,
                    ),
                    const SizedBox(height: 20),
                    ProfileMenuGroup(
                      title: 'Minha saúde',
                      items: const [
                        (Icons.medication_outlined, 'Medicamentos e alergias'),
                        (Icons.article_outlined, 'Histórico'),
                      ],
                      onSelect: _pending,
                    ),
                    const SizedBox(height: 20),
                    ProfileMenuGroup(
                      title: 'Configurações',
                      items: const [
                        (Icons.notifications_none_rounded, 'Notificações'),
                        (Icons.accessibility_new_rounded, 'Acessibilidade'),
                        (Icons.help_outline_rounded, 'Ajuda'),
                      ],
                      onSelect: _pending,
                    ),
                    const SizedBox(height: 18),
                    AppSurface(
                      color: AppColors.blueSoft,
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            color: AppColors.primaryDark,
                            size: 24,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              'Seus dados ajudam a organizar sua preparação para o atendimento.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}

class _Identity extends StatelessWidget {
  const _Identity({required this.profile});
  final UserProfile profile;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const CircleAvatar(
        radius: 35,
        backgroundColor: AppColors.blueSoft,
        child: Icon(
          Icons.person_rounded,
          size: 64,
          color: AppColors.primaryDark,
        ),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              profile.fullName,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.tealSoft,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.tealDark,
                    size: 17,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Cadastro atualizado',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.tealDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _Contact(icon: Icons.mail_outline_rounded, text: profile.email),
            const SizedBox(height: 4),
            _Contact(icon: Icons.phone_outlined, text: profile.phone),
          ],
        ),
      ),
    ],
  );
}

class _Contact extends StatelessWidget {
  const _Contact({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 13),
        ),
      ),
    ],
  );
}

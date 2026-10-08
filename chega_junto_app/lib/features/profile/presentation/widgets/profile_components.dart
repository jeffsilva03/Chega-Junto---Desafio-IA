import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/state/profile_controller.dart';
import '../../../../core/widgets/app_bottom_navigation.dart';
import '../../../../core/widgets/app_surface.dart';
import '../../../../data/models/user_profile.dart';
import '../../../../data/models/health_record.dart';

void profileBack(BuildContext context, [String fallback = AppRoutes.profile]) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(fallback);
  }
}

void profileMessage(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));

Future<void> profileInformation(
  BuildContext context,
  String title,
  String content,
) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text(title),
    scrollable: true,
    content: Text(content),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Fechar'),
      ),
    ],
  ),
);

class ProfileView extends StatelessWidget {
  const ProfileView({
    super.key,
    required this.controller,
    required this.builder,
  });
  final ProfileController controller;
  final WidgetBuilder builder;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      if (controller.loading) {
        return const Center(child: CircularProgressIndicator());
      }
      if (controller.failed ||
          controller.profile == null ||
          controller.health == null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Não foi possível carregar seus dados.'),
                TextButton(
                  onPressed: controller.load,
                  child: const Text('Tentar novamente'),
                ),
              ],
            ),
          ),
        );
      }
      return builder(context);
    },
  );
}

class ProfileScaffold extends StatelessWidget {
  const ProfileScaffold({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.action,
    this.inlineHeader = false,
    this.backTo = AppRoutes.profile,
  });
  final String title, backTo;
  final String? subtitle;
  final List<Widget> children;
  final Widget? action;
  final bool inlineHeader;
  @override
  Widget build(BuildContext context) => Scaffold(
    bottomNavigationBar: const AppBottomNavigation(selectedIndex: 3),
    body: SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (inlineHeader)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Voltar',
                      onPressed: () => profileBack(context, backTo),
                      icon: const Icon(Icons.chevron_left_rounded, size: 30),
                    ),
                    Expanded(
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    if (action != null) action! else const SizedBox(width: 48),
                  ],
                )
              else ...[
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Voltar',
                      onPressed: () => profileBack(context, backTo),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const Spacer(),
                    ?action,
                  ],
                ),
                const SizedBox(height: 4),
                Text(title, style: Theme.of(context).textTheme.headlineLarge),
              ],
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: context.appColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              ...children,
            ],
          ),
        ),
      ),
    ),
  );
}

class ProfileSection extends StatelessWidget {
  const ProfileSection({super.key, this.title, required this.children});
  final String? title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => AppSurface(
    border: true,
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null) ...[
          Text(title!, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          const Divider(),
        ],
        ...children,
      ],
    ),
  );
}

class ProfileIdentityCard extends StatelessWidget {
  const ProfileIdentityCard({
    super.key,
    required this.profile,
    required this.message,
  });
  final UserProfile profile;
  final String message;
  @override
  Widget build(BuildContext context) => AppSurface(
    color: context.appColors.blueSoft,
    padding: const EdgeInsets.all(14),
    child: Row(
      children: [
        CircleAvatar(
          radius: 34,
          backgroundColor: context.appColors.dark
              ? const Color(0xFF2C4C72)
              : const Color(0xFFD9E8FF),
          child: Icon(
            Icons.person_rounded,
            size: 62,
            color: context.appColors.primaryDark,
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
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: context.appColors.tealSoft,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: context.appColors.tealDark,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Cadastro atualizado',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: context.appColors.tealDark),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.appColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class ProfileInfo extends StatelessWidget {
  const ProfileInfo(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => AppSurface(
    color: context.appColors.blueSoft,
    padding: const EdgeInsets.all(12),
    child: Row(
      children: [
        Icon(
          Icons.info_outline_rounded,
          color: context.appColors.primary,
          size: 28,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.appColors.textSecondary,
            ),
          ),
        ),
      ],
    ),
  );
}

class SettingsOptionTile extends StatelessWidget {
  const SettingsOptionTile({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.value,
    this.onChanged,
    this.onTap,
    this.trailing,
    this.color,
    this.background,
  });
  final IconData icon;
  final String title;
  final String? description, trailing;
  final bool? value;
  final ValueChanged<bool>? onChanged;
  final VoidCallback? onTap;
  final Color? color, background;
  @override
  Widget build(BuildContext context) {
    final body = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconTile(
            icon: icon,
            color: color ?? context.appColors.primary,
            background: background ?? context.appColors.blueSoft,
            size: 40,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                if (description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    description!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.appColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),
          if (value != null)
            Switch.adaptive(
              value: value!,
              onChanged: onChanged,
              activeTrackColor: context.appColors.primary,
              activeThumbColor: context.appColors.onPrimary,
              materialTapTargetSize: MaterialTapTargetSize.padded,
            )
          else ...[
            if (trailing != null)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 76),
                child: Text(
                  trailing!,
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.appColors.textSecondary,
                  ),
                ),
              ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, size: 22),
          ],
        ],
      ),
    );
    return onTap == null
        ? value == null
              ? body
              : MergeSemantics(child: body)
        : InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadii.medium),
            child: body,
          );
  }
}

(IconData, Color, Color) healthAppearance(
  BuildContext context,
  HealthRecordType type,
) => switch (type) {
  HealthRecordType.consultation => (
    Icons.medical_services_outlined,
    context.appColors.primary,
    context.appColors.blueSoft,
  ),
  HealthRecordType.exam => (
    Icons.description_outlined,
    context.appColors.primary,
    context.appColors.blueSoft,
  ),
  HealthRecordType.medication => (
    Icons.medication_outlined,
    context.appColors.tealDark,
    context.appColors.tealSoft,
  ),
  HealthRecordType.allergy => (
    Icons.bug_report_outlined,
    context.appColors.purple,
    context.appColors.purpleSoft,
  ),
  HealthRecordType.diagnosis => (
    Icons.assignment_outlined,
    context.appColors.error,
    context.appColors.resolve(AppColors.warningSoft),
  ),
};

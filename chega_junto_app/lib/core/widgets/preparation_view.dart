import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/router/app_routes.dart';
import '../../app/theme/app_tokens.dart';
import '../state/preparation_controller.dart';
import 'app_bottom_navigation.dart';
import 'network_feedback.dart';

class PreparationView extends StatelessWidget {
  const PreparationView({
    super.key,
    required this.controller,
    required this.builder,
    this.requiresAppointment = true,
  });
  final PreparationController controller;
  final WidgetBuilder builder;
  final bool requiresAppointment;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      if (controller.loading) {
        return _feedback(
          context,
          const Center(child: CircularProgressIndicator()),
        );
      }
      if (controller.failed || controller.overview == null) {
        return _feedback(
          context,
          NetworkFeedback(error: controller.error, onRetry: controller.load),
        );
      }
      if (requiresAppointment && !controller.overview!.hasNextAppointment) {
        return _feedback(
          context,
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Nenhum próximo atendimento para preparar.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: controller.load,
                    child: const Text('Atualizar atendimentos'),
                  ),
                  TextButton(
                    onPressed: () => context.go(AppRoutes.home),
                    child: const Text('Voltar ao início'),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      return builder(context);
    },
  );

  Widget _feedback(BuildContext context, Widget child) {
    final content = Material(
      color: context.appColors.surface,
      textStyle: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: context.appColors.ink),
      child: SafeArea(child: child),
    );
    if (Scaffold.maybeOf(context) != null) return content;
    return Scaffold(
      backgroundColor: context.appColors.surface,
      body: content,
      bottomNavigationBar: const AppBottomNavigation(selectedIndex: 2),
    );
  }
}

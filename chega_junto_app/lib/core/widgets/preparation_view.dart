import 'package:flutter/material.dart';
import '../state/preparation_controller.dart';
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
        return const Center(child: CircularProgressIndicator());
      }
      if (controller.failed || controller.overview == null) {
        return NetworkFeedback(
          error: controller.error,
          onRetry: controller.load,
        );
      }
      if (requiresAppointment && !controller.overview!.hasNextAppointment) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Nenhum próximo atendimento para preparar.'),
          ),
        );
      }
      return builder(context);
    },
  );
}

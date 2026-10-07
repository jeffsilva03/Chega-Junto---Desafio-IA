import 'package:flutter/material.dart';
import '../state/preparation_controller.dart';

class PreparationView extends StatelessWidget {
  const PreparationView({
    super.key,
    required this.controller,
    required this.builder,
  });
  final PreparationController controller;
  final WidgetBuilder builder;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      if (controller.loading) {
        return const Center(child: CircularProgressIndicator());
      }
      if (controller.failed || controller.overview == null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Não foi possível carregar seu preparo.'),
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

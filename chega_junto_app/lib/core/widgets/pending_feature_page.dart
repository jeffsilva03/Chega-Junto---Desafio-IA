import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/demo_session.dart';
import '../../app/router/app_routes.dart';
import 'app_bottom_navigation.dart';

/// Technical route only; replaced when the next screen is approved.
class PendingFeaturePage extends StatelessWidget {
  const PendingFeaturePage({
    super.key,
    required this.title,
    this.selectedIndex,
    this.session,
  });
  final String title;
  final int? selectedIndex;
  final DemoSession? session;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(title),
      leading: IconButton(
        onPressed: () => context.go(AppRoutes.home),
        tooltip: 'Voltar ao início',
        icon: const Icon(Icons.arrow_back_rounded),
      ),
    ),
    bottomNavigationBar: AppBottomNavigation(selectedIndex: selectedIndex ?? 0),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Esta etapa será implementada no próximo conjunto de telas.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context.go(AppRoutes.home),
              child: const Text('Voltar ao início'),
            ),
            if (session != null)
              TextButton(
                onPressed: session!.signOut,
                child: const Text('Sair da demonstração'),
              ),
          ],
        ),
      ),
    ),
  );
}

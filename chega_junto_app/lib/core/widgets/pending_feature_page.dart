import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/demo_session.dart';
import '../../app/router/app_routes.dart';
import 'app_bottom_navigation.dart';

/// Recovery page for an unknown route.
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
              'Não encontramos esta página. Volte ao início para continuar.',
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

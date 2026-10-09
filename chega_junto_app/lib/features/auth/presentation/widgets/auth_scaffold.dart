import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/widgets/reference_artwork.dart';

/// Shared V2 login identity, including its existing photograph and typography.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.child,
    this.backTo = AppRoutes.welcome,
  });
  final Widget child;
  final String backTo;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.appColors.dark
        ? context.appColors.background
        : const Color(0xFFF0F5FA),
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              children: [
                SizedBox(
                  height:
                      238 *
                      math.max(1, MediaQuery.textScalerOf(context).scale(1)),
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const ReferenceArtwork(
                        asset: 'assets/images/login_reference.png',
                        region: Rect.fromLTWH(174, 7, 124, 197),
                        fit: BoxFit.cover,
                        alignment: Alignment(0, -.25),
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xDE081F28), Color(0x38081F28)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 26,
                        top: 26,
                        child: IconButton(
                          onPressed: () => context.go(backTo),
                          tooltip: backTo == AppRoutes.welcome
                              ? 'Voltar para boas-vindas'
                              : 'Voltar para Login',
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 28,
                        right: 28,
                        bottom: 27,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sua saúde\nmais próxima\nde você',
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    color: Colors.white,
                                    height: 1.04,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: 240,
                              child: Text(
                                'Organize seus atendimentos, prepare-se e chegue mais tranquilo para suas consultas.',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -12),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: context.appColors.surface,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(AppRadii.sheet),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(child: BrandLogo(width: 205)),
                        const SizedBox(height: 24),
                        child,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

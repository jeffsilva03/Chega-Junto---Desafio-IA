import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/reference_artwork.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: DecoratedBox(
      decoration: BoxDecoration(color: context.appColors.surface),
      child: Stack(
        children: [
          const Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _WelcomeBackground()),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 24, 28, 12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const BrandLogo(width: 178, stacked: true),
                        const SizedBox(height: 24),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: 'Seu cuidado\n'),
                              TextSpan(
                                text: 'começa antes\n',
                                style: TextStyle(
                                  color: context.appColors.primary,
                                ),
                              ),
                              TextSpan(text: 'da consulta'),
                            ],
                          ),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineLarge
                              ?.copyWith(
                                fontSize: 34,
                                height: 1.08,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Organize documentos, confirme presença e chegue mais preparado para consultas e exames do SUS.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: context.appColors.textSecondary,
                              ),
                        ),
                        const SizedBox(height: 12),
                        const SizedBox(
                          height: 205,
                          width: double.infinity,
                          child: ReferenceArtwork(
                            asset: 'assets/images/welcome_reference.png',
                            region: Rect.fromLTWH(30, 874, 873, 510),
                            dateLabel: '9 de out. · 08:00',
                            semanticLabel:
                                'Agenda, documentos e confirmação de presença organizados no aplicativo.',
                          ),
                        ),
                        const SizedBox(height: 6),
                        const _PageIndicators(),
                        const SizedBox(height: 18),
                        AppButton(
                          label: 'Começar',
                          onPressed: () => context.go(AppRoutes.login),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => context.go(AppRoutes.login),
                          child: const Text('Já tenho conta'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _PageIndicators extends StatelessWidget {
  const _PageIndicators();
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        3,
        (index) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: index == 0
                ? context.appColors.primary
                : const Color(0xFFD1DDEE),
          ),
        ),
      ),
    ),
  );
}

class _WelcomeBackground extends CustomPainter {
  const _WelcomeBackground();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      Offset(-44, -36),
      150,
      Paint()..color = const Color(0xFFCEF8F4),
    );
    canvas.drawCircle(
      Offset(size.width + 36, size.height * .17),
      86,
      Paint()..color = const Color(0xFFFFF3DE),
    );
    canvas.drawCircle(
      Offset(size.width + 78, size.height + 60),
      137,
      Paint()..color = const Color(0xFFC8F4F0),
    );
  }

  @override
  bool shouldRepaint(_WelcomeBackground oldDelegate) => false;
}

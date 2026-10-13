import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/state/report_controller.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../features/pre_visit_report/presentation/widgets/report_components.dart';

class ReportProcessingPage extends StatefulWidget {
  const ReportProcessingPage({super.key, required this.controller});
  final ReportController controller;
  @override
  State<ReportProcessingPage> createState() => _ReportProcessingPageState();
}

class _ReportProcessingPageState extends State<ReportProcessingPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _run();
    });
  }

  Future<void> _run() async {
    if (widget.controller.text.trim().isEmpty) {
      context.replace(AppRoutes.report);
      reportMessage(context, 'Escreva seu relato antes de organizar.');
      return;
    }
    final success = await widget.controller.organize();
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    if (success) {
      context.replace(AppRoutes.summary);
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    if (widget.controller.processing) {
      widget.controller.cancelProcessing(notify: false);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ReportScaffold(
    controller: widget.controller,
    title: 'Organizando seu relato...',
    subtitle:
        'Estamos reunindo apenas o que você contou. Você poderá revisar e editar o resultado.',
    children: [
      const SizedBox(height: 50),
      if (widget.controller.failed) ...[
        Icon(Icons.refresh_rounded, size: 52, color: context.appColors.primary),
        const SizedBox(height: 20),
        Text(
          userError(
            widget.controller.organizationError,
            'Não foi possível organizar seu relato. O texto continua salvo nesta sessão.',
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        AppButton(
          label: 'Tentar novamente',
          onPressed: () {
            setState(() {});
            _run();
          },
        ),
      ] else ...[
        const Center(
          child: SizedBox(
            width: 54,
            height: 54,
            child: CircularProgressIndicator(
              semanticsLabel: 'Organizando seu relato',
            ),
          ),
        ),
        const SizedBox(height: 28),
        Semantics(
          liveRegion: true,
          child: Text(
            widget.controller.realAudio
                ? 'Este conteúdo é processado por IA. Revise e edite antes de continuar.'
                : 'Organização demonstrativa, sem conexão com serviços de IA.',
            textAlign: TextAlign.center,
          ),
        ),
      ],
      const SizedBox(height: 28),
      AppButton(
        label: 'Voltar ao relato',
        outlined: true,
        icon: null,
        onPressed: () => reportBack(context, AppRoutes.report),
      ),
    ],
  );
}

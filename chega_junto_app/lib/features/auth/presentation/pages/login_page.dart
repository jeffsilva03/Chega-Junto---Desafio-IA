import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/demo_session.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/reference_artwork.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.session});
  final DemoSession session;
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _identity = TextEditingController();
  final _password = TextEditingController();
  bool _obscured = true;
  bool _busy = false;
  String? _failure;

  @override
  void dispose() {
    _identity.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn({bool google = false}) async {
    if (_busy || (!google && !_form.currentState!.validate())) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await widget.session.signIn();
      if (!mounted) return;
      _identity.clear();
      _password.clear();
      context.go(AppRoutes.home);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _failure = 'Não foi possível abrir a demonstração. Tente novamente.';
        });
      }
    }
  }

  Future<void> _recovery() async {
    final identity = TextEditingController();
    final form = GlobalKey<FormState>();
    var completed = false;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(
            completed ? 'Demonstração concluída' : 'Recuperar acesso',
          ),
          content: completed
              ? const Text(
                  'Em uma versão com autenticação real, você receberá orientações para recuperar o acesso. Nesta demonstração, nenhum e-mail foi enviado.',
                )
              : Form(
                  key: form,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Use um e-mail fictício para conhecer o fluxo.',
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: identity,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'E-mail fictício',
                        ),
                        validator: (value) =>
                            (value?.contains('@') ?? false) &&
                                (value?.contains('.') ?? false)
                            ? null
                            : 'Informe um e-mail fictício válido.',
                      ),
                    ],
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(completed ? 'Fechar' : 'Voltar'),
            ),
            if (!completed)
              TextButton(
                onPressed: () {
                  if (form.currentState!.validate()) {
                    update(() => completed = true);
                  }
                },
                child: const Text('Ver demonstração'),
              ),
          ],
        ),
      ),
    );
    // Wait for the closing animation before disposing the field controller.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    identity.dispose();
  }

  void _registration() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Primeiro acesso'),
      content: const Text(
        'Você pode conhecer o Chega Junto com o perfil fictício de Maria. O cadastro será preparado em uma próxima etapa.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Voltar'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            _signIn(google: true);
          },
          child: const Text('Conhecer o aplicativo'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF0F5FA),
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              children: [
                SizedBox(
                  height: 238,
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
                          onPressed: () => context.go(AppRoutes.welcome),
                          tooltip: 'Voltar para boas-vindas',
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
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(AppRadii.sheet),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
                    child: Form(
                      key: _form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Center(child: BrandLogo(width: 205)),
                          const SizedBox(height: 24),
                          Text(
                            'Entrar na sua conta',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Informe seus dados para continuar.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 18),
                          TextFormField(
                            key: const Key('login-identity'),
                            controller: _identity,
                            enabled: !_busy,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autocorrect: false,
                            decoration: const InputDecoration(
                              labelText: 'E-mail ou CPF',
                              prefixIcon: Icon(
                                Icons.mail_outline_rounded,
                                size: 20,
                              ),
                            ),
                            validator: (value) {
                              final text = value?.trim() ?? '';
                              if (text.isEmpty) {
                                return 'Informe um e-mail ou CPF fictício.';
                              }
                              if (RegExp(r'^\d{11}$').hasMatch(
                                    text.replaceAll(RegExp(r'[.\-\s]'), ''),
                                  ) ||
                                  RegExp(
                                    r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                  ).hasMatch(text)) {
                                return null;
                              }
                              return 'Use um e-mail ou CPF fictício válido.';
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            key: const Key('login-password'),
                            controller: _password,
                            enabled: !_busy,
                            obscureText: _obscured,
                            enableSuggestions: false,
                            autocorrect: false,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _signIn(),
                            decoration: InputDecoration(
                              labelText: 'Senha',
                              prefixIcon: const Icon(
                                Icons.lock_outline_rounded,
                                size: 20,
                              ),
                              suffixIcon: IconButton(
                                tooltip: _obscured
                                    ? 'Mostrar senha'
                                    : 'Ocultar senha',
                                onPressed: _busy
                                    ? null
                                    : () => setState(
                                        () => _obscured = !_obscured,
                                      ),
                                icon: Icon(
                                  _obscured
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  size: 20,
                                ),
                              ),
                            ),
                            validator: (value) => (value?.length ?? 0) >= 4
                                ? null
                                : 'Use uma senha fictícia com pelo menos 4 caracteres.',
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _busy ? null : _recovery,
                              child: const Text('Esqueci minha senha?'),
                            ),
                          ),
                          if (_failure != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                _failure!,
                                style: const TextStyle(color: AppColors.error),
                              ),
                            ),
                          AppButton(
                            key: const Key('login-submit'),
                            label: _busy ? 'Entrando...' : 'Entrar',
                            color: AppColors.primaryDark,
                            busy: _busy,
                            onPressed: _signIn,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Expanded(child: Divider()),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Text(
                                  'ou',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                              const Expanded(child: Divider()),
                            ],
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton(
                            onPressed: _busy
                                ? null
                                : () => _signIn(google: true),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 48),
                              foregroundColor: AppColors.ink,
                              side: const BorderSide(color: Color(0xFFCAD6E6)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadii.medium,
                                ),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _GoogleMark(),
                                SizedBox(width: 14),
                                Flexible(child: Text('Entrar com Google')),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'Ainda não tem conta?',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              TextButton(
                                onPressed: _busy ? null : _registration,
                                child: const Text('Cadastre-se'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Acesso demonstrativo · dados fictícios\nUse um e-mail fictício e uma senha de 4 caracteres ou mais.',
                            textAlign: TextAlign.center,
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(fontSize: 12),
                          ),
                        ],
                      ),
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

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();
  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 22,
    height: 22,
    child: CustomPaint(painter: _GoogleMarkPainter()),
  );
}

class _GoogleMarkPainter extends CustomPainter {
  const _GoogleMarkPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(3, 3, 16, 16);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.2;
    for (final part in [
      (const Color(0xFF4285F4), -.15, 1.05),
      (const Color(0xFF34A853), .9, 1.6),
      (const Color(0xFFFBBC05), 2.5, 1.15),
      (const Color(0xFFEA4335), 3.65, 1.85),
    ]) {
      canvas.drawArc(rect, part.$2, part.$3, false, paint..color = part.$1);
    }
    canvas.drawLine(
      const Offset(11, 11),
      const Offset(21, 11),
      paint..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(_GoogleMarkPainter oldDelegate) => false;
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/demo_session.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../data/repositories/auth_repository.dart';
import '../widgets/auth_scaffold.dart';

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key, required this.session});
  final DemoSession session;
  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _email = TextEditingController(),
      _password = TextEditingController(),
      _confirmation = TextEditingController();
  bool _busy = false, _hidden = true, _confirmHidden = true;
  String? _error;
  @override
  void dispose() {
    for (final field in [_name, _email, _password, _confirmation]) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _register() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.register(_name.text, _email.text, _password.text);
      if (!mounted || !widget.session.signedIn) return;
      for (final field in [_name, _email, _password, _confirmation]) {
        field.clear();
      }
      context.go(AppRoutes.home);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = userError(
            e,
            'Não foi possível criar a conta. Tente novamente.',
          );
        });
      }
    }
  }

  Widget _secret({required bool confirmation}) => TextFormField(
    key: Key(confirmation ? 'register-confirmation' : 'register-password'),
    controller: confirmation ? _confirmation : _password,
    enabled: !_busy,
    obscureText: confirmation ? _confirmHidden : _hidden,
    enableSuggestions: false,
    autocorrect: false,
    autofillHints: const [AutofillHints.newPassword],
    textInputAction: confirmation ? TextInputAction.done : TextInputAction.next,
    onFieldSubmitted: confirmation ? (_) => _register() : null,
    decoration: InputDecoration(
      labelText: confirmation ? 'Confirmar senha' : 'Senha',
      prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
      suffixIcon: IconButton(
        tooltip: (confirmation ? _confirmHidden : _hidden)
            ? 'Mostrar senha'
            : 'Ocultar senha',
        onPressed: _busy
            ? null
            : () => setState(() {
                if (confirmation) {
                  _confirmHidden = !_confirmHidden;
                } else {
                  _hidden = !_hidden;
                }
              }),
        icon: Icon(
          (confirmation ? _confirmHidden : _hidden)
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
          size: 20,
        ),
      ),
    ),
    validator: confirmation
        ? (value) => value == _password.text ? null : 'As senhas não coincidem.'
        : validateRegistrationPassword,
  );
  @override
  Widget build(BuildContext context) => AuthScaffold(
    backTo: AppRoutes.login,
    child: AutofillGroup(
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Criar sua conta',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 2),
            Text(
              'Informe seus dados para começar.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 18),
            TextFormField(
              key: const Key('register-name'),
              controller: _name,
              enabled: !_busy,
              autofillHints: const [AutofillHints.name],
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Nome completo',
                prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
              ),
              validator: (value) =>
                  (value?.trim().isNotEmpty ?? false) &&
                      value!.trim().runes.length <= 160
                  ? null
                  : 'Informe seu nome completo (até 160 caracteres).',
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('register-email'),
              controller: _email,
              enabled: !_busy,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'E-mail',
                prefixIcon: Icon(Icons.mail_outline_rounded, size: 20),
              ),
              validator: (value) =>
                  (value?.trim().length ?? 0) <= 254 &&
                      RegExp(
                        r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                      ).hasMatch(value?.trim() ?? '')
                  ? null
                  : 'Informe um e-mail válido.',
            ),
            const SizedBox(height: 12),
            _secret(confirmation: false),
            const SizedBox(height: 12),
            _secret(confirmation: true),
            const SizedBox(height: 16),
            Text(
              'Use uma senha entre 8 e 128 caracteres.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: context.appColors.error),
                ),
              ),
            const SizedBox(height: 18),
            AppButton(
              key: const Key('register-submit'),
              label: _busy ? 'Criando conta...' : 'Criar conta',
              color: context.appColors.primaryDark,
              busy: _busy,
              onPressed: _register,
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Já tem uma conta?',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                TextButton(
                  onPressed: _busy ? null : () => context.go(AppRoutes.login),
                  child: const Text('Entrar'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.session.repository.supportsDemo
                  ? 'Cadastro demonstrativo · dados fictícios'
                  : 'Use somente dados fictícios nesta versão.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ),
  );
}

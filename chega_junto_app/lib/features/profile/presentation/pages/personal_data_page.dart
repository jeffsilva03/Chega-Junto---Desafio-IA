import 'package:flutter/material.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/state/profile_controller.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../data/models/user_profile.dart';
import '../widgets/profile_components.dart';

class PersonalDataPage extends StatefulWidget {
  const PersonalDataPage({super.key, required this.controller});
  final ProfileController controller;
  @override
  State<PersonalDataPage> createState() => _PersonalDataPageState();
}

class _PersonalDataPageState extends State<PersonalDataPage> {
  final _form = GlobalKey<FormState>();
  Map<String, TextEditingController>? _fields;
  bool _editing = false, _saving = false;
  String? _error;
  void _initialize(UserProfile profile) {
    _fields ??= {
      for (final entry in {
        'name': profile.fullName,
        'birth': profile.birthDate,
        'cpf': profile.cpf,
        'phone': profile.phone,
        'email': profile.email,
        'postcode': profile.postcode,
        'street': profile.street,
        'number': profile.number,
        'complement': profile.complement,
        'neighborhood': profile.neighborhood,
        'city': profile.city,
        'emergencyName': profile.emergencyName,
        'relationship': profile.emergencyRelationship,
        'emergencyPhone': profile.emergencyPhone,
      }.entries)
        entry.key: TextEditingController(text: entry.value),
    };
  }

  String _text(String key) => _fields![key]!.text.trim();
  String? _validate(String key, String? raw) {
    final value = (raw ?? '').trim();
    if (key == 'complement') return null;
    if (value.isEmpty) return 'Preencha este campo.';
    if (key == 'email' &&
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)) {
      return 'Confira o e-mail.';
    }
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if ((key == 'phone' || key == 'emergencyPhone') &&
        (digits.length < 10 || digits.length > 11)) {
      return 'Use DDD e telefone.';
    }
    if (key == 'cpf' && digits.length != 11) return 'Use os 11 dígitos.';
    if (key == 'postcode' && digits.length != 8) return 'Use os 8 dígitos.';
    if (key == 'birth') {
      final match = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(value);
      if (match == null) return 'Use DD/MM/AAAA.';
      final day = int.parse(match[1]!),
          month = int.parse(match[2]!),
          year = int.parse(match[3]!);
      final date = DateTime(year, month, day);
      if (date.day != day ||
          date.month != month ||
          year < 1900 ||
          date.isAfter(DateTime(2026, 10, 7))) {
        return 'Confira a data.';
      }
    }
    return null;
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_editing && !(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final profile = widget.controller.profile!.copyWith(
      fullName: _text('name'),
      birthDate: _text('birth'),
      cpf: _text('cpf'),
      phone: _text('phone'),
      email: _text('email'),
      postcode: _text('postcode'),
      street: _text('street'),
      number: _text('number'),
      complement: _text('complement'),
      neighborhood: _text('neighborhood'),
      city: _text('city'),
      emergencyName: _text('emergencyName'),
      emergencyRelationship: _text('relationship'),
      emergencyPhone: _text('emergencyPhone'),
    );
    try {
      await widget.controller.saveProfile(profile);
      if (!mounted) return;
      setState(() => _editing = false);
      profileMessage(context, 'Dados salvos nesta sessão.');
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Não foi possível salvar. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _section(
    String title,
    List<(String, IconData, String)> rows,
  ) => ProfileSection(
    title: title,
    children: [
      for (final entry in rows.indexed) ...[
        if (entry.$1 > 0)
          const Padding(padding: EdgeInsets.only(left: 36), child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(entry.$2.$2, color: context.appColors.primary, size: 24),
              const SizedBox(width: 12),
              Expanded(
                flex: 4,
                child: Text(
                  entry.$2.$3,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 5,
                child: _editing
                    ? TextFormField(
                        key: ValueKey('personal-${entry.$2.$1}'),
                        controller: _fields![entry.$2.$1],
                        style: Theme.of(context).textTheme.bodyMedium,
                        enabled: !_saving,
                        validator: (value) => _validate(entry.$2.$1, value),
                        keyboardType: entry.$2.$1 == 'email'
                            ? TextInputType.emailAddress
                            : entry.$2.$1.toLowerCase().contains('phone')
                            ? TextInputType.phone
                            : TextInputType.text,
                        decoration: InputDecoration(
                          labelText: entry.$2.$3,
                          contentPadding: const EdgeInsets.all(10),
                        ),
                      )
                    : Text(
                        _text(entry.$2.$1),
                        textAlign: TextAlign.right,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: context.appColors.textSecondary,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ],
    ],
  );
  @override
  Widget build(BuildContext context) => ProfileView(
    controller: widget.controller,
    builder: (context) {
      final profile = widget.controller.profile!;
      _initialize(profile);
      return ProfileScaffold(
        title: 'Dados pessoais',
        inlineHeader: true,
        action: TextButton(
          onPressed: _saving
              ? null
              : () {
                  if (_editing && !(_form.currentState?.validate() ?? false)) {
                    return;
                  }
                  setState(() => _editing = !_editing);
                },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.edit_outlined, size: 20),
              const SizedBox(width: 4),
              Text(_editing ? 'Conferir' : 'Editar'),
            ],
          ),
        ),
        children: [
          Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ProfileIdentityCard(
                  profile: profile,
                  message: 'Confira e mantenha seus dados corretos.',
                ),
                const SizedBox(height: 12),
                _section('Informações pessoais', const [
                  ('name', Icons.person_outline_rounded, 'Nome completo'),
                  (
                    'birth',
                    Icons.calendar_today_outlined,
                    'Data de nascimento',
                  ),
                  ('cpf', Icons.badge_outlined, 'CPF'),
                  ('phone', Icons.phone_outlined, 'Telefone'),
                  ('email', Icons.mail_outline_rounded, 'E-mail'),
                ]),
                const SizedBox(height: 12),
                _section('Endereço', const [
                  ('postcode', Icons.location_on_outlined, 'CEP'),
                  ('street', Icons.home_outlined, 'Rua / Avenida'),
                  ('number', Icons.tag_rounded, 'Número'),
                  ('complement', Icons.notes_rounded, 'Complemento'),
                  ('neighborhood', Icons.map_outlined, 'Bairro'),
                  ('city', Icons.location_city_outlined, 'Cidade / UF'),
                ]),
                const SizedBox(height: 12),
                _section('Contato de emergência', const [
                  ('emergencyName', Icons.person_outline_rounded, 'Nome'),
                  ('relationship', Icons.people_outline_rounded, 'Relação'),
                  ('emergencyPhone', Icons.phone_outlined, 'Telefone'),
                ]),
                const SizedBox(height: 12),
                const ProfileInfo(
                  'Dados fictícios para organizar sua preparação. Alterações ficam somente nesta sessão.',
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _error!,
                      style: TextStyle(color: context.appColors.error),
                    ),
                  ),
                const SizedBox(height: 12),
                AppButton(
                  label: 'Salvar alterações',
                  icon: null,
                  busy: _saving,
                  onPressed: _save,
                ),
                TextButton(
                  onPressed: () => profileBack(context),
                  child: const Text('Voltar ao perfil'),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
  @override
  void dispose() {
    for (final field in _fields?.values ?? <TextEditingController>[]) {
      field.dispose();
    }
    super.dispose();
  }
}

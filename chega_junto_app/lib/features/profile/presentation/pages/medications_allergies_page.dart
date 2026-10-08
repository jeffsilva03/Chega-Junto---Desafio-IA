import 'package:flutter/material.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/state/profile_controller.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_surface.dart';
import '../../../../core/widgets/medication_icon.dart';
import '../../../../data/models/health_record.dart';
import '../widgets/profile_components.dart';

class MedicationsAllergiesPage extends StatefulWidget {
  const MedicationsAllergiesPage({super.key, required this.controller});
  final ProfileController controller;
  @override
  State<MedicationsAllergiesPage> createState() =>
      _MedicationsAllergiesPageState();
}

class _MedicationsAllergiesPageState extends State<MedicationsAllergiesPage> {
  List<HealthItem>? _medications, _allergies;
  bool _editing = false, _saving = false, _dirty = false;
  String? _error;
  Future<void> _edit(bool medication, [HealthItem? current]) async {
    final result = await showDialog<HealthItem>(
      context: context,
      builder: (context) =>
          _HealthItemEditor(medication: medication, item: current),
    );
    if (result == null || !mounted) return;
    setState(() {
      final items = medication ? _medications! : _allergies!;
      final index = items.indexWhere((item) => item.id == result.id);
      if (index < 0) {
        items.add(result);
      } else {
        items[index] = result;
      }
      _dirty = true;
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.controller.saveHealth(_medications!, _allergies!);
      if (!mounted) return;
      setState(() {
        _dirty = false;
        _editing = false;
      });
      profileMessage(context, 'Medicamentos e alergias salvos nesta sessão.');
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Não foi possível salvar. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _section(bool medication) {
    final items = medication ? _medications! : _allergies!;
    return ProfileSection(
      title: medication ? 'Medicamentos em uso' : 'Alergias',
      children: [
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(
              medication
                  ? 'Nenhum medicamento cadastrado.'
                  : 'Nenhuma alergia informada.',
            ),
          ),
        for (final indexed in items.indexed) ...[
          if (indexed.$1 > 0)
            const Padding(padding: EdgeInsets.only(left: 36), child: Divider()),
          InkWell(
            onTap: _saving ? null : () => _edit(medication, indexed.$2),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  if (medication)
                    MedicationIcon(color: context.appColors.primary, size: 26)
                  else
                    Icon(
                      Icons.warning_amber_rounded,
                      color: context.appColors.primary,
                      size: 26,
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 4,
                    child: Text(
                      indexed.$2.name,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 5,
                    child: Text(
                      indexed.$2.details,
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.appColors.textSecondary,
                      ),
                    ),
                  ),
                  if (_editing)
                    IconButton(
                      tooltip: 'Remover ${indexed.$2.name}',
                      onPressed: _saving
                          ? null
                          : () => setState(() {
                              items.removeAt(indexed.$1);
                              _dirty = true;
                            }),
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: context.appColors.error,
                        size: 22,
                      ),
                    )
                  else
                    const Icon(Icons.chevron_right_rounded, size: 22),
                ],
              ),
            ),
          ),
        ],
        AppSurface(
          color: context.appColors.blueSoft,
          padding: const EdgeInsets.all(10),
          child: Text(
            '${items.length} ${medication ? 'medicamentos cadastrados' : 'alergias informadas'}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.appColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _saving ? null : () => _edit(medication),
          icon: const Icon(Icons.add_rounded),
          label: Text(
            medication ? 'Adicionar medicamento' : 'Adicionar alergia',
          ),
          style: OutlinedButton.styleFrom(
            backgroundColor: context.appColors.blueSoft,
            foregroundColor: context.appColors.primary,
            side: BorderSide(color: context.appColors.border),
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.medium),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => ProfileView(
    controller: widget.controller,
    builder: (context) {
      _medications ??= List.of(widget.controller.health!.medications);
      _allergies ??= List.of(widget.controller.health!.allergies);
      return ProfileScaffold(
        title: 'Medicamentos e alergias',
        inlineHeader: true,
        action: TextButton(
          onPressed: _saving
              ? null
              : () => setState(() => _editing = !_editing),
          child: const Text('Editar'),
        ),
        children: [
          ProfileIdentityCard(
            profile: widget.controller.profile!,
            message: 'Mantenha essas informações sempre corretas.',
          ),
          const SizedBox(height: 12),
          _section(true),
          const SizedBox(height: 12),
          _section(false),
          const SizedBox(height: 12),
          const ProfileInfo(
            'Informações fictícias para organização pessoal. Não são recomendações do aplicativo.',
          ),
          if (_dirty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Há alterações para salvar.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
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
      );
    },
  );
}

class _HealthItemEditor extends StatefulWidget {
  const _HealthItemEditor({required this.medication, this.item});
  final bool medication;
  final HealthItem? item;
  @override
  State<_HealthItemEditor> createState() => _HealthItemEditorState();
}

class _HealthItemEditorState extends State<_HealthItemEditor> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.item?.name);
  late final _details = TextEditingController(text: widget.item?.details);
  void _save() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(
      context,
      HealthItem(
        id: widget.item?.id ?? 'local-${DateTime.now().microsecondsSinceEpoch}',
        name: _name.text.trim(),
        details: _details.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(
      '${widget.item == null ? 'Adicionar' : 'Editar'} ${widget.medication ? 'medicamento' : 'alergia'}',
    ),
    content: Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            key: const ValueKey('health-item-name'),
            controller: _name,
            maxLength: 80,
            decoration: const InputDecoration(labelText: 'Nome'),
            validator: (v) =>
                (v ?? '').trim().isEmpty ? 'Informe o nome.' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const ValueKey('health-item-details'),
            controller: _details,
            maxLength: 160,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: widget.medication
                  ? 'Uso informado por você'
                  : 'Reação informada por você',
            ),
            validator: (v) => (v ?? '').trim().isEmpty
                ? 'Informe os detalhes do registro.'
                : null,
          ),
          const Text('Preencha somente informações que você já possui.'),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      TextButton(
        key: const ValueKey('health-item-save'),
        onPressed: _save,
        child: const Text('Concluir'),
      ),
    ],
  );
  @override
  void dispose() {
    _name.dispose();
    _details.dispose();
    super.dispose();
  }
}

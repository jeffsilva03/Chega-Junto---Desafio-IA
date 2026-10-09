import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/state/preparation_controller.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../data/models/appointment_reminder.dart';

class NewReminderPopover extends StatefulWidget {
  const NewReminderPopover({
    super.key,
    required this.controller,
    required this.anchor,
    required this.footerTop,
  });
  final PreparationController controller;
  final Rect anchor;
  final double footerTop;
  @override
  State<NewReminderPopover> createState() => _NewReminderPopoverState();
}

class _NewReminderPopoverState extends State<NewReminderPopover> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title;
  ReminderTiming _timing = ReminderTiming.dayBefore;
  bool _saving = false;
  bool _uncertain = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(
      text: widget.controller.reminders.isEmpty
          ? ''
          : widget.controller.reminders.first.title,
    );
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _uncertain) return;
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final appointment = widget.controller.overview!.nextAppointment;
    try {
      await widget.controller.addReminder(
        AppointmentReminder(
          id: 'local-${DateTime.now().microsecondsSinceEpoch}',
          title: _title.text.trim(),
          dateTime: _timing.dateFor(appointment.dateTime),
          appointmentId: appointment.id,
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _uncertain = e is NetworkException && e.uncertain;
          _error = _uncertain
              ? 'Não foi possível confirmar o salvamento. Confira a Agenda antes de criar outro lembrete.'
              : userError(e, 'Não foi possível salvar. Tente novamente.');
        });
      }
    }
  }

  Future<void> _checkAgenda() async {
    setState(() => _saving = true);
    await widget.controller.load();
    if (!mounted) return;
    if (widget.controller.failed) {
      setState(() {
        _saving = false;
        _error = 'Não foi possível conferir a Agenda. Tente novamente.';
      });
    } else {
      Navigator.pop(context, false);
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final media = MediaQuery.of(context);
      final frameWidth = math.min(AppLayout.maxWidth, constraints.maxWidth);
      final frameLeft = (constraints.maxWidth - frameWidth) / 2;
      final width = math.min(340.0, frameWidth - AppSpacing.page * 2);
      final left = (widget.anchor.right - width).clamp(
        frameLeft + AppSpacing.page,
        frameLeft + frameWidth - AppSpacing.page - width,
      );
      final safeTop = media.padding.top + AppSpacing.md;
      final safeBottom = math.min(
        widget.footerTop - AppSpacing.md,
        constraints.maxHeight -
            media.viewInsets.bottom -
            media.padding.bottom -
            AppSpacing.md,
      );
      // Keep the card above its trigger; lift it when the keyboard appears.
      final availableHeight = math.max(48.0, safeBottom - safeTop - 10);
      final anchoredAbove =
          widget.anchor.top - 12 - safeTop >=
          math.min(360.0, availableHeight * .8);
      final bottom = anchoredAbove
          ? math.min(widget.anchor.top - 12, safeBottom)
          : safeBottom;
      final usableHeight = math.max(48.0, bottom - safeTop - 10);
      final pointer = (widget.anchor.center.dx - left - 10).clamp(
        20.0,
        width - 40,
      );
      return Stack(
        children: [
          Positioned(
            left: left,
            width: width,
            bottom: constraints.maxHeight - bottom,
            child: Semantics(
              scopesRoute: true,
              explicitChildNodes: true,
              namesRoute: true,
              label: 'Novo lembrete',
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    key: const Key('new-reminder-card'),
                    decoration: BoxDecoration(
                      color: context.appColors.surface,
                      borderRadius: BorderRadius.circular(AppRadii.sheet),
                      border: Border.all(color: context.appColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: context.appColors.ink.withValues(alpha: .12),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: usableHeight),
                        child: Form(
                          key: _form,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    16,
                                    16,
                                    0,
                                  ),
                                  child: _content(context),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: _actions(context),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (anchoredAbove)
                    Positioned(
                      bottom: -10,
                      left: pointer,
                      child: SizedBox(
                        width: 20,
                        height: 12,
                        child: CustomPaint(
                          painter: _PointerPainter(context.appColors),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );

  Widget _content(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Novo lembrete', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 5),
      Text(
        'Crie um lembrete rápido para este compromisso.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: context.appColors.textSecondary,
        ),
      ),
      const SizedBox(height: 16),
      Text(
        'Título',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: context.appColors.textSecondary,
        ),
      ),
      const SizedBox(height: 5),
      TextFormField(
        key: const Key('reminder-title'),
        controller: _title,
        maxLength: 80,
        enabled: !_saving,
        textInputAction: TextInputAction.done,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          counterText: '',
          hintText: 'Levar documento com foto',
          suffixIcon: _title.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Limpar título',
                  onPressed: _saving ? null : () => setState(_title.clear),
                  icon: Icon(
                    Icons.cancel_rounded,
                    color: context.appColors.muted,
                    size: 20,
                  ),
                ),
        ),
        validator: (value) => (value?.trim().isNotEmpty ?? false)
            ? null
            : 'Escreva seu lembrete.',
      ),
      const SizedBox(height: 16),
      Text('Quando lembrar?', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final timing in ReminderTiming.values)
            ChoiceChip(
              key: Key('reminder-timing-${timing.name}'),
              label: Text(timing.label),
              selected: _timing == timing,
              onSelected: _saving
                  ? null
                  : (_) => setState(() => _timing = timing),
              showCheckmark: false,
              selectedColor: context.appColors.blueSoft,
              backgroundColor: context.appColors.surface,
              surfaceTintColor: Colors.transparent,
              side: BorderSide(
                color: _timing == timing
                    ? context.appColors.primary
                    : context.appColors.border,
              ),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
              labelStyle: TextStyle(
                fontFamily: 'NunitoSans',
                fontSize: 13,
                color: _timing == timing
                    ? context.appColors.primary
                    : context.appColors.textSecondary,
                fontWeight: _timing == timing
                    ? FontWeight.w800
                    : FontWeight.w400,
              ),
            ),
        ],
      ),
      if (_error != null) ...[
        const SizedBox(height: 8),
        Text(_error!, style: TextStyle(color: context.appColors.error)),
      ],
    ],
  );

  Widget _actions(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AppButton(
              key: const Key('reminder-save'),
              label: _saving
                  ? (_uncertain ? 'Carregando...' : 'Salvando...')
                  : (_uncertain ? 'Conferir Agenda' : 'Salvar'),
              icon: null,
              busy: _saving,
              onPressed: _uncertain ? _checkAgenda : _save,
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Text(
        'Fica na Agenda; não dispara notificações.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );
}

class _PointerPainter extends CustomPainter {
  const _PointerPainter(this.colors);
  final AppPalette colors;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = colors.surface);
    canvas.drawPath(
      Path()
        ..moveTo(0, 1)
        ..lineTo(size.width / 2, size.height)
        ..lineTo(size.width, 1),
      Paint()
        ..color = colors.border
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_PointerPainter oldDelegate) =>
      colors != oldDelegate.colors;
}

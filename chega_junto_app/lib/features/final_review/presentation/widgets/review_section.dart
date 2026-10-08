import 'package:flutter/material.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/widgets/app_surface.dart';

class ReviewSection extends StatefulWidget {
  const ReviewSection({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.children,
    this.initiallyExpanded = false,
    this.teal = false,
  });
  final String title, subtitle;
  final IconData icon;
  final List<Widget> children;
  final bool initiallyExpanded, teal;

  @override
  State<ReviewSection> createState() => _ReviewSectionState();
}

class _ReviewSectionState extends State<ReviewSection> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) => AppSurface(
    border: true,
    padding: EdgeInsets.zero,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: _expanded,
          label: '${widget.title}. ${widget.subtitle}',
          excludeSemantics: true,
          child: InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(AppRadii.large),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconTile(
                    icon: widget.icon,
                    size: 42,
                    color: widget.teal
                        ? context.appColors.tealDark
                        : context.appColors.primary,
                    background: widget.teal
                        ? context.appColors.tealSoft
                        : context.appColors.blueSoft,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.subtitle,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: context.appColors.textSecondary,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: context.appColors.ink,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: widget.children,
            ),
          ),
      ],
    ),
  );
}

import 'package:flutter/material.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../data/models/appointment.dart';

class AttendanceOptionTile extends StatelessWidget {
  const AttendanceOptionTile({
    super.key,
    required this.status,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });
  final ConfirmationStatus status;
  final String title;
  final String description;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$title. $description',
    checked: selected,
    inMutuallyExclusiveGroup: true,
    enabled: onTap != null,
    excludeSemantics: true,
    child: Material(
      color: selected ? AppColors.blueSoft : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.medium),
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.border,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        key: Key('attendance-${status.name}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.medium),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                  size: 27,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

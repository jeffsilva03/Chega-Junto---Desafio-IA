import 'package:flutter/material.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/widgets/app_surface.dart';
import '../../../../core/widgets/medication_icon.dart';

class ProfileMenuGroup extends StatelessWidget {
  const ProfileMenuGroup({
    super.key,
    required this.title,
    required this.items,
    required this.onSelect,
  });
  final String title;
  final List<(IconData, String)> items;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 10),
      AppSurface(
        border: true,
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (final entry in items.indexed) ...[
              if (entry.$1 > 0)
                const Padding(
                  padding: EdgeInsets.only(left: 48, right: 12),
                  child: Divider(),
                ),
              InkWell(
                onTap: () => onSelect(entry.$2.$2),
                borderRadius: BorderRadius.circular(AppRadii.large),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      if (entry.$2.$1 == Icons.medication_outlined)
                        MedicationIcon(color: context.appColors.primary)
                      else
                        Icon(
                          entry.$2.$1,
                          color: context.appColors.primary,
                          size: 24,
                        ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          entry.$2.$2,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.chevron_right_rounded, size: 22),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ],
  );
}

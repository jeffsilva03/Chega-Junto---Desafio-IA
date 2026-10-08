import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/router/app_routes.dart';
import '../../app/theme/app_tokens.dart';

class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({super.key, this.selectedIndex = 0});
  final int selectedIndex;
  static const _labels = ['Início', 'Agenda', 'Preparo', 'Perfil'];
  static const _icons = [
    Icons.home_outlined,
    Icons.calendar_month_outlined,
    Icons.check_box_outlined,
    Icons.person_outline_rounded,
  ];
  static const _activeIcons = [
    Icons.home_rounded,
    Icons.calendar_month_rounded,
    Icons.check_box_rounded,
    Icons.person_rounded,
  ];
  static const _paths = [
    AppRoutes.home,
    AppRoutes.agenda,
    AppRoutes.checklist,
    AppRoutes.profile,
  ];
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: context.appColors.surface,
      border: Border(top: BorderSide(color: context.appColors.border)),
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.sheet)),
    ),
    child: SafeArea(
      top: false,
      child: Row(
        children: List.generate(_labels.length, (index) {
          final selected = selectedIndex == index;
          return Expanded(
            child: Semantics(
              selected: selected,
              button: true,
              label: _labels[index],
              excludeSemantics: true,
              child: InkWell(
                onTap: () => context.go(_paths[index]),
                borderRadius: BorderRadius.circular(AppRadii.medium),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 9,
                    horizontal: 2,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        selected ? _activeIcons[index] : _icons[index],
                        color: selected
                            ? context.appColors.primary
                            : context.appColors.textSecondary,
                        size: 27,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _labels[index],
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: selected
                              ? context.appColors.primary
                              : context.appColors.textSecondary,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        width: 28,
                        height: 3,
                        decoration: BoxDecoration(
                          color: selected
                              ? context.appColors.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    ),
  );
}

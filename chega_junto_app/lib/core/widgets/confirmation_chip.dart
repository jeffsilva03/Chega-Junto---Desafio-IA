import 'package:flutter/material.dart';
import '../../app/theme/app_tokens.dart';
import '../../data/models/appointment.dart';

class ConfirmationChip extends StatelessWidget {
  const ConfirmationChip({super.key, required this.status, this.exam = false});
  final ConfirmationStatus status;
  final bool exam;
  @override
  Widget build(BuildContext context) {
    final confirmed = status == ConfirmationStatus.confirmed;
    final color = confirmed ? AppColors.tealDark : AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: confirmed ? AppColors.tealSoft : AppColors.blueSoft,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (confirmed) ...[
            Icon(Icons.check_circle_rounded, size: 17, color: color),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              confirmed
                  ? 'Confirmada'
                  : status == ConfirmationStatus.unable
                  ? 'Não comparecerei'
                  : exam
                  ? 'Preparar-se'
                  : 'A confirmar',
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

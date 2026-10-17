import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../../features/items/domain/models/item_model.dart';

class StatusBadge extends StatelessWidget {
  final ItemStatus status;
  final bool compact;

  const StatusBadge({
    super.key,
    required this.status,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    IconData icon;

    switch (status) {
      case ItemStatus.found:
        color = AppColors.statusFound;
        label = 'FOUND';
        icon = Icons.check_circle_outline;
        break;
      case ItemStatus.claimed:
        color = AppColors.statusClaimed;
        label = 'CLAIMED';
        icon = Icons.verified_outlined;
        break;
      case ItemStatus.returned:
        color = AppColors.statusReturned;
        label = 'RETURNED';
        icon = Icons.assignment_turned_in_outlined;
        break;
      case ItemStatus.lost:
      default:
        color = AppColors.statusLost;
        label = 'LOST';
        icon = Icons.help_outline;
        break;
    }

    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: color,
            letterSpacing: 0.3,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

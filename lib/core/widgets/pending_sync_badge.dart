import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class PendingSyncBadge extends StatelessWidget {
  final bool compact;

  const PendingSyncBadge({
    super.key,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.accentAmber.withOpacity(0.2),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.accentAmber, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(
              Icons.cloud_upload_outlined,
              size: 12,
              color: AppColors.accentAmberDark,
            ),
            SizedBox(width: 4),
            Text(
              'Syncing...',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppColors.accentAmberDark,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accentAmber.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accentAmberDark.withOpacity(0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(
            Icons.cloud_queue_rounded,
            size: 14,
            color: AppColors.accentAmberDark,
          ),
          SizedBox(width: 6),
          Text(
            'Pending Sync (Offline)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.accentAmberDark,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/models/item_model.dart';

class StatusTimeline extends StatelessWidget {
  final ItemStatus currentStatus;

  const StatusTimeline({
    super.key,
    required this.currentStatus,
  });

  int get _currentIndex {
    switch (currentStatus) {
      case ItemStatus.lost:
        return 0;
      case ItemStatus.found:
        return 1;
      case ItemStatus.claimed:
        return 2;
      case ItemStatus.returned:
        return 3;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final steps = [
      _TimelineStepData(
        title: 'Lost',
        description: 'Reported missing',
        icon: Icons.search_rounded,
        color: AppColors.statusLost,
      ),
      _TimelineStepData(
        title: 'Found',
        description: 'Located & listed',
        icon: Icons.volunteer_activism_rounded,
        color: AppColors.statusFound,
      ),
      _TimelineStepData(
        title: 'Claimed',
        description: 'Ownership verified',
        icon: Icons.verified_outlined,
        color: AppColors.statusClaimed,
      ),
      _TimelineStepData(
        title: 'Returned',
        description: 'Handover complete',
        icon: Icons.check_circle_rounded,
        color: AppColors.statusReturned,
      ),
    ];

    final activeIndex = _currentIndex;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timeline_rounded, size: 18, color: AppColors.primaryTeal),
              const SizedBox(width: 8),
              Text(
                'Status Progression',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Horizontal Stepper Timeline
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(steps.length, (index) {
              final step = steps[index];
              final isPassed = index < activeIndex;
              final isCurrent = index == activeIndex;
              final isPending = index > activeIndex;

              Color nodeColor;
              if (isCurrent) {
                nodeColor = step.color;
              } else if (isPassed) {
                nodeColor = AppColors.primaryTeal;
              } else {
                nodeColor = isDark ? Colors.grey[700]! : Colors.grey[300]!;
              }

              return Expanded(
                child: Column(
                  children: [
                    // Node + Connecting Line
                    Row(
                      children: [
                        // Left line
                        Expanded(
                          child: Container(
                            height: 2.5,
                            color: index == 0
                                ? Colors.transparent
                                : (index <= activeIndex
                                    ? AppColors.primaryTeal
                                    : (isDark ? Colors.grey[800]! : Colors.grey[300]!)),
                          ),
                        ),

                        // Node Circle
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: isCurrent ? 36 : 28,
                          height: isCurrent ? 36 : 28,
                          decoration: BoxDecoration(
                            color: isPending
                                ? (isDark ? Colors.grey[850]! : Colors.white)
                                : nodeColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: nodeColor,
                              width: isCurrent ? 3 : 2,
                            ),
                            boxShadow: isCurrent
                                ? [
                                    BoxShadow(
                                      color: nodeColor.withOpacity(0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Icon(
                              isPassed
                                  ? Icons.check
                                  : (isCurrent ? step.icon : Icons.circle),
                              size: isCurrent ? 18 : (isPassed ? 14 : 8),
                              color: isPending ? Colors.grey[500] : Colors.white,
                            ),
                          ),
                        ),

                        // Right line
                        Expanded(
                          child: Container(
                            height: 2.5,
                            color: index == steps.length - 1
                                ? Colors.transparent
                                : (index < activeIndex
                                    ? AppColors.primaryTeal
                                    : (isDark ? Colors.grey[800]! : Colors.grey[300]!)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Label
                    Text(
                      step.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                        color: isCurrent
                            ? nodeColor
                            : (isPending
                                ? (isDark ? Colors.grey[500] : Colors.grey[600])
                                : null),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      step.description,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: TextStyle(
                        fontSize: 9.5,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

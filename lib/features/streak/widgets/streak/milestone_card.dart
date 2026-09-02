part of 'package:blockx/features/streak/widgets/streak_widgets.dart';

// ---------------------------------------------------------------------------
// Next-milestone card (detail)
// ---------------------------------------------------------------------------

class MilestoneCard extends StatelessWidget {
  const MilestoneCard({super.key, required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    final next = StreakLevels.next(days);
    if (next == null) {
      return _shell(
        child: Row(
          children: [
            const Icon(
              Icons.workspace_premium,
              color: AppColors.emerald,
              size: 26,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'Maxed out — legend.',
                style: AppText.title.copyWith(color: AppColors.text),
              ),
            ),
          ],
        ),
      );
    }
    final remaining = next.days - days;
    final progress = (days / next.days).clamp(0.0, 1.0);

    return _shell(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _hex(next.days),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NEXT MILESTONE',
                  style: AppText.bodyDim.copyWith(
                    fontFamily: AppFonts.oswald,
                    color: AppColors.red,
                    fontSize: 10,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(next.label.toUpperCase(), style: AppText.sectionHeader),
                const SizedBox(height: 3),
                Text(
                  '$remaining more day${remaining == 1 ? '' : 's'} to unlock',
                  style: AppText.bodyDim,
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: AppColors.dark3,
                    valueColor: const AlwaysStoppedAnimation(AppColors.red),
                  ),
                ),
                const SizedBox(height: 5),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '$days ',
                          style: AppText.bodyStrong.copyWith(
                            fontFamily: AppFonts.oswald,
                            fontSize: 11,
                          ),
                        ),
                        TextSpan(
                          text: '/ ${next.days}',
                          style: AppText.bodyDim.copyWith(
                            fontFamily: AppFonts.oswald,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _shell({required Widget child}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
    decoration: BoxDecoration(
      color: AppColors.dark2,
      borderRadius: AppRadius.mdAll,
      border: Border.all(color: AppColors.borderRed),
    ),
    child: child,
  );

  Widget _hex(int label) => SizedBox(
    width: 46,
    height: 46,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.red.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.red, width: 2),
          ),
        ),
        Text(
          '$label',
          style: AppText.heroNumber.copyWith(
            fontSize: 20,
            color: AppColors.white,
          ),
        ),
      ],
    ),
  );
}

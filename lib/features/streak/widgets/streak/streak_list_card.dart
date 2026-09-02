part of 'package:blockx/features/streak/widgets/streak_widgets.dart';

// ---------------------------------------------------------------------------
// Compact streak card (overview list)
// ---------------------------------------------------------------------------

class StreakListCard extends ConsumerWidget {
  const StreakListCard({
    super.key,
    required this.days,
    required this.start,
    required this.title,
    this.packageName,
    this.featureIcon,
    this.onTap,
  });

  final int days;
  final DateTime start;
  final String title;
  final String? packageName;
  final IconData? featureIcon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayTitle = packageName == null
        ? title
        : ref
              .watch(appNameProvider(packageName!))
              .maybeWhen(data: (n) => n, orElse: () => title);

    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdAll,
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.dark2,
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              _icon(),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            displayTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.label,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        StreakMilestoneChipSmall(days: days),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Constrain the strip so the tiles keep breathing room.
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 240),
                      child: WeekStrip(start: start),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$days',
                    style: AppText.heroNumber.copyWith(
                      fontSize: 34,
                      color: AppColors.text,
                    ),
                  ),
                  Text(
                    days == 1 ? 'DAY' : 'DAYS',
                    style: AppText.bodyDim.copyWith(
                      fontFamily: AppFonts.oswald,
                      fontSize: 10,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: AppColors.textDim, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _icon() {
    if (packageName != null) {
      return AppIcon(packageName: packageName!, size: 40);
    }
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        featureIcon ?? Icons.movie_outlined,
        color: AppColors.red,
        size: 22,
      ),
    );
  }
}

/// Small milestone chip (compact variant used on the list card).
class StreakMilestoneChipSmall extends StatelessWidget {
  const StreakMilestoneChipSmall({super.key, required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    final m = StreakLevels.current(days);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: m.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: m.color.withValues(alpha: 0.4)),
      ),
      child: Text(
        m.label.toUpperCase(),
        style: TextStyle(
          fontFamily: AppFonts.oswald,
          fontWeight: FontWeight.w600,
          fontSize: 9.5,
          letterSpacing: 0.8,
          color: m.color,
        ),
      ),
    );
  }
}

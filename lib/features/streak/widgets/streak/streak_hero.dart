part of 'package:blockx/features/streak/widgets/streak_widgets.dart';

// ---------------------------------------------------------------------------
// Hero panel
// ---------------------------------------------------------------------------

/// The big gradient flame panel. Used both as the featured streak on the
/// overview (with a week strip) and as the header on the detail screen (bigger
/// number, no strip).
class StreakHeroCard extends StatelessWidget {
  const StreakHeroCard({
    super.key,
    required this.days,
    required this.record,
    required this.title,
    required this.start,
    this.packageName,
    this.featureIcon,
    this.onTap,
    this.showWeek = true,
    this.detail = false,
  });

  final int days;
  final int record;
  final String title;
  final DateTime start;
  final String? packageName;
  final IconData? featureIcon;
  final VoidCallback? onTap;

  /// Show the Mon–Sun strip (overview featured card only).
  final bool showWeek;

  /// Detail variant: bigger number, "Current streak" kicker, no app tile.
  final bool detail;

  @override
  Widget build(BuildContext context) {
    final numberSize = detail ? 84.0 : 72.0;

    final content = Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Kicker
          if (detail)
            Text(
              'Current streak',
              style: AppText.label.copyWith(color: AppColors.white),
            )
          else
            Row(
              children: [
                _appTile(),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.title.copyWith(color: AppColors.white),
                  ),
                ),
              ],
            ),
          const SizedBox(height: AppSpacing.sm),
          // Big number
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '$days'),
                TextSpan(
                  text: 'd',
                  style: TextStyle(fontSize: numberSize * 0.34),
                ),
              ],
            ),
            style: AppText.heroNumber.copyWith(
              fontSize: numberSize,
              color: AppColors.white,
              height: 0.86,
              shadows: const [
                Shadow(
                  color: AppColors.heroShadow,
                  blurRadius: 14,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            detail ? 'Days blocked · $title' : 'Day streak',
            style: AppText.button.copyWith(
              color: AppColors.white.withValues(alpha: 0.94),
              fontSize: 13,
              letterSpacing: 0.14 * 13,
            ),
          ),
          if (showWeek) ...[
            const SizedBox(height: AppSpacing.lg),
            WeekStrip(start: start, onHero: true),
          ],
        ],
      ),
    );

    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: AppRadius.lgAll,
          gradient: const LinearGradient(
            begin: Alignment(-0.7, -1),
            end: Alignment(0.6, 1),
            colors: AppColors.heroRedGradient,
            stops: [0.0, 0.52, 1.0],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.red.withValues(alpha: 0.45),
              blurRadius: 34,
              offset: const Offset(0, 16),
              spreadRadius: -18,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: AppRadius.lgAll,
          child: Stack(
            children: [
              // Amber glow behind the flame (top-right).
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0.85, -0.5),
                      radius: 0.95,
                      colors: [
                        AppColors.amber.withValues(alpha: 0.5),
                        AppColors.amber.withValues(alpha: 0.0),
                      ],
                      stops: const [0.0, 0.55],
                    ),
                  ),
                ),
              ),
              // Faint decorative flame.
              Positioned(
                right: -18,
                top: -10,
                child: Icon(
                  Icons.local_fire_department,
                  size: 150,
                  color: AppColors.white.withValues(alpha: 0.14),
                ),
              ),
              // Dark scrim (lower-left) so the number always reads.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(-0.9, 0.95),
                      radius: 1.2,
                      colors: [AppColors.heroScrim, AppColors.heroScrimClear],
                      stops: [0.0, 0.6],
                    ),
                  ),
                ),
              ),
              // Best-ever badge.
              if (record > 0)
                Positioned(
                  top: 14,
                  right: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.black.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.emoji_events_outlined,
                          color: AppColors.white,
                          size: 13,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          detail ? 'Best $record' : '$record',
                          style: AppText.bodyStrong.copyWith(
                            color: AppColors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              content,
            ],
          ),
        ),
      ),
    );
  }

  Widget _appTile() {
    if (packageName != null) {
      return AppIcon(packageName: packageName!, size: 24);
    }
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Icon(
        featureIcon ?? Icons.movie_outlined,
        color: AppColors.white,
        size: 15,
      ),
    );
  }
}

part of 'package:blockx/features/streak/widgets/streak_widgets.dart';

// ---------------------------------------------------------------------------
// Screen-time shortcut
// ---------------------------------------------------------------------------

class ScreenTimeCard extends ConsumerWidget {
  const ScreenTimeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usageAsync = ref.watch(usageStatsProvider);
    final (label, apps) = usageAsync.maybeWhen(
      data: (list) {
        final total = list.fold<Duration>(
          Duration.zero,
          (s, u) => s + u.totalTime,
        );
        final h = total.inHours;
        final mm = total.inMinutes % 60;
        return (h > 0 ? '${h}h ${mm}m' : '${mm}m', list.length);
      },
      orElse: () => ('—', 0),
    );

    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const ProgressScreen())),
        borderRadius: AppRadius.mdAll,
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.dark2,
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.red.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.bar_chart,
                  color: AppColors.red,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SCREEN TIME TODAY',
                      style: AppText.bodyDim.copyWith(
                        fontFamily: AppFonts.oswald,
                        fontSize: 10.5,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: label, style: AppText.title),
                          if (apps > 0)
                            TextSpan(
                              text: '  · across $apps apps',
                              style: AppText.bodyDim.copyWith(fontSize: 14),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textDim),
            ],
          ),
        ),
      ),
    );
  }
}

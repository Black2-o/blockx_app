import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_usage.dart';
import '../providers/block_providers.dart';
import '../services/block_platform.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_icon.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/buttons.dart';
import '../widgets/decor.dart';
import '../widgets/empty_state.dart';

/// Progress: today's screen time per app, from Android UsageStats (read-only).
/// Needs the Usage Access permission (already part of setup); prompts for it if
/// missing. Embeddable as a bottom-nav tab.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permsAsync = ref.watch(permissionsProvider);
    final hasUsage = permsAsync.asData?.value.usageAccess ?? false;

    final Widget content = hasUsage
        ? _UsageList(ref: ref)
        : _NeedsPermission(onGranted: () => ref.invalidate(permissionsProvider));

    if (embedded) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPad),
        child: content,
      );
    }
    return AppScaffold(title: 'Screen Time', body: content, padded: false);
  }
}

class _UsageList extends StatelessWidget {
  const _UsageList({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final usageAsync = ref.watch(usageStatsProvider);

    return RefreshIndicator(
      color: AppColors.red,
      backgroundColor: AppColors.dark2,
      onRefresh: () async => ref.invalidate(usageStatsProvider),
      child: usageAsync.when(
        loading: () => const _Filler(child: Center(
          child: CircularProgressIndicator(color: AppColors.red),
        )),
        error: (err, _) => _Filler(
          child: Center(
            child: EmptyState(
              icon: Icons.error_outline,
              title: 'Could not read usage',
              subtitle: '$err',
            ),
          ),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const _Filler(
              child: Center(
                child: EmptyState(
                  icon: Icons.timelapse,
                  title: 'No usage yet today',
                  subtitle: 'Come back after using your phone a while.',
                ),
              ),
            );
          }
          final total = list.fold<Duration>(
              Duration.zero, (sum, u) => sum + u.totalTime);
          final maxMs = list.first.totalTime.inMilliseconds;

          return ListView(
            padding: const EdgeInsets.only(
              top: AppSpacing.lg,
              bottom: AppSpacing.xxxl,
            ),
            children: [
              _TotalCard(total: total, appCount: list.length),
              const SizedBox(height: AppSpacing.lg),
              Text('MOST USED TODAY', style: AppText.sectionHeader),
              const SizedBox(height: AppSpacing.sm),
              for (final u in list) ...[
                _UsageRow(usage: u, maxMs: maxMs),
                const SizedBox(height: AppSpacing.sm),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Keeps pull-to-refresh working even when content is short (single scroll).
class _Filler extends StatelessWidget {
  const _Filler({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: child,
        ),
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.total, required this.appCount});
  final Duration total;
  final int appCount;

  String get _label {
    final h = total.inHours;
    final m = total.inMinutes % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.mdAll,
      child: GlowBackground(
        alignment: Alignment.topRight,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: AppColors.borderRed),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SCREEN TIME TODAY', style: AppText.bodyDim),
              const SizedBox(height: AppSpacing.xs),
              Text(_label, style: AppText.hero.copyWith(fontSize: 44)),
              const SizedBox(height: AppSpacing.xs),
              Text('across $appCount apps', style: AppText.bodyDim),
            ],
          ),
        ),
      ),
    );
  }
}

class _UsageRow extends StatelessWidget {
  const _UsageRow({required this.usage, required this.maxMs});
  final AppUsage usage;
  final int maxMs;

  @override
  Widget build(BuildContext context) {
    final fraction =
        maxMs <= 0 ? 0.0 : (usage.totalTime.inMilliseconds / maxMs).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.dark2,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              AppIcon(packageName: usage.packageName, size: 36),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  usage.appName,
                  style: AppText.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(usage.label,
                  style: AppText.bodyDim.copyWith(
                    color: AppColors.text,
                    fontWeight: FontWeight.w600,
                  )),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              backgroundColor: AppColors.dark3,
              valueColor: const AlwaysStoppedAnimation(AppColors.red),
            ),
          ),
        ],
      ),
    );
  }
}

class _NeedsPermission extends StatelessWidget {
  const _NeedsPermission({required this.onGranted});
  final VoidCallback onGranted;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bar_chart, size: 48, color: AppColors.textDim),
            const SizedBox(height: AppSpacing.md),
            Text('See your screen time', style: AppText.title),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Turn on Usage Access so BlockX can show how long you spend in '
              'each app today.',
              style: AppText.bodyDim,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: 'Allow Usage Access',
              fullWidth: false,
              onPressed: () async {
                await BlockPlatform.openUsageAccessSettings();
                onGranted();
              },
            ),
          ],
        ),
      ),
    );
  }
}

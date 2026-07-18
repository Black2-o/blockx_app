import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_info.dart';
import '../providers/block_providers.dart';
import '../models/block_config.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_icon.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/celebration.dart';
import '../widgets/empty_state.dart';
import '../widgets/inputs.dart';
import 'config_sheet.dart';

/// The `+` destination: a list of every installed app. Tapping one opens the
/// rule sheet, adds it to the block list, and returns to Home.
class AppPickerScreen extends ConsumerStatefulWidget {
  const AppPickerScreen({super.key});

  @override
  ConsumerState<AppPickerScreen> createState() => _AppPickerScreenState();
}

class _AppPickerScreenState extends ConsumerState<AppPickerScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final installedAsync = ref.watch(installedAppsProvider);
    final blockList = ref.watch(blockListProvider);

    return AppScaffold(
      title: 'Add App',
      padded: false,
      constrainWidth: false,
      body: installedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: EmptyState(
            icon: Icons.error_outline,
            title: 'Failed to load apps',
            subtitle: '$err',
          ),
        ),
        data: (apps) {
          final q = _query.toLowerCase();
          final filtered = _query.isEmpty
              ? apps
              : apps
                  .where((a) =>
                      a.appName.toLowerCase().contains(q) ||
                      a.packageName.toLowerCase().contains(q))
                  .toList();

          return Column(
            children: [
              // Pinned search; the list scrolls under it (single scroll owner).
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPad,
                  AppSpacing.md,
                  AppSpacing.screenPad,
                  AppSpacing.sm,
                ),
                child: AppTextField(
                  hintText: 'Search apps',
                  prefixIcon: Icons.search,
                  autocorrect: false,
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: EmptyState(
                          icon: Icons.search_off,
                          title: 'No apps match',
                          subtitle: _query.isEmpty ? null : '"$_query"',
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.screenPad,
                          vertical: AppSpacing.sm,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final AppInfo app = filtered[index];
                          final added = blockList.containsKey(app.packageName);
                          return _AppRow(
                            app: app,
                            added: added,
                            onTap: added ? null : () => _pick(app),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _pick(AppInfo app) async {
    final config = await showRuleConfigSheet(context, appName: app.appName);
    if (config == null) return;
    await ref.read(blockListProvider.notifier).putApp(app.packageName, config);
    if (!mounted) return;
    await showBlockCelebration(
      context,
      title: app.appName,
      subtitle: config.mode == BlockMode.timed ? 'Limited.' : 'Locked in.',
      accent: config.mode == BlockMode.timed ? AppColors.amber : AppColors.red,
    );
    if (mounted) Navigator.of(context).pop();
  }
}

class _AppRow extends StatelessWidget {
  const _AppRow({required this.app, required this.added, this.onTap});

  final AppInfo app;
  final bool added;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: added ? 0.5 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdAll,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md,
            horizontal: AppSpacing.sm,
          ),
          child: Row(
            children: [
              AppIcon(packageName: app.packageName, size: 40),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  app.appName,
                  style: AppText.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (added)
                const Icon(Icons.check_circle,
                    color: AppColors.emerald, size: 20)
              else
                const Icon(Icons.add, color: AppColors.red, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

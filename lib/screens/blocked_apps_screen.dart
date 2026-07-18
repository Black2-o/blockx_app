import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_info.dart';
import '../models/block_config.dart';
import '../providers/block_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/cards.dart';
import '../widgets/empty_state.dart';
import '../widgets/state_indicators.dart';
import 'app_picker_screen.dart';
import 'config_sheet.dart';

/// The full list of blocked apps on its own page, with a `+` at the bottom to
/// add more. Keeping the list here (not on the dashboard) means the dashboard
/// stays short even with many blocked apps.
class BlockedAppsScreen extends ConsumerWidget {
  const BlockedAppsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blockList = ref.watch(blockListProvider);

    final names = <String, String>{};
    if (blockList.isNotEmpty) {
      ref.watch(installedAppsProvider).whenData((apps) {
        for (final AppInfo a in apps) {
          names[a.packageName] = a.appName;
        }
      });
    }

    final packages = blockList.keys.toList()
      ..sort((a, b) => (names[a] ?? a)
          .toLowerCase()
          .compareTo((names[b] ?? b).toLowerCase()));

    return AppScaffold(
      title: 'Blocked Apps',
      padded: false,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const AppPickerScreen()),
        ),
        icon: const Icon(Icons.add),
        label: Text('ADD APP', style: AppText.button),
      ),
      body: packages.isEmpty
          ? const Center(
              child: EmptyState(
                icon: Icons.apps_outlined,
                title: 'No apps blocked yet',
                subtitle: 'Tap + to block your first app.',
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPad,
                AppSpacing.lg,
                AppSpacing.screenPad,
                AppSpacing.xxxl * 2, // room above the FAB
              ),
              itemCount: packages.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final pkg = packages[index];
                final name = names[pkg] ?? pkg;
                return _AppRow(
                  name: name,
                  config: blockList[pkg]!,
                  onToggle: (v) =>
                      ref.read(blockListProvider.notifier).setEnabled(pkg, v),
                  onTap: () => _editConfig(context, ref, pkg, name, blockList[pkg]!),
                  onRemove: () => _confirmRemove(context, ref, pkg, name),
                );
              },
            ),
    );
  }

  Future<void> _editConfig(BuildContext context, WidgetRef ref, String pkg,
      String name, BlockConfig current) async {
    final updated =
        await showRuleConfigSheet(context, appName: name, initial: current);
    if (updated == null) return;
    await ref.read(blockListProvider.notifier).putApp(pkg, updated);
  }

  void _confirmRemove(
      BuildContext context, WidgetRef ref, String pkg, String name) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.dark2,
        title: Text('Remove $name?', style: AppText.title),
        content: Text('This app will be removed from the block list.',
            style: AppText.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('Cancel', style: AppText.label),
          ),
          TextButton(
            onPressed: () {
              ref.read(blockListProvider.notifier).removeApp(pkg);
              Navigator.of(dialogContext).pop();
            },
            child: Text('Remove',
                style: AppText.label.copyWith(color: AppColors.red)),
          ),
        ],
      ),
    );
  }
}

class _AppRow extends StatelessWidget {
  const _AppRow({
    required this.name,
    required this.config,
    required this.onToggle,
    required this.onTap,
    required this.onRemove,
  });

  final String name;
  final BlockConfig config;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.only(
        left: AppSpacing.lg,
        top: AppSpacing.sm,
        bottom: AppSpacing.sm,
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onRemove,
        child: Row(
          children: [
            const Icon(Icons.android, color: AppColors.textDim, size: 22),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: AppText.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      StateBadge.forConfig(config),
                      const SizedBox(width: AppSpacing.sm),
                      Flexible(
                        child: Text(
                          config.enabled ? config.summary : 'Tap to configure',
                          style: AppText.bodyDim,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Switch(value: config.enabled, onChanged: onToggle),
          ],
        ),
      ),
    );
  }
}

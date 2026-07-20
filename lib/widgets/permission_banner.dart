import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/block_providers.dart';
import '../services/block_platform.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Restyled setup card shown until all three permissions are granted. Each
/// missing permission gets its own row + button that deep-links to the right
/// system settings screen. Behavior is unchanged from the original banner — it
/// calls the same frozen [BlockPlatform] methods and reads [permissionsProvider].
class PermissionBanner extends ConsumerWidget {
  const PermissionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permsAsync = ref.watch(permissionsProvider);

    return permsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (perms) {
        if (!perms.needsSetup) return const SizedBox.shrink();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.amber.withValues(alpha: 0.08),
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: AppColors.amber.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: AppColors.amber, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Setup needed for blocking to work',
                      style: AppText.label.copyWith(
                        color: AppColors.amber,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (!perms.accessibility)
                _PermissionRow(
                  label:
                      'Enable the "BlockX" accessibility service — detects when a '
                      'blocked app opens.',
                  buttonText: 'Enable Accessibility',
                  onPressed: BlockPlatform.openAccessibilitySettings,
                ),
              if (!perms.overlay)
                _PermissionRow(
                  label:
                      'Allow "Draw over other apps" — shows the block screen.',
                  buttonText: 'Allow Overlay',
                  onPressed: BlockPlatform.openOverlaySettings,
                ),
              if (!perms.usageAccess)
                _PermissionRow(
                  label:
                      'Allow "Usage access" — reliably detects the app in front. '
                      'Find "BlockX" in the list and turn it on.',
                  buttonText: 'Allow Usage Access',
                  onPressed: BlockPlatform.openUsageAccessSettings,
                ),
              if (!perms.batteryOptimized)
                _PermissionRow(
                  label:
                      'Ignore battery optimization (recommended) — keeps blocking '
                      'running in the background. Some phones need this or the '
                      'blocker stops when the app is closed.',
                  buttonText: 'Ignore Battery Optimization',
                  onPressed: BlockPlatform.openBatteryOptimizationSettings,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.label,
    required this.buttonText,
    required this.onPressed,
  });

  final String label;
  final String buttonText;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.bodyDim),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => onPressed(),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.amber,
                side: const BorderSide(color: AppColors.amber),
                minimumSize: const Size.fromHeight(AppSpacing.tapTarget),
                shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.smAll),
                textStyle: AppText.button.copyWith(color: AppColors.amber),
              ),
              child: Text(buttonText.toUpperCase()),
            ),
          ),
        ],
      ),
    );
  }
}

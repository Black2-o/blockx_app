import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/device_info.dart';
import '../providers/block_providers.dart';
import '../services/block_platform.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/cards.dart';

/// Device Setup / Health: a live check of the permissions blocking needs, plus
/// per-manufacturer steps for the hidden OEM settings (MIUI pop-up + autostart,
/// ColorOS startup manager, Samsung battery, "Allow restricted settings", …).
/// Purely guidance + deep links — it never changes any blocking rule.
class DeviceSetupScreen extends ConsumerStatefulWidget {
  const DeviceSetupScreen({super.key});

  @override
  ConsumerState<DeviceSetupScreen> createState() => _DeviceSetupScreenState();
}

class _DeviceSetupScreenState extends ConsumerState<DeviceSetupScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check the moment the user returns from a system settings screen.
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(permissionsProvider);
    }
  }

  Future<void> _openAutoStart() async {
    final opened = await BlockPlatform.openAutoStartSettings();
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Opened App info — look for "Autostart" or "Startup manager".',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final permsAsync = ref.watch(permissionsProvider);
    final deviceAsync = ref.watch(deviceInfoProvider);

    return AppScaffold(
      title: 'Device Setup',
      padded: false,
      body: RefreshIndicator(
        color: AppColors.red,
        backgroundColor: AppColors.dark2,
        onRefresh: () async {
          ref.invalidate(permissionsProvider);
          ref.invalidate(deviceInfoProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPad,
            AppSpacing.lg,
            AppSpacing.screenPad,
            AppSpacing.xxxl,
          ),
          children: [
            Text(
              'Some phones (Xiaomi, Oppo, realme, Vivo…) aggressively close '
              'background apps and hide permissions. Grant everything below so '
              'BlockX keeps blocking — even overnight.',
              style: AppText.bodyDim,
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('PERMISSION STATUS', style: AppText.sectionHeader),
            const SizedBox(height: AppSpacing.md),
            permsAsync.when(
              loading: () => const _Loading(),
              error: (e, _) => Text('Could not read permissions: $e',
                  style: AppText.bodyDim),
              data: (perms) => Column(
                children: [
                  _StatusRow(
                    label: 'Accessibility service',
                    subtitle: 'Detects when a blocked app or reel opens.',
                    ok: perms.accessibility,
                    onFix: BlockPlatform.openAccessibilitySettings,
                  ),
                  _StatusRow(
                    label: 'Display over other apps',
                    subtitle: 'Shows the block screen and floating timer.',
                    ok: perms.overlay,
                    onFix: BlockPlatform.openOverlaySettings,
                  ),
                  _StatusRow(
                    label: 'Usage access',
                    subtitle: 'Reliably detects the app in front.',
                    ok: perms.usageAccess,
                    onFix: BlockPlatform.openUsageAccessSettings,
                  ),
                  _StatusRow(
                    label: 'Ignore battery optimization',
                    subtitle: 'Keeps blocking alive in the background.',
                    ok: perms.batteryOptimized,
                    onFix: BlockPlatform.openBatteryOptimizationSettings,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            deviceAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (device) => _reliabilitySection(device),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reliabilitySection(DeviceInfo device) {
    final steps = _stepsFor(device.oem);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('KEEP IT RUNNING ON ${device.label.toUpperCase()}',
            style: AppText.sectionHeader),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final step in steps) ...[
                _Bullet(step),
                const SizedBox(height: AppSpacing.sm),
              ],
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  _ActionChip(
                    icon: Icons.rocket_launch_outlined,
                    label: 'Autostart',
                    onTap: _openAutoStart,
                  ),
                  _ActionChip(
                    icon: Icons.battery_saver_outlined,
                    label: 'Battery',
                    onTap: BlockPlatform.openBatteryOptimizationSettings,
                  ),
                  _ActionChip(
                    icon: Icons.info_outline,
                    label: 'App info',
                    onTap: BlockPlatform.openAppSettings,
                  ),
                ],
              ),
            ],
          ),
        ),
        if (device.needsRestrictedSettings) ...[
          const SizedBox(height: AppSpacing.md),
          _RestrictedSettingsCard(onTap: BlockPlatform.openAppSettings),
        ],
      ],
    );
  }

  List<String> _stepsFor(DeviceOem oem) {
    switch (oem) {
      case DeviceOem.miui:
        return const [
          'Autostart: turn ON for BlockX.',
          'Other permissions → "Display pop-up windows while running in '
              'background": ON. This is what makes the block screen appear.',
          'Battery saver → No restrictions.',
          'Lock BlockX in Recents (swipe down on its card to lock).',
        ];
      case DeviceOem.coloros:
        return const [
          'Startup manager / Auto-launch: allow BlockX.',
          'Display over other apps: allow (shows the block screen).',
          'Battery → Allow background activity / Don\'t optimize.',
          'Lock BlockX in Recents.',
        ];
      case DeviceOem.funtouch:
        return const [
          'Autostart: ON for BlockX.',
          'Background power consumption: Allow high background power use.',
          'Display over other apps / floating window: Allow.',
        ];
      case DeviceOem.oneui:
        return const [
          'Battery → set BlockX to Unrestricted.',
          'Remove BlockX from "Sleeping apps" / "Deep sleeping apps".',
          'Turn off "Pause app activity if unused".',
        ];
      case DeviceOem.other:
        return const [
          'Battery → Don\'t optimize / Unrestricted.',
          'Allow autostart / background start if your phone offers it.',
          'Turn off "Remove permissions if app is unused".',
          'Lock BlockX in Recents so cleaners skip it.',
        ];
    }
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.subtitle,
    required this.ok,
    required this.onFix,
  });

  final String label;
  final String subtitle;
  final bool ok;
  final Future<void> Function() onFix;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        child: Row(
          children: [
            Icon(
              ok ? Icons.check_circle : Icons.cancel,
              color: ok ? AppColors.emerald : AppColors.amber,
              size: 24,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppText.label),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppText.bodyDim),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (ok)
              Text('ON',
                  style: AppText.bodyDim.copyWith(
                    color: AppColors.emerald,
                    fontWeight: FontWeight.w600,
                  ))
            else
              OutlinedButton(
                onPressed: () => onFix(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.amber,
                  side: const BorderSide(color: AppColors.amber),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.smAll),
                  textStyle: AppText.button.copyWith(fontSize: 13),
                ),
                child: const Text('FIX'),
              ),
          ],
        ),
      ),
    );
  }
}

class _RestrictedSettingsCard extends StatelessWidget {
  const _RestrictedSettingsCard({required this.onTap});

  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
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
              const Icon(Icons.lock_outline, color: AppColors.amber, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text("Accessibility greyed out? (Android 13+)",
                    style: AppText.label.copyWith(color: AppColors.amber)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Android hides Accessibility for apps installed outside the Play '
            'Store. Open App info → ⋮ menu (top-right) → "Allow restricted '
            'settings", then turn on the BlockX accessibility service.',
            style: AppText.bodyDim,
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(
            onPressed: () => onTap(),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.amber,
              side: const BorderSide(color: AppColors.amber),
              minimumSize: const Size.fromHeight(AppSpacing.tapTarget),
              shape:
                  const RoundedRectangleBorder(borderRadius: AppRadius.smAll),
              textStyle: AppText.button.copyWith(color: AppColors.amber),
            ),
            child: const Text('OPEN APP INFO'),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => onTap(),
      icon: Icon(icon, size: 18),
      label: Text(label.toUpperCase()),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.text,
        side: const BorderSide(color: AppColors.border),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.smAll),
        textStyle: AppText.button.copyWith(fontSize: 12),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: AppColors.red,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(text, style: AppText.body)),
      ],
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Center(child: CircularProgressIndicator(color: AppColors.red)),
    );
  }
}

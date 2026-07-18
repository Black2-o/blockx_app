import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/block_providers.dart';
import '../services/block_platform.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/buttons.dart';
import '../widgets/decor.dart';
import 'root_shell.dart';

/// A 4-step permissions walkthrough (Zeigarnik: a visible step counter nags an
/// unfinished grant back to completion). Wraps the existing permission checks —
/// it calls the same frozen [BlockPlatform] methods and reads
/// [permissionsProvider]; it grants nothing itself.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with WidgetsBindingObserver {
  int _step = 0;

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
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(permissionsProvider);
    }
  }

  void _finish() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const RootShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final permsAsync = ref.watch(permissionsProvider);
    final perms = permsAsync.asData?.value;

    final steps = <_OnboardStep>[
      const _OnboardStep(
        icon: Icons.shield_outlined,
        title: 'Welcome to BlockX',
        body: 'Block distracting apps, websites, and Shorts/Reels — the instant '
            'they appear. First, three quick permissions make the engine work.',
        cta: 'Get Started',
        granted: true,
      ),
      _OnboardStep(
        icon: Icons.accessibility_new,
        title: 'Accessibility',
        body: 'Lets BlockX detect the app in front and read a browser’s address '
            'bar. This is the whole engine.',
        cta: 'Enable Accessibility',
        granted: perms?.accessibility ?? false,
        onAction: BlockPlatform.openAccessibilitySettings,
      ),
      _OnboardStep(
        icon: Icons.layers_outlined,
        title: 'Display Over Apps',
        body: 'Lets BlockX show the block screen and the floating timer over '
            'other apps.',
        cta: 'Allow Overlay',
        granted: perms?.overlay ?? false,
        onAction: BlockPlatform.openOverlaySettings,
      ),
      _OnboardStep(
        icon: Icons.query_stats,
        title: 'Usage Access',
        body: 'Lets BlockX reliably read the real foreground app. Find "BlockX" '
            'in the list and turn it on.',
        cta: 'Allow Usage Access',
        granted: perms?.usageAccess ?? false,
        onAction: BlockPlatform.openUsageAccessSettings,
      ),
    ];

    final current = steps[_step];
    final isLast = _step == steps.length - 1;

    // One accent per step, driven by state: green once this permission is
    // allowed, red while it still needs allowing. (Step 0 is the intro — red.)
    final isPermissionStep = _step != 0;
    final granted = current.granted && isPermissionStep;
    final accent = granted ? AppColors.emerald : AppColors.red;

    return Scaffold(
      backgroundColor: AppColors.dark,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _StepDots(count: steps.length, active: _step, accent: accent),
                  const SizedBox(height: AppSpacing.xxl),
                  Center(
                    child: GlowBackground(
                      color: accent,
                      alignment: Alignment.center,
                      child: SizedBox(
                        width: 120,
                        height: 120,
                        child: Icon(
                          granted ? Icons.check_circle : current.icon,
                          size: 56,
                          color: accent,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text('Step ${_step + 1} of ${steps.length}',
                      style: AppText.bodyDim, textAlign: TextAlign.center),
                  const SizedBox(height: AppSpacing.sm),
                  Text(current.title.toUpperCase(),
                      style: AppText.titleL, textAlign: TextAlign.center),
                  if (isPermissionStep) ...[
                    const SizedBox(height: AppSpacing.md),
                    Center(child: _StatusPill(granted: granted)),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  Text(current.body,
                      style: AppText.body, textAlign: TextAlign.center),
                  const SizedBox(height: AppSpacing.xxl),
                  if (current.granted)
                    PrimaryButton(
                      label: isLast ? 'Done' : (_step == 0 ? current.cta : 'Next'),
                      icon: _step != 0 ? Icons.check : null,
                      color: accent,
                      onPressed: () {
                        if (isLast) {
                          _finish();
                        } else {
                          setState(() => _step++);
                        }
                      },
                    )
                  else
                    PrimaryButton(
                      label: current.cta,
                      onPressed: () => current.onAction?.call(),
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  Center(
                    child: SecondaryLink(
                      label: isLast ? 'Skip for now' : 'Do this later',
                      onPressed: () {
                        if (isLast) {
                          _finish();
                        } else {
                          setState(() => _step++);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardStep {
  const _OnboardStep({
    required this.icon,
    required this.title,
    required this.body,
    required this.cta,
    required this.granted,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String cta;
  final bool granted;
  final Future<void> Function()? onAction;
}

class _StepDots extends StatelessWidget {
  const _StepDots({
    required this.count,
    required this.active,
    required this.accent,
  });

  final int count;
  final int active;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: AppMotion.fast,
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            width: i == active ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i <= active ? accent : AppColors.border,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}

/// A small state pill: green "ALLOWED" once granted, red "NOT ALLOWED YET"
/// while pending — icon + text so it never relies on color alone.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.granted});

  final bool granted;

  @override
  Widget build(BuildContext context) {
    final color = granted ? AppColors.emerald : AppColors.red;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.smAll,
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(granted ? Icons.check_circle : Icons.error_outline,
              size: 16, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            granted ? 'ALLOWED' : 'NOT ALLOWED YET',
            style: AppText.bodyDim.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/block_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/decor.dart';
import '../widgets/page_header.dart';
import '../widgets/permission_banner.dart';
import 'blocked_apps_screen.dart';
import 'features_screen.dart';
import 'sites_screen.dart';

/// The dashboard hub: a header, the live "locked down" summary, and three cards
/// that open the full management pages (Block Apps · Shorts & Reels · Blocked
/// Sites). The lists themselves live on their own pages so the dashboard stays
/// short no matter how much is blocked.
class HomeDashboard extends ConsumerStatefulWidget {
  const HomeDashboard({super.key});

  @override
  ConsumerState<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends ConsumerState<HomeDashboard>
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
    // Re-check permissions when returning from the system settings screens.
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(permissionsProvider);
    }
  }

  void _push(Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final blockList = ref.watch(blockListProvider);
    final features = ref.watch(featureBlocksProvider);
    final sites = ref.watch(blockedSitesProvider);

    final activeApps = blockList.values.where((c) => c.enabled).length;
    final featuresOn = features.values.where((c) => c.enabled).length;

    return Column(
      children: [
        PageHeader(
          title: 'BlockX',
          showBack: false,
          leading: Row(
            children: [
              const SizedBox(width: AppSpacing.sm),
              Image.asset('assets/logo.png', width: 26, height: 26),
              const SizedBox(width: AppSpacing.sm),
              Text('BLOCKX',
                  style: AppText.hero.copyWith(fontSize: 24, letterSpacing: 2)),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: _CountBadge(count: activeApps + featuresOn + sites.length),
            ),
          ],
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPad,
              0,
              AppSpacing.screenPad,
              AppSpacing.xxxl,
            ),
            children: [
              Consumer(
                builder: (context, ref, _) {
                  final perms = ref.watch(permissionsProvider);
                  final granted = perms.maybeWhen(
                    data: (p) => !p.needsSetup,
                    orElse: () => true,
                  );
                  if (granted) return const SizedBox.shrink();
                  return const Padding(
                    padding: EdgeInsets.only(top: AppSpacing.lg),
                    child: PermissionBanner(),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              _HeroCard(
                activeApps: activeApps,
                sites: sites.length,
                features: featuresOn,
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('MANAGE', style: AppText.sectionHeader),
              const SizedBox(height: AppSpacing.md),
              _NavCard(
                icon: Icons.apps,
                title: 'Block Apps',
                value: activeApps == 0
                    ? 'None blocked'
                    : '$activeApps active',
                onTap: () => _push(const BlockedAppsScreen()),
              ),
              const SizedBox(height: AppSpacing.md),
              _NavCard(
                icon: Icons.smart_display_outlined,
                title: 'Shorts & Reels',
                value: featuresOn == 0 ? 'None on' : '$featuresOn of 3 on',
                onTap: () => _push(const FeaturesScreen()),
              ),
              const SizedBox(height: AppSpacing.md),
              _NavCard(
                icon: Icons.public,
                title: 'Blocked Sites',
                value: sites.isEmpty ? 'None blocked' : '${sites.length} blocked',
                onTap: () => _push(const SitesScreen()),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A hero panel that fills the top of the dashboard with the live "locked down"
/// summary — real counts, one glow, no filler.
class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.activeApps,
    required this.sites,
    required this.features,
  });

  final int activeApps;
  final int sites;
  final int features;

  @override
  Widget build(BuildContext context) {
    final total = activeApps + sites + features;
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
              Row(
                children: [
                  const Icon(Icons.shield_moon_outlined,
                      color: AppColors.red, size: 32),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(total == 0 ? 'ALL CLEAR' : 'LOCKED IN',
                            style: AppText.title),
                        const SizedBox(height: 2),
                        Text(
                          total == 0
                              ? 'Nothing blocked yet — add your first.'
                              : '$total distractions under control.',
                          style: AppText.bodyDim,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  _Stat(value: activeApps, label: 'Apps'),
                  _StatDivider(),
                  _Stat(value: features, label: 'Reels'),
                  _StatDivider(),
                  _Stat(value: sites, label: 'Sites'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text('$value', style: AppText.heroNumber.copyWith(fontSize: 30)),
          const SizedBox(height: 2),
          Text(label.toUpperCase(), style: AppText.bodyDim),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 32, color: AppColors.border);
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.red.withValues(alpha: 0.12),
        borderRadius: AppRadius.smAll,
        border: Border.all(color: AppColors.borderRed),
      ),
      child: Text(
        '$count active',
        style: AppText.bodyDim.copyWith(
          color: AppColors.red,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _NavCard extends StatelessWidget {
  const _NavCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.dark2,
      borderRadius: AppRadius.mdAll,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.borderRed,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.red.withValues(alpha: 0.1),
                  borderRadius: AppRadius.smAll,
                ),
                child: Icon(icon, color: AppColors.red, size: 24),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.label),
                    const SizedBox(height: 2),
                    Text(value, style: AppText.bodyDim),
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

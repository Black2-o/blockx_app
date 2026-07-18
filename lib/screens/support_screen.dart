import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/cards.dart';

/// Support Us: a few external links (donate / share / rate). UI only — no
/// backend. Links open in the system browser / share sheet.
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Support Us',
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.sm),
          Text('Keep BlockX free', style: AppText.titleL),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'BlockX is a solo, ad-free project. If it helps you stay focused, a '
            'small gesture goes a long way.',
            style: AppText.bodyDim,
          ),
          const SizedBox(height: AppSpacing.xl),
          _SupportRow(
            icon: Icons.coffee_outlined,
            title: 'Buy me a coffee',
            subtitle: 'A one-time thank you.',
            onTap: () => _open('https://www.buymeacoffee.com/'),
          ),
          const SizedBox(height: AppSpacing.md),
          _SupportRow(
            icon: Icons.ios_share,
            title: 'Share BlockX',
            subtitle: 'Tell a friend who needs it.',
            onTap: () => _open('https://blockx.app'),
          ),
          const SizedBox(height: AppSpacing.md),
          _SupportRow(
            icon: Icons.star_outline,
            title: 'Rate the app',
            subtitle: 'Leave a review.',
            onTap: () => _open('https://blockx.app'),
          ),
        ],
      ),
    );
  }
}

class _SupportRow extends StatelessWidget {
  const _SupportRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.red.withValues(alpha: 0.1),
              borderRadius: AppRadius.smAll,
            ),
            child: Icon(icon, color: AppColors.red, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.label),
                const SizedBox(height: 2),
                Text(subtitle, style: AppText.bodyDim),
              ],
            ),
          ),
          const Icon(Icons.open_in_new, color: AppColors.textDim, size: 18),
        ],
      ),
    );
  }
}

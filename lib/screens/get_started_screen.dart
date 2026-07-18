import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/buttons.dart';
import '../widgets/decor.dart';
import 'login_screen.dart';

/// The welcome / "Get Started" page shown on first launch after the splash,
/// before sign-in. Introduces what BlockX does, then leads to the login screen.
class GetStartedScreen extends StatelessWidget {
  const GetStartedScreen({super.key, required this.destinationBuilder});

  /// Where to go once the user has signed in (passed through to [LoginScreen]).
  final Widget Function() destinationBuilder;

  static const _highlights = [
    (Icons.block, 'Block distracting apps', 'Strict or a daily limit — your call.'),
    (Icons.smart_display_outlined, 'Kill Shorts & Reels',
        'Keep the app, lose the endless scroll.'),
    (Icons.insights_outlined, 'Track your progress',
        'See where your screen time really goes.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dark,
      body: GlowBackground(
        child: SafeArea(
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
                    Image.asset('assets/logo.png', width: 80, height: 80),
                    const SizedBox(height: AppSpacing.lg),
                    Text('BLOCKX',
                        style: AppText.hero.copyWith(fontSize: 44),
                        textAlign: TextAlign.center),
                    const SizedBox(height: AppSpacing.xs),
                    Text('Stay locked in. Take back your focus.',
                        style: AppText.bodyDim, textAlign: TextAlign.center),
                    const SizedBox(height: AppSpacing.xxl),
                    for (final (icon, title, sub) in _highlights) ...[
                      _Highlight(icon: icon, title: title, subtitle: sub),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    PrimaryButton(
                      label: 'Get Started',
                      icon: Icons.arrow_forward,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => LoginScreen(
                            destinationBuilder: destinationBuilder,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Highlight extends StatelessWidget {
  const _Highlight({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.red.withValues(alpha: 0.1),
            borderRadius: AppRadius.smAll,
            border: Border.all(color: AppColors.borderRed),
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
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/buttons.dart';
import 'ask_screen.dart';

/// FAQ: an accordion of the common questions, seeded from the project docs
/// (permissions, why accessibility, timers, re-enabling). Embeddable as a tab.
class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key, this.embedded = false});

  final bool embedded;

  static const List<(String, String)> _faqs = [
    (
      'Why does BlockX need the Accessibility permission?',
      'It is the whole engine. The accessibility service is what detects which '
          'app is in the foreground and reads a browser’s address bar, so it '
          'can cover a blocked app or bounce you off a blocked site.'
    ),
    (
      'Why three permissions?',
      'Accessibility detects the app in front. "Display over other apps" draws '
          'the floating timer and reliably launches the block screen. "Usage '
          'access" reads the real foreground app even under phone-maker game '
          'launchers.'
    ),
    (
      'The blocking stopped working after a restart.',
      'Some phones aggressively kill background services. Re-open BlockX; if the '
          'setup banner shows, re-enable the accessibility service from it.'
    ),
    (
      'How do time-limited apps work?',
      'You pick how many times a day you can open the app and how long each '
          'open lasts. Each open shows an "Is this really needed?" screen, then '
          'grants that session. When the daily opens are used up, it stays '
          'blocked until midnight.'
    ),
    (
      'When do daily limits reset?',
      'At midnight, local time. Your opens for each timed app and for '
          'Shorts/Reels refresh then.'
    ),
    (
      'Does blocking Shorts/Reels block the whole app?',
      'No. Only the short-video section is blocked — the rest of YouTube, '
          'Instagram, or Facebook keeps working normally.'
    ),
    (
      'A blocked site loaded for a second before the block screen.',
      'BlockX reads the address bar as the page opens, so there can be a brief '
          'flash before it bounces you back. That is expected.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final list = ListView.separated(
      padding: EdgeInsets.fromLTRB(
        embedded ? 0 : AppSpacing.screenPad,
        AppSpacing.lg,
        embedded ? 0 : AppSpacing.screenPad,
        AppSpacing.xl,
      ),
      itemCount: _faqs.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        if (index == _faqs.length) return _StillStuck(embedded: embedded);
        final (q, a) = _faqs[index];
        return _FaqItem(question: q, answer: a);
      },
    );

    if (embedded) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPad),
        child: list,
      );
    }
    return AppScaffold(title: 'FAQ', padded: false, body: list);
  }
}

class _FaqItem extends StatelessWidget {
  const _FaqItem({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.dark2,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        // Strip the default ExpansionTile dividers/splash for a clean look.
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: AppColors.borderRed,
        ),
        child: ExpansionTile(
          iconColor: AppColors.red,
          collapsedIconColor: AppColors.textDim,
          tilePadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xs,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          title: Text(question, style: AppText.label),
          children: [Text(answer, style: AppText.body)],
        ),
      ),
    );
  }
}

class _StillStuck extends StatelessWidget {
  const _StillStuck({required this.embedded});
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Column(
        children: [
          Text('Still stuck?', style: AppText.bodyDim),
          const SizedBox(height: AppSpacing.xs),
          SecondaryLink(
            label: 'Ask Us Anything',
            color: AppColors.red,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AskScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

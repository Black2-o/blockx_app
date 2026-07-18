import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/buttons.dart';
import '../widgets/decor.dart';

/// Ask Us / Contact: a single-CTA page that opens an email/contact link. UI
/// only — no form submission to a server.
class AskScreen extends StatelessWidget {
  const AskScreen({super.key});

  Future<void> _message() async {
    final uri = Uri.parse('mailto:hello@blockx.app?subject=BlockX%20Support');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Ask Us',
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.xxl),
          Center(
            child: GlowBackground(
              alignment: Alignment.center,
              child: Container(
                width: 88,
                height: 88,
                alignment: Alignment.center,
                child: const Icon(Icons.forum_outlined,
                    color: AppColors.red, size: 44),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('ASK US ANYTHING',
              style: AppText.titleL, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Bug, idea, or a blocking rule that broke after an app update? '
            'We read every message.',
            style: AppText.bodyDim,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(
            label: 'Message Us',
            icon: Icons.mail_outline,
            onPressed: _message,
          ),
        ],
      ),
    );
  }
}

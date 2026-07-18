import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/account_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/buttons.dart';
import '../widgets/cards.dart';
import '../widgets/inputs.dart';
import '../widgets/state_indicators.dart';
import 'ask_screen.dart';
import 'faq_screen.dart';
import 'splash_screen.dart';
import 'support_screen.dart';

/// Profile: premium status + the help/links hub (FAQ, Report a bug, Tip jar).
/// Sign-in is normally handled by the first-launch gate; the signed-out form
/// here only appears after an explicit sign-out. UI only — backed by the
/// persisted, UI-only [accountProvider] (no native/network).
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final ok = await ref
        .read(accountProvider.notifier)
        .signIn(_userCtrl.text, _passCtrl.text);
    if (!mounted) return;
    setState(() => _error = ok ? null : 'Incorrect username or password.');
    if (ok) FocusScope.of(context).unfocus();
  }

  /// Sign out and send the user all the way back to the splash → get-started →
  /// login flow, clearing the whole navigation stack so no app page is reachable
  /// until they sign in again.
  Future<void> _signOut() async {
    await ref.read(accountProvider.notifier).signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const SplashScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(accountProvider);

    final body = SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: account.signedIn ? _signedIn(account) : _signedOut(),
    );

    if (widget.embedded) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPad),
        child: body,
      );
    }
    return AppScaffold(title: 'Profile', scrollable: false, body: body);
  }

  Widget _signedOut() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('BLOCKX',
            style: AppText.hero.copyWith(fontSize: 32),
            textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.xs),
        Text('Sign in to manage premium.',
            style: AppText.bodyDim, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.xl),
        AppTextField(
          controller: _userCtrl,
          hintText: 'Username',
          prefixIcon: Icons.person_outline,
          autocorrect: false,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: _passCtrl,
          hintText: 'Password',
          prefixIcon: Icons.lock_outline,
          obscureText: true,
          autocorrect: false,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _signIn(),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            _error!,
            style: AppText.bodyDim.copyWith(
              color: AppColors.red,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        PrimaryButton(label: 'Sign In', onPressed: _signIn),
      ],
    );
  }

  Widget _signedIn(AccountState account) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.emerald.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border:
                  Border.all(color: AppColors.emerald.withValues(alpha: 0.4)),
            ),
            child: const Icon(Icons.person, color: AppColors.emerald, size: 36),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(account.username ?? 'You',
            style: AppText.title, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          child: Row(
            children: [
              const Icon(Icons.workspace_premium,
                  color: AppColors.emerald, size: 28),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Premium Active', style: AppText.label),
                    const SizedBox(height: 2),
                    Text('All features unlocked.', style: AppText.bodyDim),
                  ],
                ),
              ),
              StateBadge.allowed(),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('HELP & MORE', style: AppText.sectionHeader),
        const SizedBox(height: AppSpacing.md),
        _LinkRow(
          icon: Icons.help_outline,
          label: 'FAQ',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const FaqScreen()),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _LinkRow(
          icon: Icons.bug_report_outlined,
          label: 'Report a Bug',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const AskScreen()),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _LinkRow(
          icon: Icons.volunteer_activism_outlined,
          label: 'Tip Jar',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const SupportScreen()),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        OutlinedButton(
          onPressed: _signOut,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textDim,
            side: const BorderSide(color: AppColors.border),
            minimumSize: const Size(0, AppSpacing.tapTarget),
            shape:
                const RoundedRectangleBorder(borderRadius: AppRadius.smAll),
          ),
          child: Text('SIGN OUT',
              style: AppText.button.copyWith(color: AppColors.textDim)),
        ),
      ],
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.text, size: 22),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(label, style: AppText.label)),
          const Icon(Icons.chevron_right, color: AppColors.textDim),
        ],
      ),
    );
  }
}

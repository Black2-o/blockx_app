import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/account_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/buttons.dart';
import '../widgets/decor.dart';
import '../widgets/inputs.dart';

/// First-launch sign-in gate. Required once; the result is persisted so it never
/// shows again unless the user signs out. Stub credentials (admin / admin) — no
/// server. On success it clears the auth stack and shows [destinationBuilder]'s
/// screen (using its own Navigator, so there's no stale-context issue).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, required this.destinationBuilder});

  final Widget Function() destinationBuilder;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() => _busy = true);
    FocusScope.of(context).unfocus();
    final ok = await ref
        .read(accountProvider.notifier)
        .signIn(_userCtrl.text, _passCtrl.text);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => widget.destinationBuilder()),
        (route) => false,
      );
    } else {
      setState(() {
        _busy = false;
        _error = 'Incorrect username or password.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Scaffold(
      backgroundColor: AppColors.dark,
      body: GlowBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.xl,
                  AppSpacing.xl,
                  AppSpacing.xl + bottomInset,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/logo.png', width: 72, height: 72),
                    const SizedBox(height: AppSpacing.lg),
                    Text('BLOCKX',
                        style: AppText.hero.copyWith(fontSize: 40),
                        textAlign: TextAlign.center),
                    const SizedBox(height: AppSpacing.xs),
                    Text('Sign in to get started.',
                        style: AppText.bodyDim, textAlign: TextAlign.center),
                    const SizedBox(height: AppSpacing.xxl),
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
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    PrimaryButton(
                      label: _busy ? 'Signing in…' : 'Sign In',
                      onPressed: _busy ? null : _signIn,
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

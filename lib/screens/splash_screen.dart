import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../providers/account_provider.dart';
import '../providers/block_providers.dart';
import '../widgets/decor.dart';
import 'get_started_screen.dart';
import 'onboarding_screen.dart';
import 'root_shell.dart';

/// First-run brand moment. Logo scale+fades in, then the wordmark and tagline.
/// After the animation it routes onward (Home for now; Onboarding wiring is
/// added in a later phase). Orientation-agnostic: a centered column with a
/// width-capped logo.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _wordmarkFade;
  late final Animation<double> _taglineFade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.splash,
    );

    _logoFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );
    _wordmarkFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 0.8, curve: Curves.easeOut),
    );
    _taglineFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.7, 1.0, curve: Curves.easeOut),
    );

    _start();
  }

  Future<void> _start() async {
    // Respect "reduce motion": skip straight to the resting state.
    final reduceMotion =
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    if (reduceMotion) {
      _controller.value = 1.0;
    } else {
      await _controller.forward();
    }
    // Decide the destination while the animation plays. Guarded by a timeout so
    // a slow OEM permission check can never hang the splash.
    bool needsOnboarding;
    try {
      final perms = await ref.read(permissionsProvider.future).timeout(
            const Duration(seconds: 3),
          );
      needsOnboarding = !perms.allGranted;
    } catch (_) {
      needsOnboarding = false; // fall through to the app; banner handles it
    }

    final signedIn = ref.read(accountProvider).signedIn;
    if (mounted) _goNext(signedIn: signedIn, needsOnboarding: needsOnboarding);
  }

  void _goNext({required bool signedIn, required bool needsOnboarding}) {
    // Where to land once signed in: onboarding (if a permission is missing) or
    // the app shell.
    Widget destinationAfterLogin() =>
        needsOnboarding ? const OnboardingScreen() : const RootShell();

    // First launch (not signed in): Splash -> Get Started -> Login -> app.
    // Returning, signed-in user: straight to the app.
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: AppMotion.normal,
        pageBuilder: (_, _, _) => signedIn
            ? destinationAfterLogin()
            : GetStartedScreen(destinationBuilder: destinationAfterLogin),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shortSide = MediaQuery.of(context).size.shortestSide;
    final logoSize = (shortSide * 0.32).clamp(96.0, 200.0);

    return Scaffold(
      backgroundColor: AppColors.dark,
      body: GlowBackground(
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FadeTransition(
                    opacity: _logoFade,
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: Image.asset(
                        'assets/logo.png',
                        width: logoSize,
                        height: logoSize,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  FadeTransition(
                    opacity: _wordmarkFade,
                    child: Text('BLOCKX', style: AppText.hero),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  FadeTransition(
                    opacity: _taglineFade,
                    child: Text(
                      'STAY LOCKED IN',
                      style: AppText.label.copyWith(
                        color: AppColors.textDim,
                        letterSpacing: 3,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

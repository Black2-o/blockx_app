import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// A full-bleed dark background with one restrained radial glow behind its
/// [child]. The signature BlockX motif — used sparingly (splash, block screens),
/// never on every card (anti-slop §7).
class GlowBackground extends StatelessWidget {
  const GlowBackground({
    super.key,
    required this.child,
    this.color = AppColors.red,
    this.alignment = const Alignment(0, -0.3),
  });

  final Widget child;
  final Color color;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: alignment,
          radius: 0.9,
          colors: [color.withValues(alpha: 0.16), AppColors.dark],
          stops: const [0.0, 0.7],
        ),
      ),
      child: child,
    );
  }
}

/// A big hero number (timer countdowns, stat values) in Bebas Neue.
class HeroNumber extends StatelessWidget {
  const HeroNumber(this.value, {super.key, this.color = AppColors.text, this.size = 40});

  final String value;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      style: AppText.heroNumber.copyWith(color: color, fontSize: size),
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Shows a brief "winning" celebration overlay when a block is applied — a
/// popping lock badge with a burst of particles and a headline. Auto-dismisses.
/// Purely visual reward feedback (Peak-End Rule).
Future<void> showBlockCelebration(
  BuildContext context, {
  required String title,
  String subtitle = 'Locked in.',
  Color accent = AppColors.red,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'celebration',
    barrierColor: Colors.black.withValues(alpha: 0.72),
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (_, _, _) => _Celebration(
      title: title,
      subtitle: subtitle,
      accent: accent,
    ),
  );
}

class _Celebration extends StatefulWidget {
  const _Celebration({
    required this.title,
    required this.subtitle,
    required this.accent,
  });

  final String title;
  final String subtitle;
  final Color accent;

  @override
  State<_Celebration> createState() => _CelebrationState();
}

class _CelebrationState extends State<_Celebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    final rnd = math.Random();
    _particles = List.generate(14, (i) {
      final angle = (i / 14) * 2 * math.pi + rnd.nextDouble() * 0.4;
      return _Particle(
        angle: angle,
        distance: 70 + rnd.nextDouble() * 60,
        size: 4 + rnd.nextDouble() * 5,
        color: i.isEven ? widget.accent : AppColors.amber,
      );
    });

    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    final reduceMotion = WidgetsBinding
        .instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    if (reduceMotion) {
      _c.value = 1;
      _scheduleClose(const Duration(milliseconds: 800));
    } else {
      _c.forward();
      _scheduleClose(const Duration(milliseconds: 1500));
    }
  }

  void _scheduleClose(Duration after) {
    Future<void>.delayed(after, () {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pop = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.0, 0.45, curve: Curves.elasticOut),
    );
    final burst = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.1, 0.6, curve: Curves.easeOut),
    );
    final textFade = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.35, 0.7, curve: Curves.easeOut),
    );

    return GestureDetector(
      onTap: () => Navigator.of(context).maybePop(),
      child: Center(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final scale = Tween<double>(begin: 0.4, end: 1.0)
                .transform(pop.value.clamp(0.0, 1.0));
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 220,
                  height: 220,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // particle burst
                      CustomPaint(
                        size: const Size(220, 220),
                        painter: _BurstPainter(_particles, burst.value),
                      ),
                      // glowing badge
                      Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 108,
                          height: 108,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: widget.accent.withValues(alpha: 0.15),
                            border: Border.all(color: widget.accent, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: widget.accent.withValues(alpha: 0.4),
                                blurRadius: 32,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: Icon(Icons.lock,
                              color: widget.accent, size: 48),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                FadeTransition(
                  opacity: textFade,
                  child: Column(
                    children: [
                      Text(widget.title.toUpperCase(),
                          style: AppText.titleL, textAlign: TextAlign.center),
                      const SizedBox(height: AppSpacing.xs),
                      Text(widget.subtitle,
                          style: AppText.bodyDim, textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Particle {
  _Particle({
    required this.angle,
    required this.distance,
    required this.size,
    required this.color,
  });
  final double angle;
  final double distance;
  final double size;
  final Color color;
}

class _BurstPainter extends CustomPainter {
  _BurstPainter(this.particles, this.t);
  final List<_Particle> particles;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    for (final p in particles) {
      final d = p.distance * t;
      final pos = center +
          Offset(math.cos(p.angle) * d, math.sin(p.angle) * d);
      final paint = Paint()
        ..color = p.color.withValues(alpha: (1 - t).clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos, p.size * (1 - t * 0.5), paint);
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t;
}

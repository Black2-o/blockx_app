import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/block_providers.dart';
import '../theme/app_colors.dart';

/// Shows an app's real launcher icon (fetched natively + cached), with a neat
/// rounded fallback tile while it loads or if it can't be found.
class AppIcon extends ConsumerWidget {
  const AppIcon({super.key, required this.packageName, this.size = 40});

  final String packageName;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final iconAsync = ref.watch(appIconProvider(packageName));
    final radius = BorderRadius.circular(size * 0.24);

    return iconAsync.maybeWhen(
      data: (bytes) {
        if (bytes == null || bytes.isEmpty) return _fallback(radius);
        return ClipRRect(
          borderRadius: radius,
          child: Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => _fallback(radius),
          ),
        );
      },
      orElse: () => _fallback(radius),
    );
  }

  Widget _fallback(BorderRadius radius) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.dark3,
        borderRadius: radius,
        border: Border.all(color: AppColors.border),
      ),
      child: Icon(Icons.android, color: AppColors.textDim, size: size * 0.55),
    );
  }
}

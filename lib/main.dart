import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:blockx/features/account/data/account_store.dart';
import 'package:blockx/features/block/data/block_store.dart';
import 'package:blockx/features/block/data/feature_store.dart';
import 'package:blockx/features/sites/data/site_store.dart';
import 'package:blockx/features/streak/data/streak_store.dart';
import 'package:blockx/features/account/providers/account_provider.dart';
import 'package:blockx/core/providers/block_providers.dart';
import 'package:blockx/features/streak/providers/streak_provider.dart';
import 'package:blockx/features/onboarding/screens/splash_screen.dart';
import 'package:blockx/core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  // Kick off all box opens at once (they're independent) so the native launch
  // screen clears sooner — sequential awaits added avoidable startup delay.
  final blockFuture = BlockStore.open();
  final siteFuture = SiteStore.open();
  final featureFuture = FeatureStore.open();
  final accountFuture = AccountStore.open();
  final streakFuture = StreakStore.open();
  final store = await blockFuture;
  final siteStore = await siteFuture;
  final featureStore = await featureFuture;
  final accountStore = await accountFuture;
  final streakStore = await streakFuture;

  runApp(
    ProviderScope(
      overrides: [
        blockStoreProvider.overrideWithValue(store),
        siteStoreProvider.overrideWithValue(siteStore),
        featureStoreProvider.overrideWithValue(featureStore),
        accountStoreProvider.overrideWithValue(accountStore),
        streakStoreProvider.overrideWithValue(streakStore),
      ],
      child: const BlockApp(),
    ),
  );
}

class BlockApp extends StatelessWidget {
  const BlockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BlockX',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      // Clamp the OS font scale so a very large system font can't shatter every
      // layout, while still honoring accessibility to a reasonable degree
      // (responsive rules §7).
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final clamped = media.textScaler.clamp(
          minScaleFactor: 0.9,
          maxScaleFactor: 1.3,
        );
        return MediaQuery(
          data: media.copyWith(textScaler: clamped),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const SplashScreen(),
    );
  }
}

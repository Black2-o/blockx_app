import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'data/account_store.dart';
import 'data/block_store.dart';
import 'data/feature_store.dart';
import 'data/site_store.dart';
import 'providers/account_provider.dart';
import 'providers/block_providers.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  final store = await BlockStore.open();
  final siteStore = await SiteStore.open();
  final featureStore = await FeatureStore.open();
  final accountStore = await AccountStore.open();

  runApp(
    ProviderScope(
      overrides: [
        blockStoreProvider.overrideWithValue(store),
        siteStoreProvider.overrideWithValue(siteStore),
        featureStoreProvider.overrideWithValue(featureStore),
        accountStoreProvider.overrideWithValue(accountStore),
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

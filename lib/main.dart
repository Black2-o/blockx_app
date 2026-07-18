import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'data/block_store.dart';
import 'data/feature_store.dart';
import 'data/site_store.dart';
import 'providers/block_providers.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  final store = await BlockStore.open();
  final siteStore = await SiteStore.open();
  final featureStore = await FeatureStore.open();

  runApp(
    ProviderScope(
      overrides: [
        blockStoreProvider.overrideWithValue(store),
        siteStoreProvider.overrideWithValue(siteStore),
        featureStoreProvider.overrideWithValue(featureStore),
      ],
      child: const BlockApp(),
    ),
  );
}

class BlockApp extends StatelessWidget {
  const BlockApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Plain, default Material — no custom theming, per the project guide.
    return const MaterialApp(
      title: 'BlockX',
      home: HomeScreen(),
    );
  }
}

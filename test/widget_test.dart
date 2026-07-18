// Basic smoke test for the BlockX home dashboard.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:blockx/data/block_store.dart';
import 'package:blockx/data/feature_store.dart';
import 'package:blockx/data/site_store.dart';
import 'package:blockx/models/block_config.dart';
import 'package:blockx/providers/block_providers.dart';
import 'package:blockx/screens/home_screen.dart';

/// A block store backed by an in-memory map so tests don't touch Hive/native.
class _FakeBlockStore implements BlockStore {
  final Map<String, BlockConfig> _data = {};

  @override
  Map<String, BlockConfig> readAll() => Map<String, BlockConfig>.from(_data);

  @override
  Future<void> put(String packageName, BlockConfig config) async {
    _data[packageName] = config;
  }

  @override
  Future<void> remove(String packageName) async {
    _data.remove(packageName);
  }
}

class _FakeSiteStore implements SiteStore {
  final List<String> _data = [];

  @override
  List<String> readAll() => List<String>.from(_data)..sort();

  @override
  Future<void> add(String domain) async => _data.add(domain);

  @override
  Future<void> remove(String domain) async => _data.remove(domain);
}

class _FakeFeatureStore implements FeatureStore {
  @override
  Map<String, BlockConfig> readAll() => {
        for (final key in FeatureStore.keys)
          key: const BlockConfig(enabled: false),
      };

  @override
  Future<void> put(String key, BlockConfig config) async {}
}

void main() {
  testWidgets('Home dashboard shows the manage cards', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          blockStoreProvider.overrideWithValue(_FakeBlockStore()),
          siteStoreProvider.overrideWithValue(_FakeSiteStore()),
          featureStoreProvider.overrideWithValue(_FakeFeatureStore()),
          installedAppsProvider.overrideWith((ref) async => []),
          permissionsProvider.overrideWith(
            (ref) async => const BlockPermissions(
              accessibility: true,
              overlay: true,
              usageAccess: true,
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: HomeDashboard()),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Block Apps'), findsOneWidget);
    expect(find.text('Shorts & Reels'), findsOneWidget);
  });
}

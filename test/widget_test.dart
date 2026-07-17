// Basic smoke test for the Block app's home screen.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:blockx/data/block_store.dart';
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

void main() {
  testWidgets('Home screen shows empty-state message', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          blockStoreProvider.overrideWithValue(_FakeBlockStore()),
          installedAppsProvider.overrideWith((ref) async => []),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pump();

    expect(find.textContaining('No apps blocked yet'), findsOneWidget);
  });
}

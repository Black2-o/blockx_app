import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/block_config.dart';
import '../providers/block_providers.dart';
import 'config_dialog.dart';

/// Manage in-app feature blocks (Shorts / Reels). Each has an on/off switch and,
/// like an app, can be **Direct-block** or **Time-limited** (opens/day + minutes
/// each). Tap a row to choose; the switch turns it on/off.
class FeaturesScreen extends ConsumerWidget {
  const FeaturesScreen({super.key});

  // (key, label) — key must match native `featureApps` + FeatureStore.keys.
  static const List<(String, String)> _items = [
    ('yt_shorts', 'YouTube Shorts'),
    ('ig_reels', 'Instagram Reels'),
    ('fb_reels', 'Facebook Reels'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configs = ref.watch(featureBlocksProvider);
    final notifier = ref.read(featureBlocksProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Block in-app features')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Blocks just the short-video section inside these apps — the rest '
              'of the app keeps working. Turn one on with the switch, then tap '
              'the row to make it always-blocked or time-limited (opens/day + '
              'minutes each). Time-limited shows a floating timer while you watch '
              'and bounces you out when the daily limit is used up.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          for (final (key, label) in _items)
            ListTile(
              title: Text(label),
              subtitle: Text(
                (configs[key] ?? const BlockConfig(enabled: false)).enabled
                    ? (configs[key] ?? const BlockConfig(enabled: false)).summary
                    : 'Off',
              ),
              trailing: Switch(
                value:
                    (configs[key] ?? const BlockConfig(enabled: false)).enabled,
                onChanged: (v) => notifier.setEnabled(key, v),
              ),
              onTap: () async {
                final current =
                    configs[key] ?? const BlockConfig(enabled: false);
                final updated = await showConfigDialog(
                  context,
                  appName: label,
                  initial: current,
                );
                if (updated != null) await notifier.setConfig(key, updated);
              },
            ),
        ],
      ),
    );
  }
}

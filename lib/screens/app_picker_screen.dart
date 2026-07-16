import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_info.dart';
import '../providers/block_providers.dart';
import 'config_dialog.dart';

/// The `+` destination: a list of every installed app. Tapping one adds it to
/// the block list (default on) and returns to the home screen.
class AppPickerScreen extends ConsumerStatefulWidget {
  const AppPickerScreen({super.key});

  @override
  ConsumerState<AppPickerScreen> createState() => _AppPickerScreenState();
}

class _AppPickerScreenState extends ConsumerState<AppPickerScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final installedAsync = ref.watch(installedAppsProvider);
    final blockList = ref.watch(blockListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Add app to block')),
      body: installedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Failed to load apps:\n$err')),
        data: (apps) {
          final filtered = _query.isEmpty
              ? apps
              : apps
                  .where((a) =>
                      a.appName.toLowerCase().contains(_query.toLowerCase()) ||
                      a.packageName
                          .toLowerCase()
                          .contains(_query.toLowerCase()))
                  .toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search apps',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final AppInfo app = filtered[index];
                    final alreadyAdded =
                        blockList.containsKey(app.packageName);
                    return ListTile(
                      title: Text(app.appName),
                      subtitle: Text(app.packageName),
                      trailing: alreadyAdded
                          ? const Icon(Icons.check, color: Colors.green)
                          : null,
                      enabled: !alreadyAdded,
                      onTap: alreadyAdded
                          ? null
                          : () async {
                              final config = await showConfigDialog(
                                context,
                                appName: app.appName,
                              );
                              if (config == null) return;
                              await ref
                                  .read(blockListProvider.notifier)
                                  .putApp(app.packageName, config);
                              if (context.mounted) Navigator.of(context).pop();
                            },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

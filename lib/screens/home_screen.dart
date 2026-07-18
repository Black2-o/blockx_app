import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_info.dart';
import '../models/block_config.dart';
import '../providers/block_providers.dart';
import '../services/block_platform.dart';
import 'app_picker_screen.dart';
import 'config_dialog.dart';
import 'features_screen.dart';
import 'sites_screen.dart';

/// Home: the apps the user has chosen to block, each with an on/off switch,
/// plus a `+` button to add more. Shows a setup banner until the two required
/// permissions are granted.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check permissions when returning from the system settings screens.
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(permissionsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final blockList = ref.watch(blockListProvider);
    final installedAsync = ref.watch(installedAppsProvider);

    // Resolve a readable name for each stored package; fall back to the
    // package name if the app isn't found (e.g. uninstalled since).
    final names = <String, String>{};
    installedAsync.whenData((apps) {
      for (final AppInfo a in apps) {
        names[a.packageName] = a.appName;
      }
    });

    final packages = blockList.keys.toList()
      ..sort((a, b) => (names[a] ?? a).toLowerCase().compareTo(
            (names[b] ?? b).toLowerCase(),
          ));

    return Scaffold(
      appBar: AppBar(
        title: const Text('BlockX'),
        actions: [
          IconButton(
            icon: const Icon(Icons.video_library_outlined),
            tooltip: 'Block Shorts/Reels',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const FeaturesScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.public),
            tooltip: 'Blocked websites',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SitesScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const _PermissionBanner(),
          Expanded(
            child: packages.isEmpty
                ? const Center(
                    child: Text('No apps blocked yet.\nTap + to add one.',
                        textAlign: TextAlign.center),
                  )
                : ListView.builder(
                    itemCount: packages.length,
                    itemBuilder: (context, index) {
                      final pkg = packages[index];
                      final config = blockList[pkg];
                      if (config == null) return const SizedBox.shrink();
                      final name = names[pkg] ?? pkg;
                      return ListTile(
                        title: Text(name),
                        subtitle: Text(config.summary),
                        trailing: Switch(
                          value: config.enabled,
                          onChanged: (value) => ref
                              .read(blockListProvider.notifier)
                              .setEnabled(pkg, value),
                        ),
                        onTap: () => _editConfig(context, ref, pkg, name, config),
                        onLongPress: () => _confirmRemove(context, ref, pkg, name),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const AppPickerScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _editConfig(BuildContext context, WidgetRef ref, String pkg,
      String name, BlockConfig current) async {
    final updated =
        await showConfigDialog(context, appName: name, initial: current);
    if (updated == null) return;
    await ref.read(blockListProvider.notifier).putApp(pkg, updated);
  }

  void _confirmRemove(
      BuildContext context, WidgetRef ref, String pkg, String name) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Remove $name?'),
        content: const Text('This app will be removed from the block list.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(blockListProvider.notifier).removeApp(pkg);
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

/// A plain warning card shown until both required permissions are granted.
/// Each missing permission gets its own button that opens the right settings
/// screen; the banner disappears once everything is granted.
class _PermissionBanner extends ConsumerWidget {
  const _PermissionBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permsAsync = ref.watch(permissionsProvider);

    return permsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (perms) {
        if (perms.allGranted) return const SizedBox.shrink();

        return Container(
          width: double.infinity,
          color: Colors.amber.shade100,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Setup needed for blocking to work:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (!perms.accessibility)
                _PermissionRow(
                  label:
                      'Enable the "BlockX" accessibility service (detects when a blocked app opens).',
                  buttonText: 'Enable Accessibility',
                  onPressed: () async {
                    await BlockPlatform.openAccessibilitySettings();
                  },
                ),
              if (!perms.overlay)
                _PermissionRow(
                  label:
                      'Allow "Draw over other apps" (shows the blocked screen).',
                  buttonText: 'Allow Overlay',
                  onPressed: () async {
                    await BlockPlatform.openOverlaySettings();
                  },
                ),
              if (!perms.usageAccess)
                _PermissionRow(
                  label:
                      'Allow "Usage access" (reliably detects the app in front, '
                      'even under Game Space). Find "BlockX" in the list and turn it on.',
                  buttonText: 'Allow Usage Access',
                  onPressed: () async {
                    await BlockPlatform.openUsageAccessSettings();
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.label,
    required this.buttonText,
    required this.onPressed,
  });

  final String label;
  final String buttonText;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: 4),
          ElevatedButton(onPressed: onPressed, child: Text(buttonText)),
        ],
      ),
    );
  }
}

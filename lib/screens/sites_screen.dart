import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/block_providers.dart';

/// Plain screen to manage blocked website domains: a text field + Add, and a
/// list of domains with a delete button. No fancy UI.
class SitesScreen extends ConsumerStatefulWidget {
  const SitesScreen({super.key});

  @override
  ConsumerState<SitesScreen> createState() => _SitesScreenState();
}

class _SitesScreenState extends ConsumerState<SitesScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add() {
    if (_controller.text.trim().isEmpty) return;
    ref.read(blockedSitesProvider.notifier).addSite(_controller.text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final sites = ref.watch(blockedSitesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Blocked websites')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    autocorrect: false,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      hintText: 'e.g. youtube.com',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _add(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _add, child: const Text('Add')),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Opening any of these in a browser shows the block screen.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: sites.isEmpty
                ? const Center(
                    child: Text('No websites blocked yet.',
                        textAlign: TextAlign.center),
                  )
                : ListView.builder(
                    itemCount: sites.length,
                    itemBuilder: (context, index) {
                      final host = sites[index];
                      return ListTile(
                        title: Text(host),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => ref
                              .read(blockedSitesProvider.notifier)
                              .removeSite(host),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/block_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/buttons.dart';
import '../widgets/empty_state.dart';
import '../widgets/inputs.dart';

/// Manage blocked website domains: a text field + Add, and a list of domains
/// with a delete button. Backed by the frozen [blockedSitesProvider].
class SitesScreen extends ConsumerStatefulWidget {
  const SitesScreen({super.key, this.embedded = false});

  /// When true, renders without its own header (hosted inside the tab shell).
  final bool embedded;

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
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    ref.read(blockedSitesProvider.notifier).addSite(text);
    _controller.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final sites = ref.watch(blockedSitesProvider);

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.lg),
        // Add row: Expanded field so the Add button never gets pushed off-screen
        // in landscape / with large text (responsive §9).
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppTextField(
                controller: _controller,
                hintText: 'e.g. youtube.com',
                prefixIcon: Icons.public,
                autocorrect: false,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _add(),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            PrimaryButton(
              label: 'Add',
              fullWidth: false,
              onPressed: _add,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Opening any of these in a browser shows the block screen.',
          style: AppText.bodyDim,
        ),
        const SizedBox(height: AppSpacing.lg),
        Expanded(
          child: sites.isEmpty
              ? const Center(
                  child: EmptyState(
                    icon: Icons.language,
                    title: 'No websites blocked yet',
                    subtitle: 'Add a domain above to block it everywhere.',
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                  itemCount: sites.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final host = sites[index];
                    return _SiteRow(
                      host: host,
                      onRemove: () => ref
                          .read(blockedSitesProvider.notifier)
                          .removeSite(host),
                    );
                  },
                ),
        ),
      ],
    );

    if (widget.embedded) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPad),
        child: body,
      );
    }
    return AppScaffold(title: 'Blocked Sites', body: body);
  }
}

class _SiteRow extends StatelessWidget {
  const _SiteRow({required this.host, required this.onRemove});

  final String host;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.dark2,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.only(left: AppSpacing.lg),
      child: Row(
        children: [
          const Icon(Icons.public, size: 20, color: AppColors.textDim),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              host,
              style: AppText.body,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.textDim),
            tooltip: 'Remove',
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

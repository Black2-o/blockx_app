import 'package:flutter/material.dart';

import '../models/block_config.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/buttons.dart';

/// Modal bottom sheet to choose how an app/feature is blocked: Blocked directly
/// or Time-limited (opens/day + minutes each). Returns the chosen [BlockConfig],
/// or null if cancelled. [initial] pre-fills it when editing.
///
/// The returned value contract is identical to the old dialog — the native side
/// is untouched.
Future<BlockConfig?> showRuleConfigSheet(
  BuildContext context, {
  required String appName,
  BlockConfig? initial,
}) {
  return showModalBottomSheet<BlockConfig>(
    context: context,
    backgroundColor: AppColors.dark2,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: AppRadius.lg),
    ),
    builder: (_) => _ConfigSheet(appName: appName, initial: initial),
  );
}

class _ConfigSheet extends StatefulWidget {
  const _ConfigSheet({required this.appName, this.initial});

  final String appName;
  final BlockConfig? initial;

  @override
  State<_ConfigSheet> createState() => _ConfigSheetState();
}

class _ConfigSheetState extends State<_ConfigSheet> {
  static const _opensOptions = [1, 2, 3, 5, 10];
  static const _minutesOptions = [1, 2, 5, 10, 15, 30];

  late BlockMode _mode;
  late int _opensPerDay;
  late int _sessionMinutes;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _mode = initial?.mode ?? BlockMode.direct;
    _opensPerDay = initial?.opensPerDay ?? 5;
    _sessionMinutes = initial?.sessionMinutes ?? 5;
  }

  @override
  Widget build(BuildContext context) {
    // Cap height and stay above the keyboard / bottom inset (responsive §5).
    final maxHeight = MediaQuery.of(context).size.height * 0.9;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.lg + bottomInset,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle.
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                widget.appName.toUpperCase(),
                style: AppText.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: _ModeOption(
                      icon: Icons.block,
                      label: 'Strict Block',
                      hint: 'No way in',
                      color: AppColors.red,
                      selected: _mode == BlockMode.direct,
                      onTap: () => setState(() => _mode = BlockMode.direct),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _ModeOption(
                      icon: Icons.hourglass_bottom,
                      label: 'Limit',
                      hint: 'A few opens a day',
                      color: AppColors.amber,
                      selected: _mode == BlockMode.timed,
                      onTap: () => setState(() => _mode = BlockMode.timed),
                    ),
                  ),
                ],
              ),
              if (_mode == BlockMode.timed) ...[
                const SizedBox(height: AppSpacing.xl),
                Text('Daily opens', style: AppText.label),
                const SizedBox(height: AppSpacing.sm),
                _NumberChips(
                  options: _opensOptions,
                  value: _opensPerDay,
                  suffix: '×',
                  onChanged: (v) => setState(() => _opensPerDay = v),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Session length', style: AppText.label),
                const SizedBox(height: AppSpacing.sm),
                _NumberChips(
                  options: _minutesOptions,
                  value: _sessionMinutes,
                  suffix: ' min',
                  onChanged: (v) => setState(() => _sessionMinutes = v),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                label: 'Save',
                onPressed: () {
                  Navigator.of(context).pop(
                    BlockConfig(
                      enabled: widget.initial?.enabled ?? true,
                      mode: _mode,
                      opensPerDay: _opensPerDay,
                      sessionMinutes: _sessionMinutes,
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.xs),
              Center(
                child: SecondaryLink(
                  label: 'Cancel',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A big selectable mode card: icon + label + hint + selected state (never color
/// alone — §A.4).
class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.icon,
    required this.label,
    required this.hint,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String hint;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdAll,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.lg,
          horizontal: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : AppColors.dark3,
          borderRadius: AppRadius.mdAll,
          border: Border.all(
            color: selected ? color : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? color : AppColors.textDim, size: 26),
            const SizedBox(height: AppSpacing.sm),
            Text(
              label,
              style: AppText.label.copyWith(
                color: selected ? color : AppColors.text,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              hint,
              style: AppText.bodyDim,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberChips extends StatelessWidget {
  const _NumberChips({
    required this.options,
    required this.value,
    required this.suffix,
    required this.onChanged,
  });

  final List<int> options;
  final int value;
  final String suffix;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final o in options)
          _ValueChip(
            label: '$o$suffix',
            selected: o == value,
            onTap: () => onChanged(o),
          ),
      ],
    );
  }
}

class _ValueChip extends StatelessWidget {
  const _ValueChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.smAll,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.red : AppColors.dark3,
          borderRadius: AppRadius.smAll,
          border: Border.all(
            color: selected ? AppColors.red : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppText.label.copyWith(
            color: selected ? AppColors.white : AppColors.text,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

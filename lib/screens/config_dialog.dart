import 'package:flutter/material.dart';

import '../models/block_config.dart';

/// Dialog to choose how an app is blocked: Direct (always) or Time-limited
/// (opens/day + minutes per open). Returns the chosen [BlockConfig], or null if
/// cancelled. [initial] pre-fills it when editing an existing app.
Future<BlockConfig?> showConfigDialog(
  BuildContext context, {
  required String appName,
  BlockConfig? initial,
}) {
  return showDialog<BlockConfig>(
    context: context,
    builder: (_) => _ConfigDialog(appName: appName, initial: initial),
  );
}

class _ConfigDialog extends StatefulWidget {
  const _ConfigDialog({required this.appName, this.initial});

  final String appName;
  final BlockConfig? initial;

  @override
  State<_ConfigDialog> createState() => _ConfigDialogState();
}

class _ConfigDialogState extends State<_ConfigDialog> {
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
    return AlertDialog(
      title: Text(widget.appName),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RadioGroup<BlockMode>(
              groupValue: _mode,
              onChanged: (v) => setState(() => _mode = v!),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<BlockMode>(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Block directly'),
                    subtitle: Text('Always blocked — no way in.'),
                    value: BlockMode.direct,
                  ),
                  RadioListTile<BlockMode>(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Time-limited'),
                    subtitle: Text('Open a few times a day, for a set time.'),
                    value: BlockMode.timed,
                  ),
                ],
              ),
            ),
            if (_mode == BlockMode.timed) ...[
              const SizedBox(height: 8),
              const Text('Opens per day'),
              _NumberChips(
                options: _opensOptions,
                value: _opensPerDay,
                suffix: '×',
                onChanged: (v) => setState(() => _opensPerDay = v),
              ),
              const SizedBox(height: 8),
              const Text('Minutes per open'),
              _NumberChips(
                options: _minutesOptions,
                value: _sessionMinutes,
                suffix: ' min',
                onChanged: (v) => setState(() => _sessionMinutes = v),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
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
          child: const Text('Save'),
        ),
      ],
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
      spacing: 8,
      children: [
        for (final o in options)
          ChoiceChip(
            label: Text('$o$suffix'),
            selected: o == value,
            onSelected: (_) => onChanged(o),
          ),
      ],
    );
  }
}

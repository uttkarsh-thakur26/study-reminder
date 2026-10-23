import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Asks for a whole number of minutes from [min] to [max]. Null when the
/// user cancels.
Future<int?> showMinutesDialog(
  BuildContext context, {
  required String title,
  required int initial,
  int min = 1,
  int max = 240,
  String? help,
}) => showDialog<int>(
  context: context,
  builder: (context) => _MinutesDialog(
    title: title,
    initial: initial,
    min: min,
    max: max,
    help: help,
  ),
);

class _MinutesDialog extends StatefulWidget {
  const _MinutesDialog({
    required this.title,
    required this.initial,
    required this.min,
    required this.max,
    this.help,
  });

  final String title;
  final int initial;
  final int min;
  final int max;
  final String? help;

  @override
  State<_MinutesDialog> createState() => _MinutesDialogState();
}

class _MinutesDialogState extends State<_MinutesDialog> {
  late final _text = TextEditingController(text: '${widget.initial}')
    ..selection = TextSelection(
      baseOffset: 0,
      extentOffset: '${widget.initial}'.length,
    );

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  int? get _value {
    final v = int.tryParse(_text.text.trim());
    return v == null || v < widget.min || v > widget.max ? null : v;
  }

  void _done() {
    final v = _value;
    if (v != null) Navigator.of(context).pop(v);
  }

  @override
  Widget build(BuildContext context) {
    final valid = _value != null;
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _text,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(4),
        ],
        decoration: InputDecoration(
          suffixText: 'min',
          helperText:
              widget.help ?? 'From ${widget.min} to ${widget.max} minutes',
          errorText: valid || _text.text.isEmpty
              ? null
              : 'From ${widget.min} to ${widget.max} minutes',
        ),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _done(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: valid ? _done : null, child: const Text('OK')),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CopyAnswerButton extends StatelessWidget {
  const CopyAnswerButton({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: 'Copy answer',
      visualDensity: VisualDensity.compact,
      onPressed: () => Clipboard.setData(ClipboardData(text: text)),
      icon: Icon(Icons.copy_rounded, size: 15, color: scheme.onSurfaceVariant),
    );
  }
}

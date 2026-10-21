import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// An error the user can take away with them: the text selects, and one tap
/// copies it whole. Error messages end up in bug reports, so they must never
/// be a screenshot — and a copy that worked must say so, because on a phone
/// a silent press leaves no clipboard to look at.
class CopyableError extends StatelessWidget {
  const CopyableError(
    this.text, {
    super.key,
    this.maxLines = 4,
    this.fontSize = 12.5,
  });

  final String text;
  final int maxLines;
  final double fontSize;

  void _copy(BuildContext context) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    // Start the clipboard write inside the press so the browser still sees
    // the user gesture; awaiting first loses that and the write is refused.
    final write = Clipboard.setData(ClipboardData(text: text));
    // Confirmation, because on a phone a silent press leaves nothing to see.
    messenger?.showSnackBar(
      const SnackBar(
        content: Text('Error copied'),
        duration: Duration(seconds: 2),
      ),
    );
    write.catchError((Object failure) {
      debugPrint('[copy] could not copy the error: $failure');
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SelectableText(
            text,
            maxLines: maxLines,
            style: TextStyle(fontSize: fontSize, color: scheme.error),
          ),
        ),
        IconButton(
          tooltip: 'Copy error',
          visualDensity: VisualDensity.compact,
          onPressed: () => _copy(context),
          icon: Icon(Icons.copy_rounded, size: 15, color: scheme.error),
        ),
      ],
    );
  }
}

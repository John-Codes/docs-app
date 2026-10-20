import 'package:flutter/material.dart';

/// A failed upload or storage problem, in words the user can act on.
///
/// The text selects, so it can be copied out whole — this banner is never
/// truncated, which is why it carries no copy button of its own.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 18, color: scheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: SelectableText(
              message,
              maxLines: 6,
              style: TextStyle(color: scheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

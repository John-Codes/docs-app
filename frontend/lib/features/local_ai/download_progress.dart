import 'package:flutter/material.dart';

/// A labelled progress bar with an optional stop button.
class DownloadProgress extends StatelessWidget {
  const DownloadProgress({
    super.key,
    required this.label,
    required this.value,
    this.onStop,
  });

  final String label;
  final double value;
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: value.clamp(0, 1),
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
        if (onStop != null) ...[
          const SizedBox(height: 8),
          TextButton(onPressed: onStop, child: const Text('Stop downloading')),
        ],
      ],
    );
  }
}

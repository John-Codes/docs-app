import 'package:flutter/material.dart';

import 'document_info.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.document});

  final DocumentInfo document;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = document.isReady
        ? document.draft
              ? 'Draft'
              : 'Ready'
        : document.hasFailed
        ? 'Failed'
        : 'Indexing';
    final color = document.isReady && !document.draft
        ? scheme.primary
        : document.hasFailed
        ? scheme.error
        : scheme.tertiary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

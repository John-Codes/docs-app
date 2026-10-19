import 'package:flutter/material.dart';

import 'upload_button.dart';

class LibraryEmptyState extends StatelessWidget {
  const LibraryEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.auto_stories_outlined, size: 42, color: scheme.primary),
          ),
          const SizedBox(height: 24),
          Text(
            'No documents yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 380,
            child: Text(
              'Upload a PDF to read it here and ask questions about your whole collection.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, height: 1.5),
            ),
          ),
          const SizedBox(height: 24),
          const UploadButton(),
          const SizedBox(height: 10),
          Text(
            'PDF only · up to ${_limit()} MB',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  String _limit() => const String.fromEnvironment('MAX_UPLOAD_MB', defaultValue: '50');
}

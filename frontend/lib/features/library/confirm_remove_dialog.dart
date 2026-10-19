import 'package:flutter/material.dart';

import 'document_info.dart';

Future<bool> confirmRemove(BuildContext context, DocumentInfo document) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Remove document?'),
      content: Text('${document.title} and its chat index will be deleted.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Remove'),
        ),
      ],
    ),
  );
  return confirmed == true;
}

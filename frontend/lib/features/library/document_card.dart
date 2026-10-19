import 'package:flutter/material.dart';

import '../reader/reader_page.dart';
import 'confirm_remove_dialog.dart';
import 'document_info.dart';
import 'document_summary.dart';
import 'library_logic.dart';
import 'status_chip.dart';

class DocumentCard extends StatelessWidget {
  const DocumentCard({super.key, required this.document});

  final DocumentInfo document;

  void _open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ReaderPage(docId: document.id, title: document.title),
      ),
    );
  }

  Future<void> _delete(BuildContext context) async {
    if (await confirmRemove(context, document)) {
      await libraryLogic.remove(document.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: document.isReady ? () => _open(context) : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 8, 16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.menu_book_rounded, color: scheme.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      document.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      documentSummary(document),
                      style: TextStyle(
                        fontSize: 12.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (document.hasFailed && document.error != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        document.error!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: scheme.error),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              StatusChip(document: document),
              IconButton(
                tooltip: 'Remove',
                onPressed: () => _delete(context),
                icon: Icon(Icons.delete_outline_rounded, size: 20, color: scheme.onSurfaceVariant),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

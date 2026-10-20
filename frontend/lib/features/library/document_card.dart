import 'package:flutter/material.dart';

import '../reader/reader_page.dart';
import 'confirm_remove_dialog.dart';
import 'copyable_error.dart';
import 'document_info.dart';
import 'document_summary.dart';
import 'library_logic.dart';
import 'status_chip.dart';

class DocumentCard extends StatefulWidget {
  const DocumentCard({super.key, required this.document});

  final DocumentInfo document;

  @override
  State<DocumentCard> createState() => _DocumentCardState();
}

class _DocumentCardState extends State<DocumentCard> {
  bool _showError = false;

  DocumentInfo get document => widget.document;

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
                      // Two lines hide the reason — which is the one thing
                      // the user needs — so tapping shows all of it, and it
                      // can be copied out whole.
                      CopyableError(
                        document.error!,
                        maxLines: _showError ? 12 : 2,
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _showError = !_showError),
                        child: Padding(
                          // A thin text link is a hard tap target on a
                          // phone, and this is the control that reveals the
                          // one thing a failed document must tell the user.
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            _showError ? 'Show less' : 'Show full error',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: scheme.primary,
                            ),
                          ),
                        ),
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

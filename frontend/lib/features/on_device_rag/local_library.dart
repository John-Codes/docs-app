import 'dart:typed_data';

import '../library/document_info.dart';
import 'document_catalog.dart';
import 'document_ingest.dart';
import 'index_trouble.dart';
import 'passage_budget.dart';

/// The library, backed by this device instead of the server.
///
/// A thin facade so the library UI keeps its shape: list, add, remove.
final localLibrary = LocalLibrary();

class LocalLibrary {
  List<DocumentInfo> list() => documentCatalog.read();

  Future<void> add({
    String? id,
    String? title,
    required String filename,
    required Uint8List bytes,
  }) => documentIngest.add(
    id: id,
    title: title,
    filename: filename,
    bytes: bytes,
  );

  Future<void> remove(String id) async {
    final document = documentCatalog.find(id);
    if (document == null) return;
    await documentIngest.remove(document);
  }

  /// Rebuilds ready documents whose passages came from an older passage
  /// pipeline.
  ///
  /// A pipeline fix can make stored passages wrong without failing them —
  /// leader dots kept in the text, for instance — so a document that is
  /// already ready still has to be rebuilt, or the old passages outlive the
  /// fix. Failed documents are left to [retryFailed], so no document is
  /// rebuilt twice in one heal. Startup calls this only when the version
  /// changed, once per version, so a normal load re-embeds nothing.
  Future<void> reindexOutdated() async {
    final stale = documentCatalog
        .read()
        .where(
          (document) =>
              document.isReady &&
              document.pipelineVersion < onDeviceRagPipelineVersion,
        )
        .toList();
    for (final document in stale) {
      try {
        await documentIngest.rebuild(document);
      } catch (_) {
        // Offline or an unreadable file: the next version change retries.
      }
    }
  }

  /// Re-indexes failed documents that are worth another try.
  ///
  /// Two causes are worth retrying: the passages came from an older pipeline,
  /// which may now split what used to be refused, or the failure was another
  /// tab holding the database open — that cause is gone once its tab closes,
  /// and re-uploading to recover from a locked tab would be a trap. A document
  /// that fails for a reason of its own (a page that cannot be split) is left
  /// alone, so a load never re-embeds it. The file is on the device, so even a
  /// rebuild needs no re-upload.
  Future<void> retryFailed() async {
    for (final document in documentCatalog.read()) {
      if (!document.hasFailed || document.chunks > 0) continue;
      final worthRetrying =
          document.pipelineVersion < onDeviceRagPipelineVersion ||
          isIndexBusy(document.error ?? '');
      if (!worthRetrying) continue;
      try {
        await documentIngest.rebuild(document);
      } catch (_) {
        // Still offline, or the file is unreadable: leave it failed.
      }
    }
  }

  /// Picks up the documents a previous session left mid-index.
  ///
  /// Indexing runs in the background, so closing or reloading the tab in the
  /// middle of one leaves a document that says "Indexing" and never arrives:
  /// nothing was going to finish it. Only the extract survives a reload, so
  /// the text is extracted again — from the server when it is reachable, and
  /// with the on-device parser when it is not — and indexing runs to the end
  /// this time. A document that already indexed is untouched.
  Future<void> resumeInterrupted() async {
    final stranded = documentCatalog
        .read()
        .where((document) => document.isProcessing)
        .toList();
    for (final document in stranded) {
      try {
        await documentIngest.reindexDraft(document);
      } catch (_) {
        // Offline or an unreadable file: the next load tries again.
      }
    }
  }

  /// Re-extracts every document that was read offline with the fallback
  /// parser. Called when the connection comes back; one failure must not
  /// stop the others, so each document is handled on its own.
  Future<void> reindexDrafts() async {
    for (final document in documentCatalog.read()) {
      if (!document.draft || document.status == 'processing') continue;
      try {
        await documentIngest.reindexDraft(document);
      } catch (_) {
        // Still offline or a broken file: try again next time.
      }
    }
  }
}

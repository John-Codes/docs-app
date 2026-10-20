import 'dart:typed_data';

import '../library/document_info.dart';
import 'document_catalog.dart';
import 'document_ingest.dart';

/// The library, backed by this device instead of the server.
///
/// A thin facade so the library UI keeps its shape: list, add, remove.
final localLibrary = LocalLibrary();

class LocalLibrary {
  List<DocumentInfo> list() => documentCatalog.read();

  Future<void> add({required String filename, required Uint8List bytes}) =>
      documentIngest.add(filename: filename, bytes: bytes);

  Future<void> remove(String id) async {
    final document = documentCatalog.find(id);
    if (document == null) return;
    await documentIngest.remove(document);
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

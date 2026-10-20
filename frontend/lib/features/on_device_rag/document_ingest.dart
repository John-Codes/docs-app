import 'dart:async';
import 'dart:typed_data';

import '../library/document_info.dart';
import 'chunker.dart';
import 'document_catalog.dart';
import 'extractor_router.dart';
import 'local_index.dart';
import 'pdf_blob_store.dart';
import 'sequential_model_loader.dart';

/// Turns an uploaded PDF into an on-device, searchable document.
///
/// The file is extracted, stored in the browser and indexed locally; the
/// server is asked only for text extraction. Indexing runs in the
/// background, so the library shows "Indexing" and fills in when done.
final documentIngest = DocumentIngest();

class DocumentIngest {
  /// Extracts and stores the PDF, then indexes it without blocking.
  ///
  /// [id] and [title] are fixed only for documents that ship with the app;
  /// uploads get a fresh id so the same file can be added twice.
  Future<void> add({
    String? id,
    String? title,
    required String filename,
    required Uint8List bytes,
  }) async {
    final docId = id ?? DateTime.now().microsecondsSinceEpoch.toString();
    final extraction = await extractorRouter.extract(filename, bytes);
    await pdfBlobStore.write(docId, bytes);

    final document = DocumentInfo(
      id: docId,
      title: title ?? extraction.title,
      filename: filename,
      status: 'processing',
      pages: extraction.pages.length,
      sizeBytes: bytes.length,
      chunks: 0,
      uploadedAt: DateTime.now().toIso8601String(),
      draft: extraction.draft,
    );
    await documentCatalog.upsert(document);
    unawaited(indexPages(document, extraction.pages));
  }

  /// Splits, embeds and stores every passage, then marks the document ready.
  Future<void> indexPages(DocumentInfo document, List<String> pages) async {
    try {
      final chunks = chunkPages(
        docId: document.id,
        docTitle: document.title,
        pages: pages,
      );
      final indexed = await sequentialModelLoader.run(
        OnDeviceModel.embeddings,
        () => localIndex.addAll(document.id, chunks),
      );
      await documentCatalog.upsert(
        document.copyWith(status: 'ready', chunks: indexed, error: ''),
      );
    } catch (failure) {
      await documentCatalog.upsert(
        document.copyWith(
          status: 'failed',
          error: failure.toString().replaceFirst('Exception: ', ''),
        ),
      );
    }
  }

  /// Deletes the passages, the PDF and the library entry.
  Future<void> remove(DocumentInfo document) async {
    await sequentialModelLoader.run(
      OnDeviceModel.embeddings,
      () => localIndex.removeDocument(document.id, document.chunks),
    );
    await pdfBlobStore.delete(document.id);
    await documentCatalog.remove(document.id);
  }

  /// Re-does a draft extraction with the server parser, then re-indexes it.
  /// Does nothing when the document is gone or the server is unreachable.
  Future<void> reindexDraft(DocumentInfo document) async {
    final bytes = await pdfBlobStore.read(document.id);
    if (bytes == null) return;

    final extraction = await extractorRouter.extractOnServer(
      document.filename,
      bytes,
    );
    await localIndex.removeDocument(document.id, document.chunks);
    final reExtracted = document.copyWith(
      draft: false,
      pages: extraction.pages.length,
      chunks: 0,
      status: 'processing',
      error: '',
    );
    await documentCatalog.upsert(reExtracted);
    await indexPages(reExtracted, extraction.pages);
  }
}

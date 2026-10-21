import 'dart:async';

import 'package:flutter/foundation.dart';

import '../library/document_info.dart';
import '../local_ai/local_ai_state.dart';
import 'chunker.dart';
import 'document_catalog.dart';
import 'extractor_router.dart';
import 'index_trouble.dart';
import 'local_index.dart';
import 'pdf_blob_store.dart';
import 'search_model_store.dart';
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
  ///
  /// Passages are sized with the embedder's own tokenizer, so the budget is
  /// exact rather than guessed; a page that cannot be split without cutting
  /// a word fails the document with the page named, and nothing of it stays
  /// retrievable.
  Future<void> indexPages(DocumentInfo document, List<String> pages) async {
    try {
      if (!await _searchModelReady()) {
        throw StateError(
          'The on-device search model is not installed. Install it from '
          'the AI menu, then upload the document again.',
        );
      }
      final indexed = await sequentialModelLoader.run(
        OnDeviceModel.embeddings,
        () async {
          await localIndex.open();
          await localIndex.loadEmbedder();
          final chunks = chunkPages(
            docId: document.id,
            docTitle: document.title,
            pages: pages,
            countTokens: localIndex.passageTokenCounter,
            maxTokens: localIndex.maxPassageTokens,
          );
          return localIndex.addAll(document.id, chunks);
        },
      );
      await documentCatalog.upsert(
        document.copyWith(
          status: 'ready',
          chunks: indexed,
          error: '',
          pipelineVersion: onDeviceRagPipelineVersion,
        ),
      );
    } catch (failure) {
      // The stored message is what the library shows, so it must say what
      // to do next; the raw exception stays in the console for bug reports.
      debugPrint('[on-device-rag] indexing failed: $failure');
      await documentCatalog.upsert(
        document.copyWith(status: 'failed', error: describeIndexFailure(failure)),
      );
    }
  }

  /// True when the embedder can run: already installed, or a download the
  /// user started is under way. A document uploaded before the model exists
  /// waits for that download instead of failing, and never starts one.
  Future<bool> _searchModelReady() async {
    if (searchModelStore.isInstalled) return true;
    if (!localAiState.searchDownloadActive) return false;
    return searchModelStore.whenReady();
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

  /// Rebuilds a document's passages with the current pipeline.
  ///
  /// Called when the passage pipeline changed, so it must not depend on the
  /// server being up: the file is on the device, and the on-device parser
  /// can read it. Server text is still preferred when it is reachable, since
  /// it is the better extraction. A document whose file is gone is left
  /// alone rather than failed — there is nothing to rebuild it from.
  Future<void> rebuild(DocumentInfo document) async {
    final bytes = await pdfBlobStore.read(document.id);
    if (bytes == null) return;

    final extraction = await extractorRouter.extract(document.filename, bytes);
    await localIndex.removeDocument(document.id, document.chunks);
    final rebuilt = document.copyWith(
      draft: extraction.draft,
      pages: extraction.pages.length,
      chunks: 0,
      status: 'processing',
      error: '',
    );
    await documentCatalog.upsert(rebuilt);
    await indexPages(rebuilt, extraction.pages);
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

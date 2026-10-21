import 'package:flutter/foundation.dart';
import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_edge_ai_rag/flutter_edge_ai_rag.dart';
import 'package:flutter_edge_ai_sqlite/flutter_edge_ai_sqlite.dart';

import 'chunker.dart';
import 'embedder_token_counter.dart';
import 'index_trouble.dart';
import 'rag_chunk.dart';
import 'search_model_store.dart';
import 'sequential_model_loader.dart';

/// The on-device vector index: SQLite with the `vec0` extension, persisted
/// in the browser (OPFS/IndexedDB, with cross-origin isolation).
///
/// Opened lazily and closed whenever the answer model needs the memory
/// back. Every passage and its vector stay on the device.
final localIndex = LocalIndex();

class LocalIndex {
  static const _location = 'docs_app_knowledge.db';
  static const _namespace = 'docs';

  RagIndex? _index;

  Future<RagIndex> open() async {
    final existing = _index;
    if (existing != null) return existing;

    if (!await searchModelStore.ensureInstalled()) {
      throw StateError('The on-device search model is not installed.');
    }
    final rag = FlutterEdgeAiRag(
      providers: const [SqliteVectorStoreProvider()],
    );
    final spec = VectorStoreSpec(providerId: 'sqlite', location: _location);
    if (!rag.canOpen(spec)) {
      throw UnsupportedError('SQLite vector search is unavailable here.');
    }

    final embedder = FlutterEdgeAiActiveEmbedder.forActiveModel(
      namespace: _namespace,
    );
    // The database is exclusive across tabs, so a second tab — or a tab
    // that still holds it while closing — is refused outright. Wait a few
    // seconds for that holder to let go, then fail with a reason the user
    // can act on instead of a raw storage exception.
    Object? busy;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final index = await rag.open(spec: spec, embedder: embedder);
        _index = index;
        sequentialModelLoader.unloadEmbeddings = close;
        return index;
      } catch (failure) {
        if (!isIndexBusy(failure)) rethrow;
        busy = failure;
        debugPrint('[on-device-rag] index busy, waiting (attempt $attempt)');
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
    // Hand the original exception up: every surface runs it through
    // describeIndexFailure, which needs the raw text to recognize the cause.
    throw busy!;
  }

  /// Indexes one document's passages as `<doc id>:<position>` and flushes.
  ///
  /// A passage is embedded with the text the splitter measured (plus at most
  /// a few carried words), and stored with its clean text. If the runtime
  /// ever still refuses a passage, it is re-split at word boundaries under a
  /// smaller budget; if that cannot succeed the document fails and the
  /// passages already stored are removed — a half-indexed document never
  /// answers.
  Future<int> addAll(String docId, List<RagChunk> chunks) async {
    final index = await open();
    var position = 0;

    Future<void> addOne(RagChunk chunk, {required bool mayResplit}) async {
      try {
        await index.add(
          id: '$docId:$position',
          document: EmbeddingInput.text(chunk.embeddingInput),
          content: chunk.text,
          metadata: chunk.toMetadata(),
        );
        position++;
      } on EmbeddingInputTooLongException {
        if (!mayResplit) rethrow;
        final pieces = chunkPages(
          docId: chunk.docId,
          docTitle: chunk.docTitle,
          pages: [chunk.text],
          countTokens: passageTokenCounter,
          maxTokens: maxPassageTokens ~/ 2,
        );
        for (final piece in pieces) {
          await addOne(piece, mayResplit: false);
        }
      }
    }

    try {
      for (final chunk in chunks) {
        await addOne(chunk, mayResplit: true);
      }
      await index.flush();
      return position;
    } catch (_) {
      try {
        await removeDocument(docId, position);
      } catch (_) {
        // The index may be gone; the original failure still matters.
      }
      rethrow;
    }
  }

  /// Loads the embedding model (and its tokenizer) so passages can be sized
  /// to the real token budget before the first embedding.
  Future<void> loadEmbedder() async {
    await FlutterEdgeAi.getActiveEmbedder();
  }

  /// Counts a passage's tokens exactly as the embedder will.
  TokenCounter get passageTokenCounter => countEmbedderTokens;

  /// The largest passage the embedder accepts, prefix included.
  int get maxPassageTokens => embedderMaxInputTokens();

  Future<List<RagChunk>> search(String question, {int topK = 8}) async {
    final index = await open();
    final hits = await index.search(
      query: EmbeddingInput.text(question),
      topK: topK,
      threshold: 0.2,
    );
    return [
      for (final hit in hits)
        RagChunk.fromHit(
          content: hit.content,
          metadata: hit.metadata,
          score: hit.similarity,
        ),
    ];
  }

  /// Removes every passage of a document (its ids are sequential).
  Future<void> removeDocument(String docId, int chunks) async {
    final index = _index;
    if (index == null || chunks == 0) return;
    for (var position = 0; position < chunks; position++) {
      await index.remove(id: '$docId:$position');
    }
    await index.flush();
  }

  /// Disposes the index and closes the embedding model, freeing both the
  /// SQLite connection and the ~110 MB of model weights.
  Future<void> close() async {
    final index = _index;
    _index = null;
    if (index != null) {
      try {
        await index.flush();
      } catch (_) {
        // Nothing to flush when storage is gone; close anyway.
      }
      await index.dispose();
    }
    try {
      final embedder = await FlutterEdgeAi.getActiveEmbedder();
      await embedder.close();
    } catch (_) {
      // Not loaded (or already gone) — nothing to release.
    }
    sequentialModelLoader.markClosed(OnDeviceModel.embeddings);
  }
}

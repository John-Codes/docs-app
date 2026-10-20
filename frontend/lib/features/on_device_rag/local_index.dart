import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_edge_ai_rag/flutter_edge_ai_rag.dart';
import 'package:flutter_edge_ai_sqlite/flutter_edge_ai_sqlite.dart';

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

    final index = await rag.open(
      spec: spec,
      embedder: FlutterEdgeAiActiveEmbedder.forActiveModel(
        namespace: _namespace,
      ),
    );
    _index = index;
    sequentialModelLoader.unloadEmbeddings = close;
    return index;
  }

  /// Indexes one document's passages as `<doc id>:<position>` and flushes.
  Future<void> addAll(String docId, List<RagChunk> chunks) async {
    final index = await open();
    for (var position = 0; position < chunks.length; position++) {
      final chunk = chunks[position];
      await index.add(
        id: '$docId:$position',
        document: EmbeddingInput.text(chunk.text),
        content: chunk.text,
        metadata: chunk.toMetadata(),
      );
    }
    await index.flush();
  }

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

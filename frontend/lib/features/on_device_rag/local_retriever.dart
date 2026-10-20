import 'package:flutter/foundation.dart';

import 'local_index.dart';
import 'rag_chunk.dart';
import 'sequential_model_loader.dart';

/// Finds the passages that answer a question — entirely on the device.
///
/// An empty list means "no matching passage"; a thrown error means search
/// itself could not run. The chat keeps those apart, so a broken embedder
/// never masquerades as "the documents don't cover that". Nothing here ever
/// touches the network.
final localRetriever = LocalRetriever();

class LocalRetriever {
  static const _limit = 8;

  Future<List<RagChunk>> retrieve(String question) async {
    try {
      return await sequentialModelLoader.run(
        OnDeviceModel.embeddings,
        () => localIndex.search(question, topK: _limit),
      );
    } catch (failure) {
      debugPrint('[on-device-rag] retrieval failed: $failure');
      rethrow;
    }
  }
}

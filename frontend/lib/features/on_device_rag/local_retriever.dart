import 'package:flutter/foundation.dart';

import 'leader_dots.dart';
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

  /// Passages that carry words, best first.
  ///
  /// A passage of pure layout — a rule, a run of bullets, a page number
  /// floating in whitespace — matches loosely, then gives the model nothing
  /// to answer from. Such hits are dropped; if that leaves nothing, the
  /// caller sees an empty list and says the documents do not cover the
  /// question rather than writing an answer out of punctuation.
  Future<List<RagChunk>> retrieve(String question) async {
    try {
      final hits = await sequentialModelLoader.run(
        OnDeviceModel.embeddings,
        () => localIndex.search(question, topK: _limit),
      );
      final usable = hits
          .where((chunk) => !isMostlyPunctuation(chunk.text))
          .toList();
      if (usable.length < hits.length) {
        debugPrint(
          '[on-device-rag] dropped ${hits.length - usable.length} of '
          '${hits.length} passages as punctuation only',
        );
      }
      return usable;
    } catch (failure) {
      debugPrint('[on-device-rag] retrieval failed: $failure');
      rethrow;
    }
  }
}

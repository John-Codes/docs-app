import 'local_index.dart';
import 'rag_chunk.dart';
import 'sequential_model_loader.dart';

/// Finds the passages that answer a question — entirely on the device.
///
/// Returns an empty list on any failure (model missing, index locked,
/// embedding error): the chat then answers "the documents don't cover
/// that", exactly as the server would with no excerpts. Nothing here ever
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
    } catch (_) {
      return const [];
    }
  }
}

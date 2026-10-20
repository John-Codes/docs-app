import '../../core/api/api_client.dart';
import '../on_device_rag/rag_chunk.dart';
import 'chat_message.dart';
import 'chat_source.dart';

class ChatReply {
  const ChatReply({required this.answer, required this.sources});

  final String answer;
  final List<ChatSource> sources;
}

class ChatApi {
  ChatApi([ApiClient? api]) : _api = api ?? ApiClient();

  final ApiClient _api;

  /// Asks the cloud model to answer from excerpts retrieved on this device.
  /// The backend has no document store: these excerpts are all it knows.
  Future<ChatReply> ask(
    String message,
    List<ChatMessage> history,
    List<RagChunk> excerpts,
  ) async {
    final recent = history.where((turn) => !turn.isLoading).toList();
    final start = recent.length > 6 ? recent.length - 6 : 0;
    final data =
        await _api.postJson('/chat', {
              'message': message,
              'history': [
                for (final turn in recent.sublist(start))
                  {
                    'role': turn.isUser ? 'user' : 'assistant',
                    'content': turn.text,
                  },
              ],
              'excerpts': [
                for (final chunk in excerpts)
                  {
                    'doc_id': chunk.docId,
                    'doc_title': chunk.docTitle,
                    'page': chunk.page,
                    'score': chunk.score,
                    'text': chunk.text,
                  },
              ],
            })
            as Map<String, dynamic>;

    final sources = (data['sources'] as List? ?? const [])
        .map((item) => ChatSource.fromJson(item as Map<String, dynamic>))
        .toList();
    return ChatReply(
      answer: data['answer']?.toString() ?? '',
      sources: sources,
    );
  }
}

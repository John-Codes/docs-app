import '../../core/api/api_client.dart';
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

  Future<ChatReply> ask(String message, List<ChatMessage> history) async {
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

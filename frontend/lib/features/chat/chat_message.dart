import 'chat_source.dart';

class ChatMessage {
  const ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.sources = const [],
    this.isLoading = false,
  });

  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<ChatSource> sources;
  final bool isLoading;
}

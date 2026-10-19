import 'package:flutter/material.dart';

import 'chat_api.dart';
import 'chat_message.dart';

final chatLogic = ChatLogic();

class ChatLogic extends ChangeNotifier {
  ChatLogic() {
    messages.add(
      ChatMessage(
        text:
            'Ask anything about the documents in your library. '
            'Every answer cites the page it came from.',
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  final List<ChatMessage> messages = [];
  final TextEditingController textController = TextEditingController();
  final FocusNode focusNode = FocusNode();
  final ChatApi _api = ChatApi();
  bool isLoading = false;

  Future<void> sendMessage() async {
    final text = textController.text.trim();
    if (text.isEmpty || isLoading) return;

    final history = List<ChatMessage>.from(messages);
    textController.clear();
    messages.add(
      ChatMessage(text: text, isUser: true, timestamp: DateTime.now()),
    );
    isLoading = true;
    notifyListeners();

    try {
      final reply = await _api.ask(text, history);
      messages.add(
        ChatMessage(
          text: reply.answer.isEmpty
              ? "The documents don't cover that."
              : reply.answer,
          isUser: false,
          timestamp: DateTime.now(),
          sources: reply.sources,
        ),
      );
    } catch (failure) {
      messages.add(
        ChatMessage(
          text:
              'Something went wrong. '
              '${failure.toString().replaceFirst('Exception: ', '')}',
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
    }

    isLoading = false;
    notifyListeners();
    focusNode.requestFocus();
  }
}

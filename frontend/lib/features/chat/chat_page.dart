import 'package:flutter/material.dart';

import '../local_ai/local_ai.dart';
import 'chat_input_bar.dart';
import 'chat_logic.dart';
import 'chat_message_bubble.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    chatLogic.addListener(_scrollToBottom);
  }

  @override
  void dispose() {
    chatLogic.removeListener(_scrollToBottom);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920),
        child: Column(
          children: [
            Expanded(
              child: ListenableBuilder(
                listenable: chatLogic,
                builder: (context, _) => ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                  itemCount: chatLogic.messages.length,
                  itemBuilder: (context, index) => ChatMessageBubble(
                    message: chatLogic.messages[index],
                  ),
                ),
              ),
            ),
            const LocalModeBar(),
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: const ChatInputBar(),
            ),
          ],
        ),
      ),
    );
  }
}

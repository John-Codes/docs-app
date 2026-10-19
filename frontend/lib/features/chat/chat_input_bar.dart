import 'package:flutter/material.dart';

import 'chat_logic.dart';
import 'chat_send_button.dart';

class ChatInputBar extends StatelessWidget {
  const ChatInputBar({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: chatLogic,
      builder: (context, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (chatLogic.isLoading) const LinearProgressIndicator(minHeight: 2),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: chatLogic.textController,
                    focusNode: chatLogic.focusNode,
                    minLines: 1,
                    maxLines: 6,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => chatLogic.sendMessage(),
                    decoration: const InputDecoration(
                      hintText: 'Ask about your documents…',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const ChatSendButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

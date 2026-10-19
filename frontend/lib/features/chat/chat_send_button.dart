import 'package:flutter/material.dart';

import 'chat_logic.dart';

class ChatSendButton extends StatelessWidget {
  const ChatSendButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([chatLogic, chatLogic.textController]),
      builder: (context, _) {
        final canSend =
            chatLogic.textController.text.trim().isNotEmpty &&
            !chatLogic.isLoading;
        return IconButton.filled(
          tooltip: 'Send',
          onPressed: canSend ? chatLogic.sendMessage : null,
          style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
          icon: const Icon(Icons.arrow_upward_rounded),
        );
      },
    );
  }
}

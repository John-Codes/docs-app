import 'package:flutter/material.dart';

import 'chat_logic.dart';

class ChatSendButton extends StatelessWidget {
  const ChatSendButton({
    super.key,
    this.isLoading = false,
  });

  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([chatLogic, chatLogic.textController]),
      builder: (context, _) {
        final canSend =
            chatLogic.textController.text.trim().isNotEmpty &&
            !chatLogic.isLoading &&
            !isLoading;
        return IconButton.filled(
          tooltip: 'Send',
          onPressed: canSend ? chatLogic.sendMessage : null,
          style: IconButton.styleFrom(
            minimumSize: const Size(44, 44),
            padding: EdgeInsets.zero,
          ),
          icon: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.arrow_upward_rounded, size: 22),
        );
      },
    );
  }
}
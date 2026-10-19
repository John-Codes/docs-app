import 'package:flutter/material.dart';

import 'chat_input_border_painter.dart';
import 'chat_logic.dart';
import 'chat_send_button.dart';

class ChatInputBar extends StatefulWidget {
  const ChatInputBar({super.key});

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  late final FocusNode _focusNode;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _focusNode = chatLogic.focusNode;
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus != _hasFocus) {
      setState(() {
        _hasFocus = _focusNode.hasFocus;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: chatLogic,
      builder: (context, _) {
        final scheme = Theme.of(context).colorScheme;
        final isLoading = chatLogic.isLoading;

        return AnimatedGradientBorder(
          isLoading: isLoading,
          borderRadius: const BorderRadius.all(Radius.circular(24)),
          strokeWidth: isLoading ? 4 : 0,
          gradientColors: [
            Colors.cyanAccent,
            Colors.blueAccent,
            Colors.purpleAccent,
            Colors.pinkAccent,
            Colors.cyanAccent,
          ],
          animationDuration: const Duration(milliseconds: 1200),
          child: Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: const BorderRadius.all(Radius.circular(24)),
              border: Border.all(
                color: _hasFocus
                    ? scheme.primary
                    : (isLoading
                        ? Colors.transparent
                        : scheme.outlineVariant),
                width: _hasFocus || isLoading ? 2.5 : 1.5,
              ),
              boxShadow: _hasFocus
                  ? [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.15),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Text field expands to fill available space
                Expanded(
                  child: TextField(
                    controller: chatLogic.textController,
                    focusNode: _focusNode,
                    minLines: 1,
                    maxLines: 6,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => chatLogic.sendMessage(),
                    enabled: !isLoading,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 15,
                      height: 1.45,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Ask about your documents…',
                      hintStyle: TextStyle(
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                        fontSize: 15,
                        height: 1.45,
                      ),
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      isDense: true,
                    ),
                  ),
                ),
                // Send button
                const SizedBox(width: 4),
                ChatSendButton(isLoading: isLoading),
              ],
            ),
          ),
        );
      },
    );
  }
}
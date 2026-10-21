import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import 'chat_markdown_styles.dart';
import 'chat_message.dart';
import 'citation_links.dart';
import 'copy_answer_button.dart';
import 'open_citation.dart';
import 'source_card.dart';

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (message.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 620),
          margin: const EdgeInsets.only(left: 48, top: 6, bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(6),
            ),
          ),
          child: Text(
            message.text,
            style: TextStyle(
              color: scheme.onPrimary,
              fontSize: 15,
              height: 1.45,
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(right: 24, top: 6, bottom: 6),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest,
              border: Border.all(color: scheme.outlineVariant),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(6),
                bottomRight: Radius.circular(18),
              ),
            ),
            child: message.isLoading && message.text.isEmpty
                ? Text(
                    'Thinking…',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 15,
                    ),
                  )
                : MarkdownBody(
                    data: linkifyCitations(message.text, message.sources),
                    selectable: true,
                    styleSheet: chatMarkdownStyles(context),
                    onTapLink: (text, href, title) {
                      final source = citationForLink(href, message.sources);
                      if (source != null) openCitation(context, source);
                    },
                  ),
          ),
          if (message.sources.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final source in message.sources)
                    SourceCard(source: source),
                ],
              ),
            ),
          CopyAnswerButton(text: message.text),
        ],
      ),
    );
  }
}

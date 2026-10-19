import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

MarkdownStyleSheet chatMarkdownStyles(BuildContext context) {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  final body = theme.textTheme.bodyMedium?.copyWith(
    fontSize: 15,
    height: 1.6,
    color: scheme.onSurface,
  );

  return MarkdownStyleSheet(
    p: body,
    a: body?.copyWith(
      color: scheme.primary,
      decoration: TextDecoration.underline,
      decorationColor: scheme.primary,
    ),
    h1: body?.copyWith(fontSize: 23, fontWeight: FontWeight.w600, height: 1.3),
    h2: body?.copyWith(fontSize: 19, fontWeight: FontWeight.w600, height: 1.35),
    h3: body?.copyWith(fontSize: 16.5, fontWeight: FontWeight.w600, height: 1.4),
    strong: body?.copyWith(fontWeight: FontWeight.w700),
    em: body?.copyWith(fontStyle: FontStyle.italic),
    listBullet: body,
    blockSpacing: 10,
    listIndent: 22,
    code: TextStyle(
      fontFamily: 'monospace',
      fontSize: 13.5,
      backgroundColor: scheme.surfaceContainerLow,
      color: scheme.onSurface,
    ),
    codeblockDecoration: BoxDecoration(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: scheme.outlineVariant),
    ),
    codeblockPadding: const EdgeInsets.all(12),
    blockquote: body?.copyWith(color: scheme.onSurfaceVariant),
    blockquoteDecoration: BoxDecoration(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(8),
    ),
    blockquotePadding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
    horizontalRuleDecoration: BoxDecoration(
      border: Border(top: BorderSide(color: scheme.outlineVariant)),
    ),
  );
}

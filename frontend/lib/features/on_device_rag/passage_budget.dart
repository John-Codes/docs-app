/// Bumped whenever passage building changes. A document that failed under
/// an older value is retried once when this changes — never on every load.
const onDeviceRagPipelineVersion = 2;

/// Measures a text exactly as the embedder will: task prefix, BOS and EOS
/// included. Provided by the index, which owns the loaded tokenizer.
typedef TokenCounter = int Function(String text);

/// A passage that cannot be split without cutting a word. Nothing is ever
/// cut: a severed number or identifier is worse than a failed document.
class UnbreakablePassageError implements Exception {
  UnbreakablePassageError({
    required this.page,
    required this.snippet,
    required this.tokens,
    required this.budget,
  });

  /// 1-based, the page the reader shows too.
  final int page;

  /// The offending run, shortened so the message stays readable.
  final String snippet;
  final int tokens;
  final int budget;

  @override
  String toString() => 'Page $page has a single run of $tokens tokens '
      '(limit $budget) that cannot be split without cutting it: '
      '"$snippet". Remove the document or replace that part of the PDF.';
}

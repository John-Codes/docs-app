import 'leader_dots.dart';
import 'passage_budget.dart';
import 'rag_chunk.dart';
import 'seam_overlap.dart';
import 'text_units.dart';

export 'passage_budget.dart';

/// Default budget when the embedder is not there to ask: comfortably under
/// the 256 tokens the search model takes, task prefix included.
const _defaultBudget = 240;

/// Splits each page into passages the embedder accepts.
///
/// Split points fall only between words — sentence ends and line breaks
/// first, clauses next — and the passages of a page join back into the page
/// exactly, so no word, number or identifier can be lost or severed. A page
/// that cannot be split within the budget fails with [UnbreakablePassageError]
/// instead of being silently dropped.
///
/// Leader dots are collapsed first: they are the layout between a heading
/// and its page number, not content, and left in they would be most of a
/// table-of-contents page's characters — enough to dominate its embedding
/// and to leave a model reading nothing but dots. Every word and number
/// still lands in exactly one passage.
List<RagChunk> chunkPages({
  required String docId,
  required String docTitle,
  required List<String> pages,
  required TokenCounter countTokens,
  int? maxTokens,
}) {
  final budget = maxTokens ?? _defaultBudget;
  final chunks = <RagChunk>[];
  for (var index = 0; index < pages.length; index++) {
    final page = collapseLeaderDots(normalizePage(pages[index]));
    final units = TextUnits.of(page);
    if (units.isEmpty) continue;

    final pageChunks = _pageChunks(
      units: units,
      docId: docId,
      docTitle: docTitle,
      page: index + 1,
      countTokens: countTokens,
      budget: budget,
    );
    assert(
      pageChunks.map((chunk) => chunk.text).join() == page,
      'passage split lost or altered text on page ${index + 1}',
    );
    chunks.addAll(pageChunks);
  }
  return chunks;
}

List<RagChunk> _pageChunks({
  required TextUnits units,
  required String docId,
  required String docTitle,
  required int page,
  required TokenCounter countTokens,
  required int budget,
}) {
  final chunks = <RagChunk>[];
  var start = 0;
  var carry = '';
  while (start < units.words.length) {
    // Leave room for the carried words, so the seam text still fits; a
    // single word that needs the whole budget still gets it.
    var packBudget = budget;
    if (carry.isNotEmpty) {
      packBudget -= seamReserve(budget);
      if (countTokens(units.range(start, start)) > packBudget) {
        packBudget = budget;
      }
    }
    final end = _fill(units, start, countTokens, packBudget, budget, page);
    final text = units.range(start, end);
    chunks.add(
      RagChunk(
        docId: docId,
        docTitle: docTitle,
        page: page,
        text: text,
        embeddingText: seamText(
          carry: carry,
          text: text,
          countTokens: countTokens,
          budget: budget,
        ),
      ),
    );
    carry = seamCarry(text);
    start = end + 1;
  }
  return chunks;
}

/// The largest word range that fits [packBudget], broken at the best
/// boundary. [budget] is the hard limit the embedder enforces.
int _fill(
  TextUnits units,
  int start,
  TokenCounter countTokens,
  int packBudget,
  int budget,
  int page,
) {
  var low = start;
  var high = units.words.length - 1;
  while (low < high) {
    final middle = (low + high + 1) ~/ 2;
    if (countTokens(units.range(start, middle)) <= packBudget) {
      low = middle;
    } else {
      high = middle - 1;
    }
  }
  final single = countTokens(units.range(start, start));
  if (single > budget) {
    throw UnbreakablePassageError(
      page: page,
      snippet: _snippet(units.words[start]),
      tokens: single,
      budget: budget,
    );
  }
  final window = ((low - start) ~/ 3).clamp(1, 40);
  for (var i = low; i >= low - window && i > start; i--) {
    if (units.endsSentence(i)) return i;
  }
  for (var i = low; i >= low - window && i > start; i--) {
    if (units.endsClause(i)) return i;
  }
  return low;
}

String _snippet(String word) =>
    word.length <= 60 ? word : '${word.substring(0, 57)}…';

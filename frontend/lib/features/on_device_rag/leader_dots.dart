/// Repairs the leader dots a PDF puts between a heading and its page number.
///
/// A table of contents extracts as `Rig lubrication ............. 12`. Those
/// runs are the one thing in a PDF that is pure layout: they carry no words,
/// but they are most of the characters on the page, so they swamp both the
/// embedding of a passage and the prompt an answer is written from — the
/// model ends up reading a wall of dots and echoing it back.
///
/// Collapsing each run to a single space keeps every word and every number
/// exactly where it was, which is what the passage keeps and what a citation
/// shows. Nothing else about the page changes.
library;

/// A run of four or more dots, spaced or not, used as a leader.
///
/// Four is the threshold that separates a leader from real punctuation:
/// an ellipsis is three dots, a dotted part number (`TT-660..A`) has two,
/// and a version (`1.2.3`) has one. Runs this long are always layout.
final _leader = RegExp(r'(?:\.\s*){4,}');

/// `Draining the reclaimer ..... 42` becomes `Draining the reclaimer 42`.
String collapseLeaderDots(String text) {
  if (!text.contains('.')) return text;
  return text.replaceAll(_leader, ' ').replaceAll(RegExp(r' {2,}'), ' ');
}

/// True when a passage is mostly punctuation — leader dots, rules, bullets —
/// and so cannot answer anything on its own.
///
/// Used to keep such a passage out of the answer prompt: a page that is 80%
/// dots will match loosely and then contribute nothing but noise, which is
/// how a confident-looking answer of dots gets written.
bool isMostlyPunctuation(String text) {
  var letters = 0;
  var marks = 0;
  var digits = 0;
  for (final rune in text.runes) {
    final char = String.fromCharCode(rune);
    if (RegExp(r'[A-Za-z]').hasMatch(char)) {
      letters++;
    } else if (RegExp(r'[0-9]').hasMatch(char)) {
      digits++;
    } else if (!RegExp(r'\s').hasMatch(char)) {
      marks++;
    }
  }
  final total = letters + marks + digits;
  if (total < 20) return false;
  // Words are needed to answer: a passage needs some letters, and few
  // non-word characters, to be worth showing the model.
  if (letters < total * 0.35) return true;
  return marks > letters * 1.5;
}

/// A page as words plus the exact whitespace between them.
///
/// Every passage the chunker produces is a range of these words with the
/// original separators kept, so joining the passages of a page reproduces
/// the page exactly: no word, number or identifier can be lost or cut.
class TextUnits {
  TextUnits._(this._separators, this.words);

  /// [separators][i] is the whitespace that sits before [words][i]; the
  /// first separator is '' unless the text starts with whitespace.
  final List<String> _separators;
  final List<String> words;

  factory TextUnits.of(String text) {
    final words = <String>[];
    final separators = <String>[];
    var position = 0;
    var pending = '';
    for (final match in RegExp(r'\s+').allMatches(text)) {
      if (match.start > position) {
        separators.add(words.isEmpty && position == 0 ? '' : pending);
        words.add(text.substring(position, match.start));
      }
      pending = match.group(0)!;
      position = match.end;
    }
    if (position < text.length) {
      separators.add(pending);
      words.add(text.substring(position));
    }
    return TextUnits._(separators, words);
  }

  bool get isEmpty => words.isEmpty;

  /// The words from [start] to [end] inclusive, with their separators.
  String range(int start, int end) {
    final buffer = StringBuffer();
    for (var i = start; i <= end; i++) {
      buffer
        ..write(_separators[i])
        ..write(words[i]);
    }
    return buffer.toString();
  }

  /// The separator in front of [index], '' at the very start.
  String separatorBefore(int index) =>
      index < _separators.length ? _separators[index] : '';

  bool endsSentence(int index) {
    if (separatorAfter(index).contains('\n')) return true;
    final word = words[index];
    return word.isNotEmpty &&
        RegExp(r'[.?!;:]$').hasMatch(word) &&
        // A decimal ("4.5") or version ("1.2.3") is not a sentence end.
        !RegExp(r'\d[.?!;:]$').hasMatch(word);
  }

  bool endsClause(int index) {
    if (endsSentence(index)) return true;
    if (separatorAfter(index).contains('\n')) return true;
    return words[index].endsWith(',');
  }

  /// The separator behind [index], '' when it is the last word.
  String separatorAfter(int index) => separatorBefore(index + 1);
}

/// Whitespace the chunker may tidy without losing a word: table tabs become
/// spaces and blank-line runs collapse, while line breaks — where a table
/// row ends — survive.
String normalizePage(String raw) {
  final lines =
      raw.replaceAll('\t', ' ').split('\n').map((line) => line.trim()).toList();
  while (lines.isNotEmpty && lines.first.isEmpty) {
    lines.removeAt(0);
  }
  while (lines.isNotEmpty && lines.last.isEmpty) {
    lines.removeLast();
  }
  final tidy = <String>[];
  for (final line in lines) {
    final collapsed = line.replaceAll(RegExp(r' {2,}'), ' ');
    if (collapsed.isEmpty && tidy.isNotEmpty && tidy.last.isEmpty) continue;
    tidy.add(collapsed);
  }
  return tidy.join('\n');
}

import 'passage_budget.dart';

/// The seam between two passages: a few words of the previous one are
/// carried into this passage's embedding input, so a value and its unit
/// stay together where the text was cut. Stored text stays clean — nothing
/// is duplicated in citations or in the answer prompt.
const _carryWords = 10;

/// Roughly the tokens the carried words cost, held back from every passage
/// after the first so the seam text has somewhere to go.
int seamReserve(int budget) {
  final reserve = budget ~/ 6;
  return reserve < 8 ? 8 : reserve;
}

/// The last [_carryWords] words of a passage, the ones worth carrying.
String seamCarry(String text) {
  final words = text.split(' ');
  return words.length <= _carryWords
      ? text
      : words.sublist(words.length - _carryWords).join(' ');
}

/// [carry] in front of [text], trimmed word by word until the result still
/// fits [budget] — or dropped entirely, when even one carried word does not.
String seamText({
  required String carry,
  required String text,
  required TokenCounter countTokens,
  required int budget,
}) {
  var words = carry.isEmpty ? const <String>[] : carry.split(' ');
  while (words.isNotEmpty &&
      countTokens('${words.join(' ')} $text') > budget) {
    words = words.sublist(1);
  }
  return words.isEmpty ? text : '${words.join(' ')} $text';
}

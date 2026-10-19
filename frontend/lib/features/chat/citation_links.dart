import 'chat_source.dart';

final _markerPattern = RegExp(r'\[(\d{1,2})\]');

/// Turns [1]-style markers into markdown links that open the cited page.
String linkifyCitations(String text, List<ChatSource> sources) {
  return text.replaceAllMapped(_markerPattern, (match) {
    final number = int.parse(match.group(1)!);
    final known = sources.any((source) => source.index == number);
    return known ? '[${match.group(0)}](cite:$number)' : match.group(0)!;
  });
}

/// Resolves a tapped citation link back to its source, or null when unknown.
ChatSource? citationForLink(String? href, List<ChatSource> sources) {
  if (href == null || !href.startsWith('cite:')) return null;
  final number = int.tryParse(href.substring('cite:'.length));
  if (number == null) return null;
  for (final source in sources) {
    if (source.index == number) return source;
  }
  return null;
}

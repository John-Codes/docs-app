import 'dart:math' as math;

import 'rag_chunk.dart';

/// Words per passage and overlap between neighbouring passages.
///
/// Gecko 256 accepts 256 tokens (task prefix, BOS and EOS included), so a
/// passage stays well under that: ~140 words is ~190 tokens of PDF text.
const _chunkWords = 140;
const _overlapWords = 30;

/// Splits the extracted pages into passages an embedding model can take.
///
/// Chunks never cross a page boundary, so every citation points at exactly
/// one page.
List<RagChunk> chunkPages({
  required String docId,
  required String docTitle,
  required List<String> pages,
}) {
  final chunks = <RagChunk>[];
  for (var index = 0; index < pages.length; index++) {
    final words = _words(pages[index]);
    if (words.isEmpty) continue;
    var start = 0;
    while (start < words.length) {
      final end = math.min(start + _chunkWords, words.length);
      chunks.add(
        RagChunk(
          docId: docId,
          docTitle: docTitle,
          page: index + 1,
          text: words.sublist(start, end).join(' '),
        ),
      );
      if (end >= words.length) break;
      start = end - _overlapWords;
    }
  }
  return chunks;
}

List<String> _words(String text) =>
    text.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).toList();

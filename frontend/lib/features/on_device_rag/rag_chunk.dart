import 'dart:convert';

/// One passage of a document, with everything a citation needs.
///
/// Retrieved on the device and handed to either answer path: the cloud
/// proxy receives them as excerpts, the on-device model as prompt text.
class RagChunk {
  const RagChunk({
    required this.docId,
    required this.docTitle,
    required this.page,
    required this.text,
    this.embeddingText,
    this.score = 0,
  });

  factory RagChunk.fromHit({
    required String content,
    required String? metadata,
    required double score,
  }) {
    final data = _decode(metadata);
    return RagChunk(
      docId: data['doc_id']?.toString() ?? '',
      docTitle: data['doc_title']?.toString() ?? 'Untitled',
      page: (data['page'] as num?)?.toInt() ?? 0,
      text: content,
      score: score,
    );
  }

  final String docId;
  final String docTitle;

  /// 1-based, exactly as the reader and the citation show it.
  final int page;
  final String text;

  /// What the embedder sees, when that differs from [text]: a few words of
  /// the previous passage are carried along so a value and its unit stay
  /// together at a seam. Stored and shown text stays [text], so nothing is
  /// duplicated in citations or in the answer prompt.
  final String? embeddingText;
  final double score;

  String get embeddingInput => embeddingText ?? text;

  /// The small JSON the vector index stores beside the vector.
  String toMetadata() => jsonEncode({
    'doc_id': docId,
    'doc_title': docTitle,
    'page': page,
  });

  static Map<String, dynamic> _decode(String? metadata) {
    if (metadata == null || metadata.isEmpty) return const {};
    try {
      final decoded = jsonDecode(metadata);
      return decoded is Map<String, dynamic> ? decoded : const {};
    } catch (_) {
      return const {};
    }
  }
}

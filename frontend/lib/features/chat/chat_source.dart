class ChatSource {
  const ChatSource({
    required this.docId,
    required this.docTitle,
    required this.page,
    required this.score,
    required this.snippet,
  });

  final String docId;
  final String docTitle;
  final int page;
  final double score;
  final String snippet;

  factory ChatSource.fromJson(Map<String, dynamic> json) {
    return ChatSource(
      docId: json['doc_id']?.toString() ?? '',
      docTitle: json['doc_title']?.toString() ?? 'Untitled',
      page: (json['page'] as num?)?.toInt() ?? 0,
      score: (json['score'] as num?)?.toDouble() ?? 0,
      snippet: json['snippet']?.toString() ?? '',
    );
  }
}

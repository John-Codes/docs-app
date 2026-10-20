class ChatSource {
  const ChatSource({
    required this.docId,
    required this.docTitle,
    required this.page,
    required this.score,
    required this.snippet,
    this.index = 0,
  });

  final String docId;
  final String docTitle;
  final int page;
  final double score;
  final String snippet;
  final int index;

  factory ChatSource.fromJson(Map<String, dynamic> json) {
    return ChatSource(
      docId: json['doc_id']?.toString() ?? '',
      docTitle: json['doc_title']?.toString() ?? 'Untitled',
      page: (json['page'] as num?)?.toInt() ?? 0,
      score: (json['score'] as num?)?.toDouble() ?? 0,
      snippet: json['snippet']?.toString() ?? '',
      index: (json['index'] as num?)?.toInt() ?? 0,
    );
  }
}

import '../../core/api/api_client.dart';

/// One document chunk the backend retrieved for a question. On-device
/// answers are written only from these, so they can cite [Title, p. N]
/// exactly like the cloud chat does.
class GroundedChunk {
  const GroundedChunk({
    required this.docId,
    required this.docTitle,
    required this.page,
    required this.text,
  });

  factory GroundedChunk.fromJson(Map<String, dynamic> json) => GroundedChunk(
        docId: json['doc_id']?.toString() ?? '',
        docTitle: json['doc_title']?.toString() ?? 'Untitled',
        page: (json['page'] as num?)?.toInt() ?? 0,
        text: json['text']?.toString() ?? '',
      );

  final String docId;
  final String docTitle;
  final int page;
  final String text;
}

/// Calls the backend's /retrieve endpoint.
///
/// If this call fails (backend down, network error) the caller silently
/// falls back to the cloud answer, so the user never sees an error caused
/// by the local mode.
class LocalGrounding {
  LocalGrounding([ApiClient? api]) : _api = api ?? ApiClient();

  final ApiClient _api;

  Future<List<GroundedChunk>> retrieve(String question) async {
    final data = await _api.postJson('/retrieve', {'message': question})
        as Map<String, dynamic>;
    final chunks = (data['chunks'] as List? ?? const [])
        .map((item) => GroundedChunk.fromJson(item as Map<String, dynamic>))
        .toList();
    return chunks;
  }
}

class DocumentInfo {
  const DocumentInfo({
    required this.id,
    required this.title,
    required this.filename,
    required this.status,
    required this.pages,
    required this.sizeBytes,
    required this.chunks,
    required this.uploadedAt,
    this.error,
  });

  final String id;
  final String title;
  final String filename;
  final String status;
  final int pages;
  final int sizeBytes;
  final int chunks;
  final String uploadedAt;
  final String? error;

  bool get isReady => status == 'ready';
  bool get isProcessing => status == 'processing';
  bool get hasFailed => status == 'failed';

  factory DocumentInfo.fromJson(Map<String, dynamic> json) {
    return DocumentInfo(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Untitled',
      filename: json['filename']?.toString() ?? 'document.pdf',
      status: json['status']?.toString() ?? 'processing',
      pages: (json['pages'] as num?)?.toInt() ?? 0,
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      chunks: (json['chunks'] as num?)?.toInt() ?? 0,
      uploadedAt: json['uploaded_at']?.toString() ?? '',
      error: json['error']?.toString(),
    );
  }
}

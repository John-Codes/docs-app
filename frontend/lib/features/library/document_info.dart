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
    this.draft = false,
    this.pipelineVersion = 0,
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

  /// Extracted on the device while offline with the fallback parser: good
  /// enough to read and search, re-extracted with the server parser when
  /// the connection comes back.
  final bool draft;

  /// The passage pipeline that built this document's passages. Zero means
  /// "before this was recorded", which is older than any real version — so
  /// an entry from an earlier build is rebuilt once, not trusted as current.
  final int pipelineVersion;

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
      draft: json['draft'] == true,
      pipelineVersion: (json['pipeline_version'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'filename': filename,
    'status': status,
    'pages': pages,
    'size_bytes': sizeBytes,
    'chunks': chunks,
    'uploaded_at': uploadedAt,
    'error': error,
    'draft': draft,
    'pipeline_version': pipelineVersion,
  };

  DocumentInfo copyWith({
    String? status,
    int? pages,
    int? chunks,
    String? error,
    bool? draft,
    int? pipelineVersion,
  }) {
    return DocumentInfo(
      id: id,
      title: title,
      filename: filename,
      status: status ?? this.status,
      pages: pages ?? this.pages,
      sizeBytes: sizeBytes,
      chunks: chunks ?? this.chunks,
      uploadedAt: uploadedAt,
      error: error ?? this.error,
      draft: draft ?? this.draft,
      pipelineVersion: pipelineVersion ?? this.pipelineVersion,
    );
  }
}

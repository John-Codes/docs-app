import 'dart:convert';

import 'package:web/web.dart' as web;

import '../library/document_info.dart';

/// The library list, persisted in localStorage.
///
/// Only metadata lives here — a few hundred bytes per document. The PDF
/// bytes are in [PdfBlobStore], the passages and vectors in the SQLite
/// vector index.
final documentCatalog = DocumentCatalog();

class DocumentCatalog {
  static const _key = 'on_device_rag_documents_v1';

  List<DocumentInfo> read() {
    final raw = web.window.localStorage.getItem(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return [
        for (final item in decoded)
          if (item is Map<String, dynamic>) DocumentInfo.fromJson(item),
      ];
    } catch (_) {
      return [];
    }
  }

  DocumentInfo? find(String id) {
    for (final document in read()) {
      if (document.id == id) return document;
    }
    return null;
  }

  Future<void> upsert(DocumentInfo document) async {
    final documents = read();
    final index = documents.indexWhere((item) => item.id == document.id);
    if (index >= 0) {
      documents[index] = document;
    } else {
      documents.insert(0, document);
    }
    await _write(documents);
  }

  Future<void> remove(String id) async {
    final documents = read()..removeWhere((item) => item.id == id);
    await _write(documents);
  }

  Future<void> _write(List<DocumentInfo> documents) async {
    web.window.localStorage.setItem(
      _key,
      jsonEncode([for (final document in documents) document.toJson()]),
    );
  }
}

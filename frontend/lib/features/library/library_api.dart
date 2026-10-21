import 'dart:typed_data';

import '../on_device_rag/on_device_rag.dart';
import 'document_info.dart';

/// The library API, now local: documents live in this browser.
///
/// The server is reached only through the extractor inside the ingest
/// pipeline, and only for text extraction.
class LibraryApi {
  List<DocumentInfo> list() => localLibrary.list();

  Future<void> upload(String filename, Uint8List bytes) =>
      localLibrary.add(filename: filename, bytes: bytes);

  Future<void> delete(String id) => localLibrary.remove(id);
}

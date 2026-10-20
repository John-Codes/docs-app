import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// The PDFs themselves, kept in the browser's Cache API.
///
/// Nothing is uploaded to the server for storage: the file lives on the
/// device, opens from a local blob URL, and is the source of truth when a
/// draft extraction needs re-doing.
final pdfBlobStore = PdfBlobStore();

class PdfBlobStore {
  static const _cacheName = 'docs-app-pdfs';
  static const _prefix = '/local-pdf/';

  String _key(String docId) => '$_prefix$docId';

  Future<void> write(String docId, Uint8List bytes) async {
    final cache = await web.window.caches.open(_cacheName).toDart;
    await cache.put(_key(docId).toJS, web.Response(bytes.toJS)).toDart;
  }

  Future<Uint8List?> read(String docId) async {
    final cache = await web.window.caches.open(_cacheName).toDart;
    final response = await cache.match(_key(docId).toJS).toDart;
    if (response == null) return null;
    final buffer = await response.arrayBuffer().toDart;
    return Uint8List.view(buffer.toDart);
  }

  Future<void> delete(String docId) async {
    final cache = await web.window.caches.open(_cacheName).toDart;
    await cache.delete(_key(docId).toJS).toDart;
  }

  /// A blob URL the browser's PDF viewer can open directly.
  Future<String?> urlFor(String docId) async {
    final bytes = await read(docId);
    if (bytes == null) return null;
    final blob = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: 'application/pdf'),
    );
    return web.URL.createObjectURL(blob);
  }

  void revoke(String url) => web.URL.revokeObjectURL(url);
}

import 'dart:typed_data';

import '../../core/api/api_client.dart';
import 'document_info.dart';

class LibraryApi {
  LibraryApi([ApiClient? api]) : _api = api ?? ApiClient();

  final ApiClient _api;

  Future<List<DocumentInfo>> list() async {
    final data = await _api.getJson('/documents') as List? ?? const [];
    return data
        .map((item) => DocumentInfo.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<DocumentInfo> upload(String filename, Uint8List bytes) async {
    final data = await _api.uploadPdf(filename, bytes);
    return DocumentInfo.fromJson(data as Map<String, dynamic>);
  }

  Future<void> delete(String id) => _api.delete('/documents/$id');
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

const _configuredBase = String.fromEnvironment('API_BASE_URL');

class ApiClient {
  ApiClient([String? base])
    : baseUrl = (base ?? _configuredBase).trim();

  final String baseUrl;

  String get origin => baseUrl.isEmpty ? Uri.base.origin : baseUrl;

  Uri uri(String path) => Uri.parse('$origin$path');

  String documentFileUrl(String docId, {int? page}) {
    final suffix = page != null && page > 0 ? '#page=$page' : '';
    return '$origin/documents/$docId/file$suffix';
  }

  Future<dynamic> getJson(String path) async {
    return _decode(await http.get(uri(path)));
  }

  Future<dynamic> postJson(String path, Map<String, dynamic> body) async {
    final response = await http.post(
      uri(path),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Future<dynamic> uploadPdf(String filename, Uint8List bytes) async {
    final request = http.MultipartRequest('POST', uri('/documents'));
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: filename),
    );
    final response = await http.Response.fromStream(await request.send());
    return _decode(response);
  }

  Future<void> delete(String path) async {
    _decode(await http.delete(uri(path)));
  }

  dynamic _decode(http.Response response) {
    final success = response.statusCode >= 200 && response.statusCode < 300;
    if (!success) {
      var message = 'Request failed (${response.statusCode})';
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body['detail'] != null) {
          message = body['detail'].toString();
        }
      } catch (_) {
        // Keep the generic message when the body is not JSON.
      }
      throw Exception(message);
    }
    if (response.body.isEmpty) return null;
    return jsonDecode(response.body);
  }
}

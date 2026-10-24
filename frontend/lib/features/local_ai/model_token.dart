import 'package:flutter/foundation.dart';

import '../../core/api/api_client.dart';
import 'client_report.dart';

/// Fetches the HuggingFace token the gated model downloads need.
///
/// The token is deliberately not compiled into the app: the web bundle is
/// public, so a baked-in token would be a published token. It comes from the
/// server at runtime instead. Nothing here is required for the app to work —
/// the search model is ungated — so every failure is quiet and simply leaves
/// gated downloads unavailable.
final modelToken = ModelToken();

class ModelToken {
  String? _token;
  Future<String?>? _pending;

  /// Whether the server supplied a token this session. Reported alongside
  /// download failures so a refused gated file is easy to recognise.
  bool get hasToken => _token != null;

  /// The token, or null when the server has none. Fetched once per session.
  Future<String?> read() {
    if (_token != null) return Future.value(_token);
    return _pending ??= _fetch();
  }

  Future<String?> _fetch() async {
    try {
      final body = await ApiClient().getJson('/token');
      final token = body is Map ? body['token']?.toString() : null;
      _token = (token == null || token.isEmpty) ? null : token;
    } catch (failure) {
      // Offline, or an older server without the endpoint: gated downloads
      // stay off and the app carries on.
      debugPrint('[local-ai] could not read the model token: $failure');
      reportClientEvent('model_token_failed', failure);
      _token = null;
    }
    return _token;
  }
}

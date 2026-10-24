/// Reports client-side failures to the backend so a problem on someone's
/// phone stops being invisible.
///
/// Fire-and-forget by design: a failed report must never break the app that
/// is already having a bad day. One small JSON object per event — the
/// exception summary plus the device facts needed to reproduce it. No PDF
/// text, no chat content, no tokens.
library;

import 'package:web/web.dart' as web;

import '../../core/api/api_client.dart';
import 'device_facts.dart';

const _reportsEndpoint = '/errors';
const _installIdKey = 'docs_app_install_id';

/// Sends one report. Never throws, never blocks the caller for long.
///
/// [event] names what happened ("download_failed"), [stage] names where
/// ("search_model", "engine_init", "answer"), [error] is the raw failure,
/// and [extra] carries anything stage-specific worth keeping.
Future<void> reportClientError(
  String event,
  String stage, {
  Object? error,
  Map<String, Object?> extra = const {},
}) async {
  try {
    final body = <String, Object?>{
      'event': event,
      'stage': stage,
      'error': errorSummary(error),
      'device': deviceFacts(),
      'caps': capabilityFacts(),
      'app': extra,
      'install_id': _installId(),
      'report_id': shortRandomId(),
    };
    await ApiClient().postJson(_reportsEndpoint, body);
  } catch (_) {
    // Reporting must never make things worse.
  }
}

/// The anonymous per-browser id that groups reports from the same device.
String _installId() {
  try {
    final stored = web.window.localStorage.getItem(_installIdKey);
    if (stored != null && stored.isNotEmpty) return stored;
    final fresh = shortRandomId();
    web.window.localStorage.setItem(_installIdKey, fresh);
    return fresh;
  } catch (_) {
    return 'unknown';
  }
}

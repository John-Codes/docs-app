import 'dart:async';

import '../../core/api/api_client.dart';
import 'client_report_context.dart';
import 'log_scrubber.dart';

/// Sends one caught failure to the server's log stream.
///
/// Fire-and-forget on purpose: a report is diagnostics, never a step the app
/// waits on or fails because of. Production strips the engine's own logs, so
/// this is the only way to see why an install failed on a user's machine.
void reportClientEvent(
  String event, [
  Object? failure,
  Map<String, String> extra = const {},
]) {
  unawaited(clientReport.report(event, failure, extra: extra));
}

final clientReport = ClientReport();

class ClientReport {
  /// A permanently broken path must not post on every retry.
  static const _maxPerFailure = 2;

  /// The session's report list stays small even if many different errors mix.
  static const _maxTrackedFailures = 40;

  final Map<String, int> _sentFailures = {};

  Future<void> report(
    String event,
    Object? failure, {
    Map<String, String> extra = const {},
  }) async {
    final message = scrubForReport(failure);
    final key = '$event|$message';
    final alreadySent = _sentFailures[key] ?? 0;
    if (alreadySent >= _maxPerFailure) return;
    if (alreadySent == 0 && _sentFailures.length >= _maxTrackedFailures) {
      return;
    }
    _sentFailures[key] = alreadySent + 1;

    try {
      final context = await deviceSnapshot();
      context.addAll(extra);
      await ApiClient()
          .postJson('/client-logs', {
            'entries': [
              {'event': event, 'message': message, 'context': context},
            ],
          })
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      // Offline, an older server, a blocked request: the app carries on.
    }
  }
}

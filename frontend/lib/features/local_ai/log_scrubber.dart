/// Shortens a failure for the server's report log, without any credential.
///
/// The app never sends the model token, but an engine exception can quote
/// the request it failed on, so the token and any Authorization header are
/// removed here as well as on the server. Pure and testable.
library;

final _huggingFaceToken = RegExp(r'hf_[A-Za-z0-9]{20,}');
final _bearerHeader = RegExp(
  r'bearer\s+[A-Za-z0-9._~+/=-]{10,}',
  caseSensitive: false,
);

const reportMessageLimit = 500;

String scrubForReport(Object? failure, {int limit = reportMessageLimit}) {
  final text = failure?.toString() ?? '';
  final scrubbed = text
      .replaceAll(_bearerHeader, 'Bearer [redacted]')
      .replaceAll(_huggingFaceToken, 'hf_[redacted]');
  if (scrubbed.length <= limit) return scrubbed;
  return scrubbed.substring(0, limit);
}

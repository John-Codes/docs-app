/// Turns a model-download failure into the words the user actually sees,
/// and into the code the error log needs to group reports by.
library;

import 'error_reporter.dart';
import '../local_ai/storage_room.dart';
/// One classified download failure.
class DownloadFailure {
  const DownloadFailure({
    required this.code,
    required this.headline,
    required this.rawMessage,
  });

  /// Machine-readable cause: "capability", "storage", "auth", "gated",
  /// "network", "cancelled", "engine" or "unknown".
  final String code;

  /// The one sentence the download sheet shows.
  final String headline;

  /// The raw exception text, for the copyable details block.
  final String rawMessage;
}

/// Classify [failure] into a headline the user can act on.
///
/// The old copy blamed the connection for everything, which is exactly wrong
/// when the browser simply cannot write OPFS files (iOS 15–18) or the disk
/// is full. Each branch also names the code the error log groups by.
DownloadFailure describeDownloadFailure(Object failure) {
  final text = failure.toString();
  final lower = text.toLowerCase();

  if (lower.contains('cancel') ||
      lower.contains('aborterror') ||
      lower.contains('user stopped')) {
    return DownloadFailure(
      code: 'cancelled',
      headline: 'The download was stopped.',
      rawMessage: text,
    );
  }
  if (_isMissingWriteApi(lower)) {
    return DownloadFailure(
      code: 'capability',
      headline: 'This browser cannot store the model file (its OPFS write '
          'API is missing). It needs Safari 26+, Chrome 86+ or Firefox 111+.',
      rawMessage: text,
    );
  }
  if (isStorageFailure(failure) || lower.contains('insufficient storage')) {
    return DownloadFailure(
      code: 'storage',
      headline: 'This device does not have enough browser storage for the '
          'model. Free up space and try again.',
      rawMessage: text,
    );
  }
  if (lower.contains('gatedrepo') || lower.contains('403')) {
    return DownloadFailure(
      code: 'gated',
      headline: 'HuggingFace refused the download: accept the Gemma 3 '
          'license on its model page once, then retry.',
      rawMessage: text,
    );
  }
  if (lower.contains('401') || lower.contains('unauthorized')) {
    return DownloadFailure(
      code: 'auth',
      headline: 'The model download was refused: the server needs a valid '
          'HUGGINGFACE_TOKEN.',
      rawMessage: text,
    );
  }
  if (lower.contains('failed to fetch') ||
      lower.contains('networkerror') ||
      lower.contains('network problem')) {
    return DownloadFailure(
      code: 'network',
      headline: 'The connection dropped while downloading. Check the '
          'network and retry.',
      rawMessage: text,
    );
  }
  if (lower.contains('timed out') || lower.contains('timeout')) {
    return DownloadFailure(
      code: 'network',
      headline: 'The download took too long and was stopped. Retry on a '
          'faster connection.',
      rawMessage: text,
    );
  }
  return DownloadFailure(
    code: 'unknown',
    headline: 'The download could not be completed. Retry, and if it keeps '
        'failing the details below say exactly why.',
    rawMessage: text,
  );
}

bool _isMissingWriteApi(String lower) {
  return lower.contains('createwritable') ||
      lower.contains('is not a function') ||
      lower.contains('not supported') ||
      lower.contains('not implemented');
}

/// Report a classified failure to the error log, then hand it back so the
/// caller can show it. One call, both jobs.
DownloadFailure describeAndReportDownloadFailure(
  String event,
  String stage,
  Object failure,
) {
  final described = describeDownloadFailure(failure);
  reportClientError(
    event,
    stage,
    error: failure,
    extra: {'code': described.code, 'headline': described.headline},
  );
  return described;
}

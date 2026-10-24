import 'package:flutter_edge_ai/flutter_edge_ai.dart';

import 'storage_room.dart';

/// Turns a model-download failure into the one sentence the sheet shows.
///
/// The web engine streams through OPFS, and that helper reports every HTTP
/// refusal as a plain `HTTP <status>` error instead of the typed
/// [DownloadException] the older Cache API path produces. Reading the status
/// back keeps the advice honest: a refused license must not be described as
/// a connection problem.
String describeDownloadFailure(Object failure, {String? fallback}) {
  if (isStorageFailure(failure)) return storageFailureMessage();
  if (failure is DownloadException) return _fromTypedError(failure);

  final text = failure.toString().toLowerCase();
  if (_mentions(text, const [
    'createwritable',
    'createsyncaccesshandle',
    'is not a function',
    'not supported',
    'not implemented',
  ])) {
    return _capabilityMessage;
  }
  if (_mentions(text, const ['403', 'forbidden'])) return _licenseMessage;
  if (_mentions(text, const ['401', 'unauthorized'])) return _tokenMessage;
  if (_mentions(text, const ['429', 'rate limit', 'too many requests'])) {
    return _rateLimitMessage;
  }
  if (_mentions(text, const ['404', 'not found'])) return _missingMessage;
  if (_mentions(text, const [
    'failed to fetch',
    'network',
    'connection',
    'socket',
    'timeout',
    'timed out',
    'http 5',
  ])) {
    return _networkMessage;
  }
  return fallback ?? _genericMessage;
}

bool _mentions(String text, List<String> needles) =>
    needles.any(text.contains);

String _fromTypedError(DownloadException failure) => switch (failure.error) {
  ForbiddenError() => _licenseMessage,
  UnauthorizedError() => _tokenMessage,
  NotFoundError() => _missingMessage,
  RateLimitedError() => _rateLimitMessage,
  ServerError(:final statusCode) =>
    'The model server reported an error (HTTP $statusCode) — retry in a few '
        'minutes.',
  NetworkError() => _networkMessage,
  CanceledError() => _genericMessage,
  _ => failure.error.toUserMessage(),
};

const _licenseMessage =
    'One-time step needed: open the Gemma 3 1B model page on '
    'huggingface.co/litert-community/Gemma3-1B-IT while logged in, tap '
    '"Agree and access", then retry here.';

const _tokenMessage =
    'The model download was refused by HuggingFace — the server needs a '
    'valid HUGGINGFACE_TOKEN, or set LOCAL_MODEL_URL to your own copy of the '
    'file.';

const _rateLimitMessage =
    'HuggingFace rate limit reached — wait a few minutes and retry.';

const _missingMessage =
    'The model file was not found on the server — retry later or point '
    'LOCAL_MODEL_URL at your own copy.';

const _capabilityMessage =
    'This browser cannot store the model file (its OPFS write API is '
    'missing). It needs Safari 26+, Chrome 86+ or Firefox 111+.';

const _networkMessage =
    'Network problem while downloading — check the connection and retry.';

const _genericMessage =
    'The download could not start — check the connection and retry.';

import 'dart:async';

/// Runs [attempt] until it succeeds or the tries run out.
///
/// Model downloads fail for reasons that pass: a dropped connection, a
/// storage hiccup while the finished bytes are written, a rate limiter
/// letting go. One such blip used to leave the model uninstalled until the
/// user noticed the badge and pressed Retry, which most never do — so the
/// app quietly stays cloud-only forever. A few automatic tries turn a blip
/// back into a background download.
///
/// [onRetry] is called before each wait with the number of the failed
/// attempt (1 for the first), so the UI can say it is retrying instead of
/// freezing at the same percentage.
///
/// [isCancelled] is checked before every wait and attempt: a download the
/// user stopped must never come back to life on its own.
///
/// [shouldRetry] decides whether a failure is worth another try. Pass
/// [isRetryableDownloadFailure]: a full disk or a refused license must fail
/// at once, because retrying it only downloads the same hundreds of
/// megabytes again.
Future<void> retrying({
  required Future<void> Function() attempt,
  required bool Function() isCancelled,
  int tries = 3,
  Duration firstDelay = const Duration(seconds: 2),
  void Function(int failedAttempt)? onRetry,
  bool Function(Object failure)? shouldRetry,
}) async {
  var delay = firstDelay;
  for (var attemptNumber = 1; ; attemptNumber++) {
    if (isCancelled()) return;
    try {
      await attempt();
      return;
    } catch (failure) {
      final permanent = shouldRetry != null && !shouldRetry(failure);
      if (attemptNumber >= tries || isCancelled() || permanent) rethrow;
      onRetry?.call(attemptNumber);
      await Future<void>.delayed(delay);
      // Grow the wait so a service that is briefly unavailable is not
      // hammered, but keep it short enough that a real recovery is quick.
      delay *= 2;
    }
  }
}

/// True for failures another try can plausibly fix: a dropped connection, a
/// timeout, a rate limit, a server hiccup. False for anything permanent —
/// storage exhaustion, a gated model, a bad token, a missing file — where a
/// retry only repeats the same long download.
bool isRetryableDownloadFailure(Object failure) {
  final text = failure.toString().toLowerCase();
  const permanent = [
    'quota',
    'storage',
    'no space',
    'out of memory',
    'allocation',
    'forbidden',
    'unauthorized',
    'not found',
    'cancel',
    // The OPFS helper reports `HTTP <status>` and may omit the status text,
    // so match the codes too: a refused install must not re-fetch 700 MB.
    '401',
    '403',
    '404',
  ];
  if (permanent.any(text.contains)) return false;
  const transient = [
    'network',
    'failed to fetch',
    'timeout',
    'timed out',
    'rate limit',
    '429',
    '500',
    '502',
    '503',
    '504',
    'socket',
    'connection',
  ];
  return transient.any(text.contains);
}

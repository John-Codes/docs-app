import 'package:flutter_test/flutter_test.dart';

import 'package:docs_app/features/local_ai/download_retry.dart';

void main() {
  group('retrying', () {
    test('a first-try success never waits or retries', () async {
      var tries = 0;
      final retries = <int>[];
      await retrying(
        attempt: () async => tries++,
        isCancelled: () => false,
        onRetry: retries.add,
      );
      expect(tries, 1);
      expect(retries, isEmpty);
    });

    test('a transient failure is retried until it succeeds', () async {
      // The whole point: one blip must not need a human.
      var tries = 0;
      await retrying(
        attempt: () async {
          tries++;
          if (tries < 3) throw Exception('blip');
        },
        isCancelled: () => false,
        firstDelay: Duration.zero,
      );
      expect(tries, 3);
    });

    test('it gives up after the allowed tries and rethrows', () async {
      var tries = 0;
      await expectLater(
        retrying(
          attempt: () async {
            tries++;
            throw Exception('permanent');
          },
          isCancelled: () => false,
          tries: 3,
          firstDelay: Duration.zero,
        ),
        throwsA(isA<Exception>()),
      );
      expect(tries, 3);
    });

    test('onRetry reports each failed attempt in order', () async {
      final retries = <int>[];
      await expectLater(
        retrying(
          attempt: () async => throw Exception('x'),
          isCancelled: () => false,
          tries: 3,
          firstDelay: Duration.zero,
          onRetry: retries.add,
        ),
        throwsA(isA<Exception>()),
      );
      // Two retries follow the three attempts; the last failure is final.
      expect(retries, [1, 2]);
    });

    test('cancellation before the first attempt does nothing', () async {
      var tries = 0;
      await retrying(
        attempt: () async => tries++,
        isCancelled: () => true,
      );
      expect(tries, 0);
    });

    test('cancelling during a wait stops the retry', () async {
      // A user who pressed Stop must not be overridden by the retry timer.
      var tries = 0;
      var cancelled = false;
      await expectLater(
        retrying(
          attempt: () async {
            tries++;
            cancelled = true;
            throw Exception('blip');
          },
          isCancelled: () => cancelled,
          firstDelay: Duration.zero,
        ),
        throwsA(isA<Exception>()),
      );
      expect(tries, 1);
    });

    test('a permanent failure is not retried at all', () async {
      // Retrying a full disk just fetches the whole model again for nothing.
      var tries = 0;
      await expectLater(
        retrying(
          attempt: () async {
            tries++;
            throw Exception('QuotaExceededError: Quota exceeded.');
          },
          isCancelled: () => false,
          firstDelay: Duration.zero,
          shouldRetry: isRetryableDownloadFailure,
        ),
        throwsA(isA<Exception>()),
      );
      expect(tries, 1);
    });

    test('a transient failure still uses the full retry budget', () async {
      var tries = 0;
      await expectLater(
        retrying(
          attempt: () async {
            tries++;
            throw Exception('Network error: Failed to fetch');
          },
          isCancelled: () => false,
          tries: 3,
          firstDelay: Duration.zero,
          shouldRetry: isRetryableDownloadFailure,
        ),
        throwsA(isA<Exception>()),
      );
      expect(tries, 3);
    });
  });

  group('isRetryableDownloadFailure', () {
    test('transient problems are retryable', () {
      expect(isRetryableDownloadFailure('Network error: timed out'), isTrue);
      expect(isRetryableDownloadFailure('Rate limit exceeded (HTTP 429)'),
          isTrue);
      expect(isRetryableDownloadFailure('Server error (HTTP 503)'), isTrue);
    });

    test('permanent problems are not', () {
      expect(
        isRetryableDownloadFailure('QuotaExceededError: Quota exceeded.'),
        isFalse,
      );
      expect(
        isRetryableDownloadFailure('Access forbidden (HTTP 403)'),
        isFalse,
      );
      expect(
        isRetryableDownloadFailure('Authentication required (HTTP 401)'),
        isFalse,
      );
      expect(isRetryableDownloadFailure('Model not found (HTTP 404)'),
          isFalse);
      expect(isRetryableDownloadFailure('Download was canceled.'), isFalse);
    });
  });
}

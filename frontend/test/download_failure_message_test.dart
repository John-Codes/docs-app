import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:docs_app/features/local_ai/download_failure_message.dart';

void main() {
  group('describeDownloadFailure', () {
    test('an OPFS 403 asks for the license step, not the connection', () {
      // Exactly what the streaming web helper throws in production.
      final failure = Exception(
        'Failed to download to OPFS: Error: HTTP 403: Forbidden',
      );

      final message = describeDownloadFailure(failure);

      expect(message, contains('Agree and access'));
      expect(message, isNot(contains('connection')));
    });

    test('an OPFS 401 names the server token', () {
      final failure = Exception(
        'Failed to download to OPFS: Error: HTTP 401: Unauthorized',
      );

      expect(describeDownloadFailure(failure), contains('HUGGINGFACE_TOKEN'));
    });

    test('an OPFS 429 asks the user to wait instead of retrying blindly', () {
      final failure = Exception(
        'Failed to download to OPFS: Error: HTTP 429: Too Many Requests',
      );

      expect(describeDownloadFailure(failure), contains('rate limit'));
    });

    test('a status code without its text still maps', () {
      final failure = Exception('Failed to download to OPFS: Error: HTTP 403');

      expect(describeDownloadFailure(failure), contains('Agree and access'));
    });

    test('a typed forbidden failure gets the same license advice', () {
      const failure = DownloadException(ForbiddenError());

      expect(describeDownloadFailure(failure), contains('Agree and access'));
    });

    test('a storage failure is reported as storage, not as the network', () {
      final failure = Exception('QuotaExceededError: exceeded the quota');

      expect(describeDownloadFailure(failure), contains('storage'));
    });

    test('an unrecognised failure uses the caller wording', () {
      final message = describeDownloadFailure(
        Exception('something new'),
        fallback: 'The search model could not be downloaded.',
      );

      expect(message, 'The search model could not be downloaded.');
    });
  });
}

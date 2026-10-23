import 'package:flutter_test/flutter_test.dart';

import 'package:docs_app/features/local_ai/log_scrubber.dart';

const _token = 'hf_a1B2c3D4e5F6g7H8i9J0k1L2m3N4o5P6';

void main() {
  group('scrubForReport', () {
    test('removes a Hugging Face token quoted by an engine failure', () {
      final scrubbed = scrubForReport(
        Exception('GET https://huggingface.co/... failed for $_token'),
      );

      expect(scrubbed, isNot(contains(_token)));
      expect(scrubbed, contains('hf_[redacted]'));
    });

    test('removes an Authorization header', () {
      final scrubbed = scrubForReport(
        'request failed: Authorization: Bearer abcdef1234567890xyz',
      );

      expect(scrubbed, isNot(contains('abcdef1234567890xyz')));
      expect(scrubbed, contains('Bearer [redacted]'));
    });

    test('shortens the report so one failure cannot flood the log', () {
      final scrubbed = scrubForReport('x' * 4000);

      expect(scrubbed.length, reportMessageLimit);
      expect(scrubbed, 'x' * reportMessageLimit);
    });

    test('keeps an ordinary failure readable', () {
      expect(
        scrubForReport(Exception('HTTP 403: Forbidden')),
        'Exception: HTTP 403: Forbidden',
      );
    });
  });
}

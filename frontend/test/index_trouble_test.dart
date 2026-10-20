import 'package:flutter_test/flutter_test.dart';
import 'package:docs_app/features/on_device_rag/index_trouble.dart';

/// The exact text flutter_edge_ai_sqlite throws when another tab (or this
/// one) already holds the database.
const busyText =
    'SQLite web location "docs_app_knowledge.db" is already open. Close the '
    'existing WebSqliteVectorStore before opening the same location in this '
    'tab, worker, or another browser tab.';

void main() {
  group('isIndexBusy', () {
    test('recognizes the package’s busy-location exception', () {
      expect(isIndexBusy(Exception(busyText)), isTrue);
    });

    test('ignores unrelated failures', () {
      expect(isIndexBusy(Exception('disk full')), isFalse);
      expect(isIndexBusy(StateError('The on-device search model is not '
          'installed.')), isFalse);
    });
  });

  group('describeIndexFailure', () {
    test('busy: leads with the action and still round-trips', () {
      final message = describeIndexFailure(Exception(busyText));
      expect(message, contains('Close the other Docs tab'));
      // The startup heal matches on the stored message, so the raw marker
      // must survive being described once.
      expect(isIndexBusy(message), isTrue);
    });

    test('missing model says where to download it', () {
      final message = describeIndexFailure(
        StateError('The on-device search model is not installed.'),
      );
      expect(message, contains('Download it from the badge'));
    });

    test('unknown failures keep their technical text', () {
      final message = describeIndexFailure(Exception('vector table corrupt'));
      expect(message, contains('vector table corrupt'));
      expect(message, contains('Reload the page'));
    });

    test('a self-explaining split failure is not buried', () {
      // This one already names the page and the text that cannot be split;
      // wrapping it in "the index could not run" would hide both.
      const unsplittable =
          'Page 1 has a single run of 529 tokens (limit 254) that cannot be '
          'split without cutting it: "7f3a9c1e…". Remove the document or '
          'replace that part of the PDF.';
      final message = describeIndexFailure(Exception(unsplittable));
      expect(message, unsplittable);
      expect(message, isNot(contains('could not run')));
    });
  });
}

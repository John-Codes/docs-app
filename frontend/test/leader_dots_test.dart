import 'package:flutter_test/flutter_test.dart';
import 'package:docs_app/features/on_device_rag/chunker.dart';
import 'package:docs_app/features/on_device_rag/leader_dots.dart';

/// A real table-of-contents line, as the server parser extracts it.
const tocLine =
    'Rig lubrication and operating care ................................... 12';

/// The leader-heavy shape of the manual's first page.
const tocPage = 'FIELD EQUIPMENT SERVICE MANUAL\n'
    'Rig lubrication and operating care ............................. 6\n'
    'Reclaimer startup ............................. 7\n'
    'Torque values ............................. 8';

int words(String text) => text.split(RegExp(r'\s+')).length;

void main() {
  group('collapseLeaderDots', () {
    test('a table-of-contents line keeps its heading and page number', () {
      expect(collapseLeaderDots(tocLine), 'Rig lubrication and operating care 12');
    });

    test('every heading and number on a page survives', () {
      final collapsed = collapseLeaderDots(tocPage);
      expect(collapsed, contains('Rig lubrication and operating care 6'));
      expect(collapsed, contains('Reclaimer startup 7'));
      expect(collapsed, contains('Torque values 8'));
      expect(collapsed, isNot(contains('....')));
    });

    test('real punctuation is left alone', () {
      // An ellipsis, a dotted part number and a version are not leaders.
      expect(collapseLeaderDots('Wait for it... then stop.'), 'Wait for it... then stop.');
      expect(collapseLeaderDots('part TT-660..A is fitted'), 'part TT-660..A is fitted');
      expect(collapseLeaderDots('version 1.2.3 shipped'), 'version 1.2.3 shipped');
    });

    test('a decimal and a date are untouched', () {
      expect(collapseLeaderDots('torque 42.5 Nm on 2024-11-25'), 'torque 42.5 Nm on 2024-11-25');
    });
  });

  group('isMostlyPunctuation', () {
    test('a leader-dot run is not content', () {
      expect(isMostlyPunctuation('................................... 7'), isTrue);
    });

    test('real prose is content', () {
      expect(
        isMostlyPunctuation(
          'The relief valve kit TT-660 is torqued to 42.5 Nm before the '
          'seal is fitted.',
        ),
        isFalse,
      );
    });

    test('a table row with numbers is content', () {
      expect(
        isMostlyPunctuation(
          'Row 25: pump 375 psi, torque 25.5 Nm, part TT-625, checked '
          '2024-11-25.',
        ),
        isFalse,
      );
    });

    test('a short fragment is not judged', () {
      // Too little to tell; the splitter's own budget already handles it.
      expect(isMostlyPunctuation('...'), isFalse);
      expect(isMostlyPunctuation('p. 7'), isFalse);
    });
  });

  group('chunker with leader dots', () {
    test('a table-of-contents page indexes as readable text', () {
      final chunks = chunkPages(
        docId: 'doc',
        docTitle: 'Manual',
        pages: const [tocPage],
        countTokens: (text) => words(text) * 2,
      );
      final joined = chunks.map((chunk) => chunk.text).join();
      expect(joined, contains('Rig lubrication and operating care 6'));
      expect(joined, isNot(contains('....')));
      // No word or number is dropped by the collapse.
      expect(joined, contains('FIELD EQUIPMENT SERVICE MANUAL'));
      expect(joined, contains('8'));
    });

    test('the page still joins back exactly after collapsing', () {
      final chunks = chunkPages(
        docId: 'doc',
        docTitle: 'Manual',
        pages: const [tocPage],
        countTokens: (text) => words(text) * 2,
      );
      expect(
        chunks.map((chunk) => chunk.text).join(),
        collapseLeaderDots(
          'FIELD EQUIPMENT SERVICE MANUAL\n'
          'Rig lubrication and operating care ............................. 6\n'
          'Reclaimer startup ............................. 7\n'
          'Torque values ............................. 8',
        ),
      );
    });

    test('normal prose is unchanged', () {
      const page = 'Section 1: hydraulic readings\nRow 1: pump 103 psi, '
          'torque 1.5 Nm, part TT-601, checked 2024-11-01.';
      final chunks = chunkPages(
        docId: 'doc',
        docTitle: 'Manual',
        pages: const [page],
        countTokens: (text) => words(text) * 2,
      );
      expect(chunks.map((chunk) => chunk.text).join(), page);
    });
  });
}

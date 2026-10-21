import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:docs_app/features/on_device_rag/chunker.dart';
import 'package:docs_app/features/on_device_rag/leader_dots.dart';
import 'package:docs_app/features/on_device_rag/text_units.dart';

/// The conservative estimate that stands in when the runtime tokenizer is
/// not loaded: nothing must break either way.
int estimateTokens(String text) {
  final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  final byChars = (text.length / 3).ceil();
  return (words * 2 > byChars ? words * 2 : byChars) + 12;
}

const realBudget = 254; // the model's 256 input tokens, less headroom

List<String> _chunks(String page) => chunkPages(
  docId: 'doc',
  docTitle: 'Manual',
  pages: [page],
  countTokens: estimateTokens,
  maxTokens: realBudget,
).map((chunk) => chunk.text).toList();

void main() {
  test('the bundled manual, page by page, without loss or overflow', () {
    final pages = (jsonDecode(
      File('test/fixtures/hardrock_pages.json').readAsStringSync(),
    ) as List).cast<String>();

    var chunks = 0;
    for (var index = 0; index < pages.length; index++) {
      final page = pages[index];
      final parts = _chunks(page);
      chunks += parts.length;

      expect(parts.join(), collapseLeaderDots(normalizePage(page)),
          reason: 'page ${index + 1} must come back whole');
      for (final part in parts) {
        expect(estimateTokens(part), lessThanOrEqualTo(realBudget),
            reason: 'page ${index + 1} passage over budget');
      }
      for (final token in page.split(RegExp(r'\s+'))) {
        if (token.isEmpty || int.tryParse(token) == null) continue;
        expect(parts.any((part) => part.contains(token)), isTrue,
            reason: 'number $token on page ${index + 1} was cut');
      }
    }
    expect(chunks, greaterThan(pages.length));
  });

  test('a 120-page manual splits, fits and keeps every page', () {
    final pages = [
      for (var page = 1; page <= 120; page++)
        List.generate(
          30,
          (row) =>
              'Page $page line $row: valve ${row * 7} psi, part '
              'TT-$page$row, torque ${(row * 1.5).toStringAsFixed(1)} Nm.',
        ).join('\n'),
    ];
    final chunks = chunkPages(
      docId: 'doc',
      docTitle: 'Thick manual',
      pages: pages,
      countTokens: estimateTokens,
      maxTokens: realBudget,
    );
    expect(chunks.length, greaterThan(pages.length));
    expect(chunks.first.page, 1);
    expect(chunks.last.page, 120);
    for (final chunk in chunks) {
      expect(estimateTokens(chunk.embeddingInput), lessThanOrEqualTo(realBudget));
    }
  });

  test('a decimal, a date and a part number survive a seam', () {
    final raw = List.generate(
      40,
      (i) => 'Reading $i: pressure ${i * 13} psi on 2024-11-${(i % 28 + 1).toString().padLeft(2, '0')}, '
          'part A-${1000 + i}-B, temperature ${(i * 1.1).toStringAsFixed(1)} C. '
          'Every reading is logged and checked by the crew.',
    ).join('\n');
    final chunks = _chunks(raw);
    for (var i = 0; i < 40; i++) {
      for (final token in [
        (i * 13).toString(),
        '2024-11-${(i % 28 + 1).toString().padLeft(2, '0')}',
        'A-${1000 + i}-B',
      ]) {
        expect(
          chunks.any((c) => c.split(RegExp(r'\s+')).any((w) => w.contains(token))),
          isTrue,
          reason: '$token must live whole inside one passage',
        );
      }
    }
    expect(chunks.join(), normalizePage(raw));
  });
}

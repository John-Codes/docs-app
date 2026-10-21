import 'package:flutter_test/flutter_test.dart';

import 'package:docs_app/features/on_device_rag/chunker.dart';
import 'package:docs_app/features/on_device_rag/text_units.dart';

/// A stand-in for the runtime tokenizer: about one token per four
/// characters, plus the task prefix, so budgets force real splits.
int fakeCounter(String text) => (text.length / 4).ceil() + 12;

const _budget = 60;

List<String> _chunksOf(String page) => chunkPages(
  docId: 'doc',
  docTitle: 'Manual',
  pages: [page],
  countTokens: fakeCounter,
  maxTokens: _budget,
).map((chunk) => chunk.text).toList();

void main() {
  const prose =
      'The pump must be primed before the first start. Open the valve '
      'slowly, then wait until the gauge reads 1250 psi. Do not exceed '
      '1500 psi at any time; the relief valve protects the housing. '
      'Replace the filter every 500 hours of operation.';

  test('passages join back into the page exactly', () {
    final chunks = _chunksOf(prose);
    expect(chunks.length, greaterThan(1));
    expect(chunks.join(), normalizePage(prose));
  });

  test('every word survives in order, from the raw page', () {
    final raw = 'Line one  with   odd spacing\n\nLine two\tTT-660 A-10472-3 '
        '4.5% 2024-11-02\nLast line.';
    final page = normalizePage(raw);
    final chunks = _chunksOf(raw);
    final words = page.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    for (final word in words) {
      expect(chunks.join(), contains(word));
    }
  });

  test('numbers, identifiers and dates are never cut', () {
    final raw = 'Pressure 1250 psi, torque 42.5 Nm, part TT-660, '
        'serial A-10472-3, checked 2024-11-02. Fuse 7.5 A, do not exceed '
        '4.5% duty. The readings above come from the service log.';
    final chunks = _chunksOf(raw);
    for (final token in [
      '1250',
      '42.5',
      'TT-660',
      'A-10472-3',
      '2024-11-02',
      '7.5',
      '4.5%',
    ]) {
      expect(
        chunks.any(
          (chunk) => chunk
              .split(RegExp(r'\s+'))
              .any((word) => word.startsWith(token)),
        ),
        isTrue,
        reason: '$token must live whole inside one passage',
      );
    }
  });

  test('no passage exceeds the token budget', () {
    final long = List.generate(60, (i) => 'Row $i shows value ${i * 13}.').join(' ');
    final chunks = chunkPages(
      docId: 'doc',
      docTitle: 'Manual',
      pages: [long],
      countTokens: fakeCounter,
      maxTokens: _budget,
    );
    for (final chunk in chunks) {
      expect(fakeCounter(chunk.embeddingInput), lessThanOrEqualTo(_budget));
      expect(fakeCounter(chunk.text), lessThanOrEqualTo(_budget));
    }
  });

  test('line breaks survive, so table rows stay apart', () {
    final raw = 'Item    Value\nFilter  1250 psi\nPump    TT-660';
    final chunks = _chunksOf(raw);
    expect(chunks.join(), contains('\n'));
    expect(chunks.join(), contains('1250 psi'));
  });

  test('the next passage carries a few words of the previous one', () {
    final long = List.generate(40, (i) => 'Step $i checks value ${i * 7}.').join(' ');
    final chunks = chunkPages(
      docId: 'doc',
      docTitle: 'Manual',
      pages: [long],
      countTokens: fakeCounter,
      maxTokens: _budget,
    );
    expect(chunks.length, greaterThan(1));
    expect(chunks[1].embeddingInput, endsWith(chunks[1].text));
    expect(chunks[1].embeddingInput.length,
        greaterThan(chunks[1].text.length));
    expect(chunks[1].text, isNot(contains(chunks.first.text)),
        reason: 'stored text stays clean and unduplicated');
  });

  test('a single unbreakable run fails loudly instead of being cut', () {
    final token = 'A' * 400;
    expect(
      () => _chunksOf('Before $token after.'),
      throwsA(isA<UnbreakablePassageError>()),
    );
  });

  test('page numbers are 1-based and per page', () {
    final chunks = chunkPages(
      docId: 'doc',
      docTitle: 'Manual',
      pages: ['first page text', 'second page text'],
      countTokens: fakeCounter,
      maxTokens: _budget,
    );
    expect(chunks.map((chunk) => chunk.page), [1, 2]);
  });

  test('normalize keeps words and single line breaks only', () {
    expect(normalizePage('  a  b\n\n\nc\td  '), 'a b\n\nc d');
  });

  test('TextUnits ranges reconstruct without loss', () {
    const text = 'alpha beta\ngamma delta';
    final units = TextUnits.of(text);
    expect(units.range(0, units.words.length - 1), text);
  });
}

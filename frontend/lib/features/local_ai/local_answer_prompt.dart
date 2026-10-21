import '../on_device_rag/rag_chunk.dart';

/// The standing instruction the on-device model runs with: answer only from
/// the excerpts, cite pages as [Title, p. N], admit when the documents do
/// not cover the question.
const localSystemInstruction =
    'You are a careful document assistant. Answer ONLY from the excerpts '
    'provided with each question. Cite the page you used as [Title, p. N]. '
    "If the excerpts do not contain the answer, reply exactly: "
    "The documents don't cover that. Keep answers brief.";

/// Wraps the retrieved passages and the question into one prompt turn.
///
/// Small models drift: given a page header, a stray page number or a wall of
/// punctuation, they copy it instead of answering. The excerpts are therefore
/// fenced off as data, on lines of their own, with the question clearly after
/// them — so "answer the question" is the last thing the model read.
String buildGroundedQuestion(String question, List<RagChunk> chunks) {
  final excerpts = StringBuffer()
    ..writeln('The text between the markers is quoted reference material.')
    ..writeln('--- BEGIN EXCERPTS ---');
  for (final chunk in chunks) {
    excerpts
      ..writeln()
      ..writeln('[${chunk.docTitle}, p. ${chunk.page}]')
      ..writeln(chunk.text.trim());
  }
  excerpts
    ..writeln()
    ..writeln('--- END EXCERPTS ---')
    ..writeln()
    ..writeln('Using only the excerpts above, answer this question.');
  return '$excerpts\nQuestion: $question';
}

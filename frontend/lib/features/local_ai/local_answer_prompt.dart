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
String buildGroundedQuestion(String question, List<RagChunk> chunks) {
  final excerpts = StringBuffer('Excerpts from the documents:\n');
  for (final chunk in chunks) {
    excerpts.writeln();
    excerpts.writeln('Source [${chunk.docTitle}, p. ${chunk.page}]:');
    excerpts.writeln(chunk.text);
  }
  excerpts.writeln();
  excerpts.write('Question: $question');
  return excerpts.toString();
}

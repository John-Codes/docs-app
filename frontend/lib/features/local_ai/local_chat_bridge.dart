import 'package:flutter_edge_ai/flutter_edge_ai.dart';

import '../chat/chat_source.dart';
import 'local_answer_prompt.dart';
import 'local_grounding.dart';

final localChatBridge = LocalChatBridge();

/// The result of one on-device turn: the streamed answer plus the citations
/// that back it, shown exactly like a cloud answer.
class LocalAnswer {
  const LocalAnswer({required this.text, required this.sources});

  final String text;
  final List<ChatSource> sources;
}

/// Runs one on-device answer end to end: retrieve chunks, stream the model.
///
/// Returns null on ANY failure — nothing retrieved, engine error, model
/// crash, empty answer — so the chat silently falls back to the cloud and
/// the user experience never degrades because of local mode.
class LocalChatBridge {
  LocalChatBridge([LocalGrounding? grounding])
      : _grounding = grounding ?? LocalGrounding();

  final LocalGrounding _grounding;
  InferenceChat? _chat;

  Future<LocalAnswer?> answer(String question) async {
    try {
      final chunks = await _grounding.retrieve(question);
      if (chunks.isEmpty) return null; // Cloud answers "don't cover that".

      final chat = await _openChat();
      await chat.addQueryChunk(
        Message.text(
          text: buildGroundedQuestion(question, chunks),
          isUser: true,
        ),
      );

      final answer = await _streamAnswer(chat);
      if (answer.trim().isEmpty) return null;

      return LocalAnswer(text: answer.trim(), sources: _citations(chunks));
    } catch (_) {
      _chat = null; // A broken session must not poison the next turn.
      return null;
    }
  }

  Future<InferenceChat> _openChat() async {
    if (_chat != null) return _chat!;
    final model = await FlutterEdgeAi.getActiveModel(maxTokens: 2048);
    _chat = await model.createChat(systemInstruction: localSystemInstruction);
    return _chat!;
  }

  Future<String> _streamAnswer(InferenceChat chat) async {
    final answer = StringBuffer();
    await for (final response in chat.generateChatResponseAsync()) {
      if (response is TextResponse) answer.write(response.token);
    }
    return answer.toString();
  }

  /// One citation per cited page, mirroring the cloud source list.
  List<ChatSource> _citations(List<GroundedChunk> chunks) {
    final seen = <String>{};
    final sources = <ChatSource>[];
    for (final chunk in chunks) {
      final key = '${chunk.docId}:${chunk.page}';
      if (seen.contains(key)) continue;
      seen.add(key);
      sources.add(
        ChatSource(
          docId: chunk.docId,
          docTitle: chunk.docTitle,
          page: chunk.page,
          score: 0,
          snippet: chunk.text.length > 260
              ? chunk.text.substring(0, 260)
              : chunk.text,
        ),
      );
    }
    return sources;
  }
}

import 'package:flutter_edge_ai/flutter_edge_ai.dart';

import '../chat/chat_source.dart';
import '../on_device_rag/rag_chunk.dart';
import '../on_device_rag/sequential_model_loader.dart';
import 'local_answer_prompt.dart';

final localChatBridge = LocalChatBridge();

/// The result of one on-device turn: the streamed answer plus the citations
/// that back it, shown exactly like a cloud answer.
class LocalAnswer {
  const LocalAnswer({required this.text, required this.sources});

  final String text;
  final List<ChatSource> sources;
}

/// Runs one on-device answer end to end from excerpts retrieved locally.
///
/// Returns null on ANY failure — engine error, model crash, empty answer —
/// so the chat silently falls back to the cloud and the user experience
/// never degrades because of local mode.
class LocalChatBridge {
  LocalChatBridge() {
    sequentialModelLoader.unloadLanguageModel = unload;
  }

  InferenceModel? _model;
  InferenceChat? _chat;

  Future<LocalAnswer?> answer(
    String question,
    List<RagChunk> chunks, {
    void Function(String token)? onToken,
  }) async {
    if (chunks.isEmpty) return null;
    try {
      return await sequentialModelLoader.run(OnDeviceModel.languageModel, () async {
        final chat = await _openChat();
        await chat.addQueryChunk(
          Message.text(text: buildGroundedQuestion(question, chunks), isUser: true),
        );
        final answer = await _streamAnswer(chat, onToken);
        if (answer.trim().isEmpty) return null;
        return LocalAnswer(text: answer.trim(), sources: _citations(chunks));
      });
    } catch (_) {
      await unload(); // A broken session must not poison the next turn.
      return null;
    }
  }

  /// Releases the answer model completely — the memory the embedding model
  /// needs back on a device that can only hold one of them.
  Future<void> unload() async {
    final chat = _chat;
    final model = _model;
    _chat = null;
    _model = null;
    try {
      await chat?.close();
      await model?.close();
    } catch (_) {
      // Already gone; the reference is dropped either way.
    }
    sequentialModelLoader.markClosed(OnDeviceModel.languageModel);
  }

  Future<InferenceChat> _openChat() async {
    final existing = _chat;
    if (existing != null) return existing;
    final model = await FlutterEdgeAi.getActiveModel(maxTokens: 2048);
    _model = model;
    final chat = await model.createChat(systemInstruction: localSystemInstruction);
    _chat = chat;
    return chat;
  }

  Future<String> _streamAnswer(
    InferenceChat chat,
    void Function(String token)? onToken,
  ) async {
    final answer = StringBuffer();
    await for (final response in chat.generateChatResponseAsync()) {
      if (response is TextResponse) {
        answer.write(response.token);
        onToken?.call(response.token);
      }
    }
    return answer.toString();
  }

  /// One citation per cited page, mirroring the cloud source list.
  List<ChatSource> _citations(List<RagChunk> chunks) {
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
          score: chunk.score,
          snippet: chunk.text.length > 260
              ? chunk.text.substring(0, 260)
              : chunk.text,
        ),
      );
    }
    return sources;
  }
}

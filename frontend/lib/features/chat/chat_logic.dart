import 'package:flutter/material.dart';

import '../local_ai/local_ai.dart';
import '../on_device_rag/on_device_rag.dart';
import 'chat_api.dart';
import 'chat_message.dart';
import 'chat_source.dart';

final chatLogic = ChatLogic();

class ChatLogic extends ChangeNotifier {
  ChatLogic() {
    messages.add(
      ChatMessage(
        text:
            'Ask anything about the documents in your library. '
            'Every answer cites the page it came from.',
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  final List<ChatMessage> messages = [];
  final TextEditingController textController = TextEditingController();
  final FocusNode focusNode = FocusNode();
  final ChatApi _api = ChatApi();
  bool isLoading = false;

  Future<void> sendMessage() async {
    final text = textController.text.trim();
    if (text.isEmpty || isLoading) return;

    final history = List<ChatMessage>.from(messages);
    textController.clear();
    messages.add(
      ChatMessage(text: text, isUser: true, timestamp: DateTime.now()),
    );
    isLoading = true;
    notifyListeners();

    // Retrieval happens on the device for both answer paths. A failure is
    // said out loud instead of being folded into "don't cover that": it is
    // the difference between a document that lacks the answer and search
    // that never ran. No excerpts means no network round trip either way.
    final List<RagChunk> excerpts;
    try {
      excerpts = await localRetriever.retrieve(text);
    } catch (_) {
      _settle(_searchFailedMessage(), const []);
      return;
    }
    if (excerpts.isEmpty) {
      _settle(_noExcerptsMessage(), const []);
      return;
    }

    if (localAiState.useLocal && localAiState.available) {
      final stream = LocalReplyStream(messages, notifyListeners);
      stream.start();
      final localAnswer = await localChatBridge.answer(
        text,
        excerpts,
        onToken: stream.onToken,
      );
      if (localAnswer != null) {
        stream.finish(localAnswer);
        _settle(null, const []);
        return;
      }
      // Any local failure silently continues with the cloud answer below;
      // the half-written bubble is removed first.
      stream.discard();
    }

    try {
      final reply = await _api.ask(text, history, excerpts);
      _settle(
        reply.answer.isEmpty ? "The documents don't cover that." : reply.answer,
        reply.sources,
      );
    } catch (failure) {
      _settle(
        'Something went wrong. '
        '${failure.toString().replaceFirst('Exception: ', '')}',
        const [],
      );
    }
  }

  /// No excerpts is usually an honest "not in the documents", but it must
  /// not hide a missing search model or a document that never indexed.
  String _noExcerptsMessage() {
    final documents = documentCatalog.read();
    if (documents.isEmpty) {
      return 'Upload a PDF first, then ask about it.';
    }
    if (!searchModelStore.isInstalled) {
      return 'Search is not ready on this device yet. Download the search '
          'model from the badge at the top, then ask again.';
    }
    if (!documents.any((document) => document.isReady && document.chunks > 0)) {
      return documents.any((document) => document.isProcessing)
          ? 'The documents are still being indexed. Try again in a moment.'
          : 'No document could be indexed on this device yet. Open the '
                'library, remove the failed document and upload it again.';
    }
    return "The documents don't cover that.";
  }

  /// Search itself broke (embedder or index unavailable): say so instead of
  /// pretending the documents lack the answer.
  String _searchFailedMessage() {
    if (!searchModelStore.isInstalled) {
      return 'Search is not ready on this device yet. Download the search '
          'model from the badge at the top, then ask again.';
    }
    return 'On-device search could not run on this device. Reload the page '
        'and try again — uploading still works meanwhile.';
  }

  /// Adds an assistant bubble unless told otherwise, then ends the turn.
  void _settle(String? text, List<ChatSource> sources) {
    if (text != null) {
      messages.add(
        ChatMessage(
          text: text,
          isUser: false,
          timestamp: DateTime.now(),
          sources: sources,
        ),
      );
    }
    isLoading = false;
    notifyListeners();
    focusNode.requestFocus();
  }
}

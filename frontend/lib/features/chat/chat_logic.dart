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
    } catch (failure) {
      _settle(_searchFailedMessage(failure), const []);
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
    final waiting = _searchModelWaitMessage();
    if (waiting != null) return waiting;
    if (!documents.any((document) => document.isReady && document.chunks > 0)) {
      return documents.any((document) => document.isProcessing)
          ? 'The documents are still being indexed. Try again in a moment.'
          : 'No document could be indexed on this device yet. Open the '
                'library, remove the failed document and upload it again.';
    }
    return "The documents don't cover that.";
  }

  /// Search itself broke (embedder or index unavailable): say so instead of
  /// pretending the documents lack the answer. The reason matters — another
  /// tab holding the database and a missing model need different fixes —
  /// so it comes from the failure itself.
  String _searchFailedMessage(Object failure) {
    final waiting = _searchModelWaitMessage();
    if (waiting != null) return waiting;
    debugPrint('[on-device-rag] chat search failed: $failure');
    return describeIndexFailure(failure);
  }

  /// What to say when the search model is the reason search did not run.
  ///
  /// A question asked mid-download used to be answered with "not ready yet",
  /// which reads like a fault and gives no sense of when to try again. The
  /// live percentage says the app is working on it. Null when the model is
  /// installed, so the caller falls through to its own reason.
  String? _searchModelWaitMessage() {
    if (searchModelStore.isInstalled) return null;
    if (localAiState.searchDownloadActive) {
      return 'Still getting this device ready — the search model is '
          '${localAiState.searchProgress}% downloaded. Ask again once it '
          'finishes and I can read your documents.';
    }
    return 'This device needs its search model before it can read your '
        'documents. Tap Download now in the bar above the message box, '
        'then ask again.';
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

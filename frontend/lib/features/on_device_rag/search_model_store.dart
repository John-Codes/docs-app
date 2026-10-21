import 'dart:async';

import 'package:flutter_edge_ai/flutter_edge_ai.dart';

import '../local_ai/download_retry.dart';
import '../local_ai/local_ai_state.dart';

/// Downloads and tracks the on-device search model: Gecko-110m.
///
/// It turns document passages and questions into 768-number vectors, which
/// the local SQLite index searches. Without it nothing can be indexed or
/// retrieved, so cloud answers need it too; once installed, retrieval and
/// answers work with no network. 114 MB, ungated, in the browser's storage.
final searchModelStore = SearchModelStore();

class SearchModelStore {
  static const _revision = '61a0d0c2cdc9b4f2c1727e63acb7ad86e68508c2';
  static const _base =
      'https://huggingface.co/litert-community/Gecko-110m-en/resolve/'
      '$_revision';

  /// Filenames double as the embedding profile, so pin them.
  static const modelFile = 'Gecko_256_quant.tflite';
  static const tokenizerFile = 'gecko-110m-en-sentencepiece.model';

  bool get isInstalled => FlutterEdgeAi.activeEmbedderSpec != null;

  /// Installs the model unless it is already here. Returns whether it is
  /// ready; callers treat false as "no local retrieval right now".
  Future<bool> ensureInstalled() async {
    if (isInstalled) return true;
    await download();
    return isInstalled;
  }

  /// Resolves when the search model is installed: immediately when it
  /// already is, otherwise when a running download finishes. Never starts
  /// a download itself — the 114 MB is the user's call.
  Future<bool> whenReady({
    Duration timeout = const Duration(minutes: 30),
  }) async {
    if (isInstalled) return true;
    final ready = Completer<bool>();
    void check() {
      if (localAiState.searchReady && !ready.isCompleted) ready.complete(true);
    }

    localAiState.addListener(check);
    check();
    final installed = await ready.future.timeout(
      timeout,
      onTimeout: () => false,
    );
    localAiState.removeListener(check);
    return installed;
  }

  /// Runs in the background: progress goes to [localAiState], never to a
  /// blocking dialog, and a failure just leaves local retrieval off.
  ///
  /// A failure retries itself a couple of times first. This download is the
  /// one everything else waits on — no embedder means no indexing, no
  /// retrieval, and no chat answer even from the cloud — so a transient
  /// stumble near the end must not require the user to spot a badge and
  /// press Retry.
  Future<void> download() async {
    if (localAiState.searchDownloadActive) return;
    localAiState.update(
      searchDownloading: true,
      searchFailed: false,
      searchProgress: 0,
    );
    try {
      await retrying(
        attempt: () => FlutterEdgeAi.installEmbedder()
            .modelFromNetwork('$_base/$modelFile', filename: modelFile)
            .tokenizerFromNetwork(
              '$_base/sentencepiece.model',
              filename: tokenizerFile,
            )
            .withModelProgress(
              (progress) => localAiState.update(searchProgress: progress),
            )
            .withTokenizerProgress(
              (progress) => localAiState.update(searchProgress: progress),
            )
            .install(),
        isCancelled: () => false,
        // Start the bar over so a retry reads as new work, not a stall.
        onRetry: (_) => localAiState.update(searchProgress: 0),
      );
      localAiState.update(
        searchDownloading: false,
        searchReady: true,
        searchProgress: 100,
      );
    } catch (_) {
      localAiState.update(
        searchDownloading: false,
        searchFailed: true,
        searchProgress: 0,
      );
    }
  }
}

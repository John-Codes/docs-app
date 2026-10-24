import 'package:flutter_edge_ai/flutter_edge_ai.dart';

import '../error_reports/download_failure.dart';
import 'download_retry.dart';
import 'local_ai_preferences.dart';
import 'local_ai_state.dart';
import 'model_token.dart';
import 'opfs_models.dart';
import 'storage_guard.dart';
import 'storage_room.dart';

final localModelStore = LocalModelStore();

/// Downloads and tracks the on-device model (Gemma 3 1B web build).
///
/// The download runs entirely in the background: it never blocks the UI,
/// the cloud chat, or document uploads/downloads; it reports progress
/// through [localAiState] and can be cancelled. Any failure just marks the
/// download failed — the app continues exactly as before.
class LocalModelStore {
  CancelToken? _cancelToken;

  /// Set while the user has stopped the download, so a retry in flight
  /// never resurrects it behind their back.
  bool _stopped = false;

  /// The Gemma 3 1B web build is gated on Hugging Face: accept its license
  /// once, then either let the server supply the token (GET /token) or mirror
  /// the file and point LOCAL_MODEL_URL at your own storage.
  static const _defaultUrl =
      'https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/'
      'gemma3-1b-it-int4-web.task';

  String get modelUrl {
    const configured = String.fromEnvironment('LOCAL_MODEL_URL');
    return configured.isEmpty ? _defaultUrl : configured;
  }

  /// The file name the engine stores the model under, taken from the URL so a
  /// mirrored copy keeps working.
  String get modelFile => Uri.parse(modelUrl).pathSegments.last;

  /// Starts the background download. Safe to call again while it runs, and
  /// safe after an interrupted download — installModel restarts and picks
  /// up what it can. A manual start counts as fresh consent, so it clears
  /// any earlier "not now".
  Future<void> download() async {
    if (localAiState.downloadActive) return;
    await localAiPreferences.clearDeclined();

    // Ask the browser to keep this data instead of evicting it later.
    await requestPersistentStorage();

    // A half-written file from an interrupted download looks "cached" to the
    // engine and would be installed without downloading anything. Drop it
    // first, which also frees its space before the room check.
    await discardIncompleteModel(modelFile);

    // A full browser is the one failure no retry can fix, and the browser
    // only reports it after the whole file has been fetched. Ask first.
    final needed = neededFor(
      modelBytes: answerModelBytes,
      searchInstalled: localAiState.searchReady,
    );
    final room = await readStorageRoom(needed);
    if (room != null && !room.enough) {
      localAiState.update(
        downloading: false,
        failed: true,
        progress: 0,
        error: storageShortageMessage(room),
      );
      return;
    }

    _stopped = false;
    localAiState.update(
      downloading: true,
      failed: false,
      progress: 0,
      error: '', // Clear any message from a previous attempt.
    );
    try {
      final token = await modelToken.read();
      await retrying(
        // A cancelled token stays cancelled, so every attempt gets its own;
        // the store's flag is what actually decides whether to keep going.
        attempt: () async {
          // A retry after a failed write must not reuse the broken file.
          await discardIncompleteModel(modelFile);
          final attemptToken = CancelToken();
          _cancelToken = attemptToken;
          await FlutterEdgeAi.installModel(
            modelType: ModelType.gemmaIt,
            fileType: ModelFileType.task,
          )
              .fromNetwork(modelUrl, token: token)
              .withCancelToken(attemptToken)
              .withProgress((int progress) {
            localAiState.update(progress: progress);
          }).install();
          await markModelComplete(modelFile);
        },
        isCancelled: () => _stopped,
        // A dropped connection is worth another try; a full disk or a
        // refused license is not, and retrying would fetch 700 MB again.
        shouldRetry: isRetryableDownloadFailure,
        onRetry: (_) => localAiState.update(progress: 0),
      );
      localAiState.update(downloading: false, model: true, progress: 100);
    } catch (failure) {
      // Free whatever the failed attempt wrote so the next try has room.
      await discardIncompleteModel(modelFile);
      // A cancelled download is quiet; a real failure explains itself in
      // the download sheet — never as a chat error, never blocking anything.
      final cancelled = CancelToken.isCancel(failure);
      final described = describeAndReportDownloadFailure(
        'download_failed',
        'answer_model',
        failure,
      );
      localAiState.update(
        downloading: false,
        failed: !cancelled,
        progress: 0,
        error: cancelled ? '' : described.headline,
      );
    }
  }

  /// Stops the download and remembers the decision, so smart auto-download
  /// never starts it again by itself. The badge stays for a manual restart.
  Future<void> cancel() async {
    _stopped = true;
    _cancelToken?.cancel('User stopped the on-device model download.');
    localAiState.update(downloading: false);
    await localAiPreferences.markDownloadDeclined();
  }

  bool get isModelInstalled => FlutterEdgeAi.activeModelSpec != null;
}

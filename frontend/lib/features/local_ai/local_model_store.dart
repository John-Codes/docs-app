import 'package:flutter_edge_ai/flutter_edge_ai.dart';

import 'local_ai_state.dart';

final localModelStore = LocalModelStore();

/// Downloads and tracks the on-device model (Gemma 3 1B web build).
///
/// The download runs entirely in the background: it never blocks the UI,
/// the cloud chat, or document uploads/downloads; it reports progress
/// through [localAiState] and can be cancelled. Any failure just marks the
/// download failed — the app continues exactly as before.
class LocalModelStore {
  CancelToken? _cancelToken;

  /// Set to true to download automatically as soon as the device qualifies.
  /// Off by default: 530 MB is the user's mobile-data decision.
  static const autoDownload = false;

  /// The Gemma 3 1B web build is gated on Hugging Face: accept its license
  /// once, then either pass HUGGINGFACE_TOKEN at build time or mirror the
  /// file and point LOCAL_MODEL_URL at your own storage.
  static const _defaultUrl =
      'https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/'
      'gemma3-1b-it-int4-web.task';

  String get modelUrl {
    const configured = String.fromEnvironment('LOCAL_MODEL_URL');
    return configured.isEmpty ? _defaultUrl : configured;
  }

  /// Starts the background download. Safe to call again while it runs.
  Future<void> download() async {
    if (localAiState.downloadActive) return;
    localAiState.update(downloading: true, failed: false, progress: 0);
    _cancelToken = CancelToken();
    try {
      await FlutterEdgeAi.installModel(
        modelType: ModelType.gemmaIt,
        fileType: ModelFileType.task,
      )
          .fromNetwork(modelUrl, token: _huggingFaceToken)
          .withCancelToken(_cancelToken!)
          .withProgress((int progress) {
        localAiState.update(progress: progress);
      }).install();
      localAiState.update(downloading: false, model: true, progress: 100);
    } catch (failure) {
      // A cancelled download is quiet; a real failure shows a retry chip.
      final cancelled = CancelToken.isCancel(failure);
      localAiState.update(
        downloading: false,
        failed: !cancelled,
        progress: 0,
      );
    }
  }

  void cancel() {
    _cancelToken?.cancel('User stopped the on-device model download.');
    localAiState.update(downloading: false);
  }

  bool get isModelInstalled => FlutterEdgeAi.activeModelSpec != null;

  static String? get _huggingFaceToken {
    const token = String.fromEnvironment('HUGGINGFACE_TOKEN');
    return token.isEmpty ? null : token;
  }
}

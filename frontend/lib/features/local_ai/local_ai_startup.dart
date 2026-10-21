import 'dart:async';

import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_edge_ai_embeddings/flutter_edge_ai_embeddings.dart';
import 'package:flutter_edge_ai_litertlm/flutter_edge_ai_litertlm.dart';
import 'package:flutter_edge_ai_mediapipe/flutter_edge_ai_mediapipe.dart';

import '../on_device_rag/on_device_rag.dart';
import 'browser_connectivity.dart';
import 'local_ai_gate.dart';
import 'local_ai_preferences.dart';
import 'local_ai_state.dart';
import 'local_model_store.dart';
import 'model_token.dart';

/// Boots the on-device AI engine in the background.
///
/// Never throws and never blocks the UI: the cloud app runs first and the
/// local parts turn themselves on only when their step succeeds. The
/// embedding backend is always registered — cloud answers retrieve their
/// excerpts on the device too — while on-device answers stay gated on a
/// device that can actually run the WebGPU model.
Future<void> startLocalAi() async {
  try {
    final token = await modelToken.read();
    await FlutterEdgeAi.initialize(
      inferenceEngines: const [MediaPipeEngine()],
      embeddingBackends: const [LiteRtEmbeddingBackend()],
      embeddingTokenizers: const [GemmaEmbeddingTokenizers()],
      huggingFaceToken: token,
    ).timeout(_startupTimeout, onTimeout: () {});

    localAiState.update(engine: true);
    await _cleanupInterruptedFiles();
    unawaited(startOnDeviceRag());

    if (!await isDeviceSupportedForLocalAi()) return;
    localAiState.update(supported: true);

    final alreadyHere = FlutterEdgeAi.activeModelSpec != null;
    localAiState.update(model: alreadyHere);
    if (!alreadyHere) await _maybeAutoDownload();
  } catch (_) {
    // Local AI is a bonus, never a requirement. Cloud chat is untouched.
  }
}

const _startupTimeout = Duration(seconds: 60);

/// Removes partial files left by an interrupted download. Called after the
/// engine is ready — the interrupted download itself is restarted by the
/// auto-download below or by the user's "Get offline mode" button.
Future<void> _cleanupInterruptedFiles() async {
  try {
    await FlutterEdgeAi.performCleanup();
  } catch (_) {
    // Cleanup is best-effort; a failure must never affect the app.
  }
}

/// Auto-download the ~530 MB answer model without asking.
///
/// The unmetered check is deliberately not used: the browser cannot confirm
/// a connection on Safari or Firefox, so requiring it left users with no
/// on-device answers and no idea why. The download starts whenever the app is
/// online and the user has not stopped it before; the download sheet's Stop
/// button cancels it and remembers that choice, so it is never restarted
/// against someone's wishes.
Future<void> _maybeAutoDownload() async {
  try {
    if (await localAiPreferences.isDownloadDeclined()) return;
    if (!browserConnectivity.online) return;
    unawaited(localModelStore.download());
  } catch (_) {
    // Auto-download is opportunistic; never let it surface an error.
  }
}

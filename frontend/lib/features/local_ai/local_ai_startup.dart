import 'dart:async';

import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_edge_ai_mediapipe/flutter_edge_ai_mediapipe.dart';

import 'browser_connectivity.dart';
import 'local_ai_gate.dart';
import 'local_ai_preferences.dart';
import 'local_ai_state.dart';
import 'local_model_store.dart';

/// Boots the on-device AI engine in the background.
///
/// Never throws and never blocks the UI: the cloud app runs first and the
/// local mode turns itself on only when every step below succeeds. A device
/// that fails the gate, an unreachable CDN, an engine error — each one just
/// leaves local mode invisible while the cloud chat keeps working.
Future<void> startLocalAi() async {
  try {
    if (!await isDeviceSupportedForLocalAi()) return;
    localAiState.update(supported: true);

    await FlutterEdgeAi.initialize(
      inferenceEngines: const [MediaPipeEngine()],
      huggingFaceToken: _huggingFaceToken,
    ).timeout(_startupTimeout, onTimeout: () {});

    localAiState.update(engine: true);
    await _cleanupInterruptedFiles();
    final alreadyHere = FlutterEdgeAi.activeModelSpec != null;
    localAiState.update(model: alreadyHere);
    if (!alreadyHere) await _maybeAutoDownload();
  } catch (_) {
    // Local AI is a bonus, never a requirement. Cloud chat is untouched.
  }
}

const _startupTimeout = Duration(seconds: 60);

String? get _huggingFaceToken {
  const token = String.fromEnvironment('HUGGINGFACE_TOKEN');
  return token.isEmpty ? null : token;
}

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

/// Smart auto-download: start the ~530 MB download without asking only
/// when the connection is verifiably unmetered (Wi-Fi/Ethernet, data saver
/// off) and the user has not declined before. Otherwise the badge shows
/// "Get offline mode" and the user stays in control.
Future<void> _maybeAutoDownload() async {
  try {
    if (await localAiPreferences.isDownloadDeclined()) return;
    if (!browserConnectivity.isUnmetered()) return;
    unawaited(localModelStore.download());
  } catch (_) {
    // Auto-download is opportunistic; never let it surface an error.
  }
}

import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_edge_ai_mediapipe/flutter_edge_ai_mediapipe.dart';

import 'local_ai_gate.dart';
import 'local_ai_state.dart';

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
    localAiState.update(model: _modelAlreadyInstalled);
  } catch (_) {
    // Local AI is a bonus, never a requirement. Cloud chat is untouched.
  }
}

const _startupTimeout = Duration(seconds: 60);

String? get _huggingFaceToken {
  const token = String.fromEnvironment('HUGGINGFACE_TOKEN');
  return token.isEmpty ? null : token;
}

bool get _modelAlreadyInstalled => FlutterEdgeAi.activeModelSpec != null;

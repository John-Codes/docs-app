import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_edge_ai_embeddings/flutter_edge_ai_embeddings.dart';
import 'package:flutter_edge_ai_litertlm/flutter_edge_ai_litertlm.dart';
import 'package:flutter_edge_ai_mediapipe/flutter_edge_ai_mediapipe.dart';

import '../error_reports/error_reporter.dart';
import '../on_device_rag/on_device_rag.dart';
import 'browser_connectivity.dart';
import 'local_ai_gate.dart';
import 'local_ai_preferences.dart';
import 'local_ai_state.dart';
import 'local_model_store.dart';
import 'model_token.dart';
import 'opfs_models.dart';

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
    final capabilities = await opfsWriteCapabilities();
    await FlutterEdgeAi.initialize(
      inferenceEngines: const [MediaPipeEngine()],
      embeddingBackends: const [LiteRtEmbeddingBackend()],
      embeddingTokenizers: const [GemmaEmbeddingTokenizers()],
      huggingFaceToken: token,
      // Stream model bytes straight to disk (OPFS) instead of buffering the
      // whole file in memory and copying it into the Cache API. The 700 MB
      // answer model otherwise peaks at well over a gigabyte of RAM, and a
      // full browser only refused it after the entire fetch had finished.
      // Browsers that cannot write OPFS (Safari/iOS 15-18) get the Cache API
      // instead: the worker shim covers them, and a missing write API must
      // not kill the ungated 114 MB search model with it.
      webStorageMode: _storageModeFor(capabilities),
    ).timeout(_startupTimeout, onTimeout: () {});

    localAiState.update(engine: true);
    await _cleanupInterruptedFiles();
    await _repairInstalledModels();
    unawaited(startOnDeviceRag());

    if (!await isDeviceSupportedForLocalAi()) {
      await reportClientError(
        'device_unsupported',
        'device_gate',
        extra: {'reason': 'webgpu/cores/memory/storage gate failed'},
      );
      return;
    }
    localAiState.update(supported: true);

    final alreadyHere = FlutterEdgeAi.activeModelSpec != null;
    localAiState.update(model: alreadyHere);
    if (!alreadyHere) await _maybeAutoDownload();
  } catch (failure) {
    // Local AI is a bonus, never a requirement. Cloud chat is untouched —
    // but the failure is reported so the badge can say why it is missing
    // instead of leaving the user with no download button and no reason.
    debugPrint('[local-ai] startup failed: $failure');
    await reportClientError('engine_init_failed', 'engine_init', error: failure);
  }
}

/// Streaming needs a browser that can write OPFS files; everyone else falls
/// back to the Cache API so the search model still downloads.
WebStorageMode _storageModeFor(OpfsWriteCapabilities? capabilities) {
  if (capabilities == null) return WebStorageMode.cacheApi;
  return capabilities.usable ? WebStorageMode.streaming : WebStorageMode.cacheApi;
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

/// Deletes streamed model files that were never finished and forgets their
/// stale "installed" records. Without this an interrupted 700 MB download
/// leaves a file the engine happily treats as a cached model, so the app
/// claims offline mode is ready for a model that cannot load.
Future<void> _repairInstalledModels() async {
  // Streaming mode uses OPFS; without it the browser keeps models in the
  // Cache API, so "not in OPFS" says nothing about the model being missing.
  // Repairing there would delete a healthy record and re-download each load.
  if (!await opfsAvailable()) return;
  var answerChanged = false;
  var searchChanged = false;
  try {
    answerChanged = await _repairModel(localModelStore.modelFile);
  } catch (_) {}
  try {
    searchChanged =
        await _repairModel(SearchModelStore.modelFile) || searchChanged;
    searchChanged =
        await _repairModel(SearchModelStore.tokenizerFile) || searchChanged;
  } catch (_) {}
  try {
    if (answerChanged) await FlutterEdgeAi.clearActiveInferenceIdentity();
    if (searchChanged) await FlutterEdgeAi.clearActiveEmbeddingIdentity();
  } catch (_) {
    // A stale identity is retried at the next start.
  }
}

/// Removes one stored file that is not proven complete, plus the installation
/// record that would otherwise make the next install skip the download.
Future<bool> _repairModel(String filename) async {
  final cached = await readCachedModel(filename);
  final recorded = await FlutterEdgeAi.isModelInstalled(filename);
  // A complete file is healthy whether or not a record exists: without a
  // record the next install records it and reuses the bytes.
  if (cached?.complete ?? false) return false;
  if (!recorded && cached == null) return false;
  if (recorded) {
    try {
      await FlutterEdgeAi.uninstallModel(filename);
    } catch (_) {
      // Nothing recorded under that name after all.
    }
  }
  await discardIncompleteModel(filename);
  return true;
}

/// Auto-download the ~700 MB answer model without asking.
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

import 'dart:async';

import 'package:flutter_edge_ai_litertlm/flutter_edge_ai_litertlm.dart';

import '../local_ai/browser_connectivity.dart';
import '../local_ai/local_ai_state.dart';
import 'bundled_document.dart';
import 'local_library.dart';
import 'search_model_store.dart';

/// Wires the on-device RAG pipeline into the app after the AI engine is up.
///
/// Never throws: the cloud chat keeps working even if none of this does.
/// Embeddings are WASM, so they work on browsers without WebGPU too — that
/// is why this does not use the local-answer device gate.
Future<void> startOnDeviceRag() async {
  try {
    // Serve the LiteRT WASM runtime from the app itself: the package
    // default is a CDN, and offline answers must not need one.
    LiteRtWebRuntime.wasmPath = '/wasm/';

    localAiState.update(searchReady: searchModelStore.isInstalled);
    if (!searchModelStore.isInstalled && browserConnectivity.isUnmetered()) {
      unawaited(searchModelStore.download());
    }
    browserConnectivity.addListener(_reindexDraftsWhenOnline);
    unawaited(_restoreLibrary());
  } catch (_) {
    // Local retrieval stays off; cloud chat is unaffected.
  }
}

/// Brings the library up to date once search is installed: the document
/// that ships with the app, and anything that failed before the passages
/// were split to fit the embedder. Never forces the 114 MB download.
Future<void> _restoreLibrary() async {
  try {
    if (!await searchModelStore.whenReady()) return;
    await bundledDocument.seed();
    await localLibrary.retryFailed();
  } catch (_) {
    // Best effort; uploads and cloud answers do not depend on this.
  }
}

void _reindexDraftsWhenOnline() {
  if (!browserConnectivity.online) return;
  unawaited(localLibrary.reindexDrafts());
}

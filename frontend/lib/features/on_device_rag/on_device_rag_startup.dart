import 'dart:async';

import 'package:flutter_edge_ai_litertlm/flutter_edge_ai_litertlm.dart';
import 'package:web/web.dart' as web;

import '../local_ai/browser_connectivity.dart';
import '../local_ai/local_ai_state.dart';
import 'bundled_document.dart';
import 'document_catalog.dart';
import 'index_trouble.dart';
import 'local_library.dart';
import 'passage_budget.dart';
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
/// that ships with the app, anything a previous session left mid-index, and
/// — only when the passage pipeline changed — anything that failed under the
/// older splitter. Never forces the 114 MB download, and never re-embeds a
/// ready document on app load.
Future<void> _restoreLibrary() async {
  try {
    if (!await searchModelStore.whenReady()) return;
    await bundledDocument.seed();
    await localLibrary.resumeInterrupted();
    await _healFailedDocumentsOnce();
  } catch (_) {
    // Best effort; uploads and cloud answers do not depend on this.
  }
}

const _pipelineVersionKey = 'on_device_rag_pipeline_version_v1';

/// Rebuilds documents indexed under an older passage pipeline, once per
/// version, then records the version so later loads do no embedding work of
/// their own.
///
/// A pipeline change can make existing passages wrong rather than failed —
/// leader dots in the stored text, say — so a document that is already ready
/// has to be re-indexed too, or the old passages would outlive the fix.
/// A document that only failed because another tab held the database open is
/// retried on any load: that cause is gone once its tab is closed, and
/// re-uploading to recover from a locked tab would be a trap.
Future<void> _healFailedDocumentsOnce() async {
  final current = '$onDeviceRagPipelineVersion';
  final versionChanged = _readVersion() != current;
  final tabWasBusy = documentCatalog.read().any(
    (document) => document.hasFailed && isIndexBusy(document.error ?? ''),
  );
  if (!versionChanged && !tabWasBusy) return;
  // Offline the extraction would fail anyway; leave the version unclaimed
  // so one online load can heal them.
  if (!browserConnectivity.online) return;
  if (versionChanged) {
    await localLibrary.reindexOutdated();
  }
  await localLibrary.retryFailed();
  _writeVersion(current);
}

String? _readVersion() {
  try {
    return web.window.localStorage.getItem(_pipelineVersionKey);
  } catch (_) {
    return null;
  }
}

void _writeVersion(String value) {
  try {
    web.window.localStorage.setItem(_pipelineVersionKey, value);
  } catch (_) {
    // Storage is full or blocked: retrying once more next load is harmless.
  }
}

void _reindexDraftsWhenOnline() {
  if (!browserConnectivity.online) return;
  unawaited(localLibrary.reindexDrafts());
}

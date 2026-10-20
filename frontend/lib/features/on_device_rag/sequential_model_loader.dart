import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// The two on-device models that can be resident at the same time.
enum OnDeviceModel { embeddings, languageModel }

/// Runs on-device model work one stage at a time and, on devices without
/// memory headroom, unloads the other model first.
///
/// The embedding model (~110 MB) and the answer model (~530 MB) are both
/// large. On a phone they must never be resident together: embedding a
/// document and answering a question do not overlap, so the safe order is
/// always "embed, unload, generate" and back again. On a roomy desktop both
/// may stay loaded, which avoids paying a model load on every turn.
///
/// Every job is serialised through [run], so embedding work and generation
/// can never race for the same memory.
final sequentialModelLoader = SequentialModelLoader();

class SequentialModelLoader {
  SequentialModelLoader({this._oneModelAtATime});

  bool? _oneModelAtATime;
  Future<void> _tail = Future<void>.value();
  bool _embeddingsLoaded = false;
  bool _languageModelLoaded = false;

  /// What the caller must do to unload each model. Wired once at startup by
  /// the index (embeddings) and the chat bridge (answer model).
  Future<void> Function()? unloadEmbeddings;
  Future<void> Function()? unloadLanguageModel;

  bool get oneModelAtATime => _oneModelAtATime ??= _isTightDevice();

  /// Runs [work] as the only model stage in flight, after making room.
  Future<T> run<T>(OnDeviceModel model, Future<T> Function() work) {
    final job = _tail.then((_) async {
      await _makeRoomFor(model);
      final result = await work();
      _setLoaded(model, true);
      return result;
    });
    _tail = job.then((_) {}, onError: (_) {});
    return job;
  }

  /// Tells the loader a model was closed outside [run] (an error path).
  void markClosed(OnDeviceModel model) => _setLoaded(model, false);

  Future<void> _makeRoomFor(OnDeviceModel model) async {
    if (!oneModelAtATime) return;
    switch (model) {
      case OnDeviceModel.embeddings:
        if (_languageModelLoaded) {
          await unloadLanguageModel?.call();
          _setLoaded(OnDeviceModel.languageModel, false);
        }
      case OnDeviceModel.languageModel:
        if (_embeddingsLoaded) {
          await unloadEmbeddings?.call();
          _setLoaded(OnDeviceModel.embeddings, false);
        }
    }
  }

  void _setLoaded(OnDeviceModel model, bool loaded) {
    switch (model) {
      case OnDeviceModel.embeddings:
        _embeddingsLoaded = loaded;
      case OnDeviceModel.languageModel:
        _languageModelLoaded = loaded;
    }
  }
}

/// Unknown counts as tight: Safari and Firefox do not report memory, and
/// that includes most phones. Only a clearly roomy machine keeps both.
bool _isTightDevice() {
  if (!kIsWeb) return true;
  try {
    final navigator = web.window.navigator as JSObject;
    final memory = navigator['deviceMemory'];
    if (memory == null || memory.isUndefinedOrNull) return true;
    if ((memory as JSNumber).toDartDouble < 8) return true;
    final cores = navigator['hardwareConcurrency'];
    if (cores == null || cores.isUndefinedOrNull) return true;
    return (cores as JSNumber).toDartInt < 8;
  } catch (_) {
    return true;
  }
}

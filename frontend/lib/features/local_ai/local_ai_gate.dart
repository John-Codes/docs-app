import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'storage_room.dart';

/// Decides whether this browser can realistically run the 700 MB WebGPU
/// model. Any doubt (missing API, rejected GPU adapter, too few cores, too
/// little free storage) returns false — the app then silently stays on
/// the cloud chat and nothing about the local mode is ever shown.
Future<bool> isDeviceSupportedForLocalAi() async {
  if (!kIsWeb) return false;
  try {
    final navigator = web.window.navigator as JSObject;
    if (!await _hasWebGpu(navigator)) return false;
    if (!_hasEnoughCores(navigator)) return false;
    if (!_hasEnoughMemory(navigator)) return false;
    return await _hasStorageForModel(navigator);
  } catch (_) {
    return false; // Never let a probe failure surface to the user.
  }
}

const _minCores = 4;
const _minDeviceMemoryGb = 4.0;
// The answer model is 700 MB and must fit on disk alongside everything else.
const _minFreeStorageBytes = answerModelBytes + storageHeadroomBytes;

Future<bool> _hasWebGpu(JSObject navigator) async {
  final gpu = navigator['gpu'];
  if (gpu == null || gpu.isUndefinedOrNull) return false;
  final requestAdapter = (gpu as JSObject)['requestAdapter'];
  if (requestAdapter == null || requestAdapter.isUndefinedOrNull) return false;
  final pending = (requestAdapter as JSFunction).callAsFunction(gpu);
  if (pending == null || pending.isUndefinedOrNull) return false;
  final adapter = await (pending as JSPromise<JSAny?>).toDart;
  return adapter != null && !adapter.isUndefinedOrNull;
}

bool _hasEnoughCores(JSObject navigator) {
  final cores = navigator['hardwareConcurrency'];
  if (cores == null || cores.isUndefinedOrNull) return false;
  return (cores as JSNumber).toDartInt >= _minCores;
}

bool _hasEnoughMemory(JSObject navigator) {
  final memory = navigator['deviceMemory'];
  // Only Chromium reports deviceMemory; skip the check elsewhere.
  if (memory == null || memory.isUndefinedOrNull) return true;
  return (memory as JSNumber).toDartDouble >= _minDeviceMemoryGb;
}

Future<bool> _hasStorageForModel(JSObject navigator) async {
  final storage = navigator['storage'];
  if (storage == null || storage.isUndefinedOrNull) return true;
  final estimate = (storage as JSObject)['estimate'];
  if (estimate == null || estimate.isUndefinedOrNull) return true;
  final pending = (estimate as JSFunction).callAsFunction(storage);
  if (pending == null || pending.isUndefinedOrNull) return true;
  final estimateMap = await (pending as JSPromise<JSAny?>).toDart;
  if (estimateMap == null || estimateMap.isUndefinedOrNull) return true;
  final map = estimateMap as JSObject;
  final quota = _bytes(map['quota']);
  if (quota <= 0) return true; // Unknown: never block on a missing number.
  // What matters is free space, not the total quota: a large quota that is
  // already used up still cannot hold the model, and that was exactly the
  // "download stops at 99%" failure.
  final free = quota - _bytes(map['usage']);
  return free >= _minFreeStorageBytes;
}

int _bytes(JSAny? value) {
  if (value == null || value.isUndefinedOrNull) return 0;
  return value.isA<JSNumber>() ? (value as JSNumber).toDartInt : 0;
}

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Decides whether this browser can realistically run the ~530 MB WebGPU
/// model. Any doubt (missing API, rejected GPU adapter, too few cores, too
/// little storage quota) returns false — the app then silently stays on
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
// The model is ~530 MB; keep headroom for the browser cache and the app.
const _minStorageQuotaBytes = 1200 * 1024 * 1024;

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
  final quota = (estimateMap as JSObject)['quota'];
  if (quota == null || quota.isUndefinedOrNull) return true;
  return (quota as JSNumber).toDartInt >= _minStorageQuotaBytes;
}

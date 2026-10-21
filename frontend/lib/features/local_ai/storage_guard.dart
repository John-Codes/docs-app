import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'storage_room.dart';

/// Asks the browser how much storage it will allow this site to use and how
/// much is already taken, then compares the free part with [neededBytes].
///
/// Returns null when the browser cannot answer (Safari and Firefox hide the
/// numbers in some versions) or when this is not the web. Callers treat null
/// as "try anyway": a missing measurement must never block a download.
Future<StorageRoom?> readStorageRoom(int neededBytes) async {
  if (!kIsWeb) return null;
  try {
    final navigator = web.window.navigator as JSObject;
    final storage = navigator['storage'];
    if (storage == null || storage.isUndefinedOrNull) return null;
    final estimate = (storage as JSObject)['estimate'];
    if (estimate == null || estimate.isUndefinedOrNull) return null;
    final pending = (estimate as JSFunction).callAsFunction(storage);
    if (pending == null || pending.isUndefinedOrNull) return null;
    final result = await (pending as JSPromise<JSAny?>).toDart;
    if (result == null || result.isUndefinedOrNull) return null;

    final map = result as JSObject;
    final quota = map['quota'];
    final usage = map['usage'];
    return StorageRoom(
      quotaBytes: _asBytes(quota),
      usedBytes: _asBytes(usage),
      neededBytes: neededBytes,
    );
  } catch (_) {
    return null;
  }
}

int _asBytes(JSAny? value) {
  if (value == null || value.isUndefinedOrNull) return 0;
  return value.isA<JSNumber>() ? (value as JSNumber).toDartInt : 0;
}

/// Asks the browser to keep this site's data instead of evicting it when
/// space runs low. Best-effort: a refusal changes nothing for the user.
Future<void> requestPersistentStorage() async {
  if (!kIsWeb) return;
  try {
    final navigator = web.window.navigator as JSObject;
    final storage = navigator['storage'];
    if (storage == null || storage.isUndefinedOrNull) return;
    final persist = (storage as JSObject)['persist'];
    if (persist == null || persist.isUndefinedOrNull) return;
    final pending = (persist as JSFunction).callAsFunction(storage);
    if (pending == null || pending.isUndefinedOrNull) return;
    await (pending as JSPromise<JSAny?>).toDart;
  } catch (_) {
    // Persistence is a nicety; never let it affect the download.
  }
}

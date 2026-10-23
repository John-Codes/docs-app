import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'opfs_models.dart';
import 'storage_guard.dart';

/// The environment facts that explain a failed on-device install.
///
/// Only facts about the browser and its storage: never page content and
/// never the model token. Each probe fails soft, so a browser that hides one
/// value still reports everything else instead of dropping the whole report.
Future<Map<String, String>> deviceSnapshot() async {
  final context = <String, String>{};
  if (!kIsWeb) {
    context['platform'] = 'not-web';
    return context;
  }

  final navigator = web.window.navigator as JSObject;
  context['userAgent'] = _text(navigator['userAgent'], 160);
  context['cores'] = _text(navigator['hardwareConcurrency'], 8);
  context['deviceMemory'] = _text(navigator['deviceMemory'], 8);
  context['online'] = _text(navigator['onLine'], 8);
  context['opfs'] = '${await opfsAvailable()}';
  context['webgpuAdapter'] = '${await _hasWebGpuAdapter()}';

  final room = await readStorageRoom(0);
  if (room != null) {
    context['storageUsedBytes'] = '${room.usedBytes}';
    context['storageQuotaBytes'] = '${room.quotaBytes}';
  }
  return context;
}

String _text(JSAny? value, int limit) {
  final text = value?.dartify()?.toString() ?? '';
  return text.length <= limit ? text : text.substring(0, limit);
}

Future<bool> _hasWebGpuAdapter() async {
  try {
    final navigator = web.window.navigator as JSObject;
    final gpu = navigator['gpu'];
    if (gpu == null || gpu.isUndefinedOrNull) return false;
    final requestAdapter = (gpu as JSObject)['requestAdapter'];
    if (requestAdapter == null || requestAdapter.isUndefinedOrNull) {
      return false;
    }
    final pending = (requestAdapter as JSFunction).callAsFunction(gpu);
    final adapter = await (pending as JSPromise<JSAny?>).toDart;
    return adapter != null && !adapter.isUndefinedOrNull;
  } catch (_) {
    return false;
  }
}

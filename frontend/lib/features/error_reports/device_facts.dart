/// The device facts and browser capabilities every error report carries.
///
/// These answer "what was this person using when it broke": the browser,
/// the OS, and the exact APIs the on-device features depend on. Everything
/// is probed lazily and defensively — a probe must never throw its own
/// report.
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// The exception summary: type name plus the first line of its message.
Map<String, String> errorSummary(Object? error) {
  if (error == null) return const {'name': '', 'message': ''};
  return {
    'name': error.runtimeType.toString(),
    'message': error.toString().split('\n').first,
  };
}

/// Who is reporting: browser, platform, isolation. No identifiers.
Map<String, Object?> deviceFacts() {
  final navigator = web.window.navigator as JSObject;
  return {
    'ua': text(navigator.getProperty<JSAny?>('userAgent'.toJS), 300),
    'platform': text(navigator.getProperty<JSAny?>('platform'.toJS), 60),
    'language': text(navigator.getProperty<JSAny?>('language'.toJS), 20),
    'standalone': flag(navigator.getProperty<JSAny?>('standalone'.toJS)),
    'crossOriginIsolated': web.window.crossOriginIsolated,
  };
}

/// What the on-device features can use on this browser right now.
Map<String, Object?> capabilityFacts() {
  final navigator = web.window.navigator as JSObject;
  return {
    'webgpu': !isBlank(navigator.getProperty<JSAny?>('gpu'.toJS)),
    'cores': integer(navigator.getProperty<JSAny?>('hardwareConcurrency'.toJS)),
    'deviceMemoryGB': decimal(navigator.getProperty<JSAny?>('deviceMemory'.toJS)),
    'opfsGetDirectory': _storageHas('getDirectory'),
    'opfsEstimate': _storageHas('estimate'),
    'createWritable': _fileHandleFlag('createWritable'),
    'syncAccessHandle': _fileHandleFlag('createSyncAccessHandle'),
    'workerAvailable': !isBlank(web.window.getProperty('Worker'.toJS)),
    'webgl': _webglVersion(),
  };
}

/// A short id for one report or one install, safe to show a user.
String shortRandomId() {
  try {
    final crypto = web.window.getProperty<JSObject?>('crypto'.toJS);
    if (crypto != null && !crypto.isUndefinedOrNull) {
      final uuid = (crypto.getProperty<JSFunction>('randomUUID'.toJS))
          .callAsFunction(crypto) as JSString;
      return uuid.toDart.replaceAll('-', '').substring(0, 12);
    }
  } catch (_) {}
  return DateTime.now().microsecondsSinceEpoch.toRadixString(36);
}

bool _storageHas(String member) {
  final navigator = web.window.navigator as JSObject;
  final storage = navigator.getProperty<JSObject?>('storage'.toJS);
  if (storage == null || storage.isUndefinedOrNull) return false;
  return !isBlank(storage.getProperty<JSAny?>(member.toJS));
}

bool _fileHandleFlag(String member) {
  try {
    final ctor = web.window.getProperty<JSObject?>('FileSystemFileHandle'.toJS);
    if (ctor == null || ctor.isUndefinedOrNull) return false;
    final prototype = ctor.getProperty<JSObject?>('prototype'.toJS);
    if (prototype == null || prototype.isUndefinedOrNull) return false;
    return !isBlank(prototype.getProperty<JSAny?>(member.toJS));
  } catch (_) {
    return false;
  }
}

int _webglVersion() {
  try {
    final canvas = web.document.createElement('canvas');
    final context = canvas as JSObject;
    if (!isBlank(context.getProperty<JSAny?>('getContext'.toJS))) {
      final get2 = context.getProperty<JSFunction>('getContext'.toJS);
      if (!isBlank(get2.callAsFunction(context, 'webgl2'.toJS))) return 2;
      if (!isBlank(get2.callAsFunction(context, 'webgl'.toJS))) return 1;
    }
  } catch (_) {}
  return 0;
}

bool isBlank(JSAny? value) => value == null || value.isUndefinedOrNull;

String text(JSAny? value, int limit) {
  if (isBlank(value)) return '';
  final string = (value as JSString).toDart;
  return string.length <= limit ? string : string.substring(0, limit);
}

bool flag(JSAny? value) => !isBlank(value) && (value as JSBoolean).toDart;

int integer(JSAny? value) => isBlank(value) ? 0 : (value as JSNumber).toDartInt;

double decimal(JSAny? value) =>
    isBlank(value) ? 0 : (value as JSNumber).toDartDouble;

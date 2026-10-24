/// Guards OPFS model files against being mistaken for complete downloads.
///
/// The browser writes a streamed model straight into its final OPFS file and
/// the engine treats any existing file as a cached model. A download that dies
/// (full disk, closed tab, dropped connection) therefore leaves a half-written
/// file that is "installed" instantly and then cannot load. A small marker
/// written after a successful install proves the file is whole; anything else
/// is deleted and downloaded again.
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// True when this browser can actually *write* OPFS files.
///
/// `getDirectory()` alone is not enough: Safari and iOS 15–18 expose the
/// origin-private file system but not `createWritable()`, so a download
/// there failed on its very first chunk. The opfs_helper.js worker shim
/// covers those browsers with `createSyncAccessHandle()`, so the requirement
/// is "a directory handle AND (createWritable OR a worker-backed sync
/// access handle)".
Future<bool> opfsAvailable() async {
  final caps = await opfsWriteCapabilities();
  return caps?.usable ?? false;
}

/// What the browser says it can do with OPFS files, or null when it cannot
/// answer (non-web, no OPFS, or the helper script did not load).
Future<OpfsWriteCapabilities?> opfsWriteCapabilities() async {
  if (!kIsWeb) return null;
  try {
    await web.window.navigator.storage.getDirectory().toDart;
  } catch (_) {
    return null;
  }
  try {
    final helper = web.window.getProperty<JSObject?>('flutterGemmaOPFS'.toJS);
    if (helper == null || helper.isUndefinedOrNull) return null;
    final readCapabilities =
        helper.getProperty<JSFunction>('getWriteCapabilities'.toJS);
    final pending = readCapabilities.callAsFunction(helper);
    if (pending == null || pending.isUndefinedOrNull) return null;
    final raw = await (pending as JSPromise<JSAny?>).toDart;
    final map = raw as JSObject;
    return OpfsWriteCapabilities(
      createWritable: _flag(map, 'createWritable'),
      syncAccessHandle: _flag(map, 'syncAccessHandle'),
      workerAvailable: _flag(map, 'workerAvailable'),
    );
  } catch (_) {
    // The helper is newer than this call site knows: assume the classic
    // behaviour rather than disabling a download that might work.
    return const OpfsWriteCapabilities(
      createWritable: true,
      syncAccessHandle: false,
      workerAvailable: false,
    );
  }
}

/// The three booleans that decide whether a streamed download can be stored.
class OpfsWriteCapabilities {
  const OpfsWriteCapabilities({
    required this.createWritable,
    required this.syncAccessHandle,
    required this.workerAvailable,
  });

  /// The standard API. Present on Chrome 86+, Firefox 111+, Safari 26+.
  final bool createWritable;

  /// Worker-only API present on every OPFS browser, including iOS 15–18.
  final bool syncAccessHandle;

  /// Whether the shim can actually create the worker it needs.
  final bool workerAvailable;

  /// True when at least one write path is usable end to end.
  bool get usable => createWritable || (syncAccessHandle && workerAvailable);

  /// A short, printable reason a download cannot be stored, or null.
  String? get missingReason {
    if (usable) return null;
    if (!createWritable && !syncAccessHandle) {
      return 'this browser cannot write OPFS files (no createWritable, no '
          'createSyncAccessHandle)';
    }
    return 'this browser cannot write OPFS files (no createWritable and the '
        'sync-access worker is unavailable)';
  }
}

bool _flag(JSObject map, String key) {
  final value = map.getProperty<JSAny?>(key.toJS);
  return value != null &&
      !value.isUndefinedOrNull &&
      (value as JSBoolean).toDart;
}

/// An OPFS model file, and whether a marker proves it was fully written.
class CachedModel {
  const CachedModel({required this.bytes, required this.complete});

  final int bytes;
  final bool complete;
}

/// The state of [filename] on disk, or null when it is not there.
Future<CachedModel?> readCachedModel(String filename) async {
  if (!kIsWeb) return null;
  try {
    final directory = await web.window.navigator.storage.getDirectory().toDart;
    final file = await _read(directory, filename);
    if (file == null) return null;
    final bytes = file.size;
    final recorded = await _recorded(directory, _markerFor(filename));
    return CachedModel(bytes: bytes, complete: recorded == bytes);
  } catch (_) {
    return null;
  }
}

/// Deletes [filename] when it is not proven complete.
Future<void> discardIncompleteModel(String filename) async {
  if (!kIsWeb) return;
  try {
    final directory = await web.window.navigator.storage.getDirectory().toDart;
    final file = await _read(directory, filename);
    if (file == null) return;
    if (await _recorded(directory, _markerFor(filename)) == file.size) return;
    await _remove(directory, filename);
    await _remove(directory, _markerFor(filename));
  } catch (_) {
    // Best effort: an absent file is not an error.
  }
}

/// Records that [filename] was downloaded in full.
///
/// Written through opfs_helper.js so the Safari/iOS worker shim backs it
/// the same way it backs the model download itself.
Future<void> markModelComplete(String filename) async {
  if (!kIsWeb) return;
  try {
    final directory = await web.window.navigator.storage.getDirectory().toDart;
    final file = await _read(directory, filename);
    if (file == null) return;
    await _writeText(directory, _markerFor(filename), file.size.toString());
  } catch (_) {
    // A missing marker only costs one more download next launch.
  }
}

Future<void> _writeText(
  web.FileSystemDirectoryHandle directory,
  String name,
  String text,
) async {
  final helper = _helper();
  if (helper != null) {
    final write = helper.getProperty<JSAny?>('writeMarker'.toJS);
    if (write != null && !write.isUndefinedOrNull) {
      final writeFn = write as JSFunction;
      final pendingWrite = writeFn.callAsFunction(helper, name.toJS, text.toJS);
      if (pendingWrite != null) {
        await (pendingWrite as JSPromise<JSAny?>).toDart;
      }
      return;
    }
  }
  // Classic path: the helper predates the marker helper.
  final handle = await directory
      .getFileHandle(name, web.FileSystemGetFileOptions(create: true))
      .toDart;
  final stream = await handle.createWritable().toDart;
  await stream.write(text.toJS).toDart;
  await stream.close().toDart;
}

JSObject? _helper() {
  final value = web.window.getProperty<JSAny?>('flutterGemmaOPFS'.toJS);
  if (value == null || value.isUndefinedOrNull) return null;
  return value as JSObject;
}

String _markerFor(String filename) => '$filename.complete';

Future<web.File?> _read(
  web.FileSystemDirectoryHandle directory,
  String name,
) async {
  try {
    final handle = await directory.getFileHandle(name).toDart;
    return await handle.getFile().toDart;
  } catch (_) {
    return null; // NotFoundError: not cached.
  }
}

Future<int?> _recorded(
  web.FileSystemDirectoryHandle directory,
  String name,
) async {
  final file = await _read(directory, name);
  if (file == null) return null;
  return int.tryParse((await file.text().toDart).toDart);
}

Future<void> _remove(
  web.FileSystemDirectoryHandle directory,
  String name,
) async {
  try {
    await directory.removeEntry(name).toDart;
  } catch (_) {
    // Already gone.
  }
}

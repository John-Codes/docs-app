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

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// True when this browser provides the origin-private file system.
Future<bool> opfsAvailable() async {
  if (!kIsWeb) return false;
  try {
    await web.window.navigator.storage.getDirectory().toDart;
    return true;
  } catch (_) {
    return false;
  }
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
Future<void> markModelComplete(String filename) async {
  if (!kIsWeb) return;
  try {
    final directory = await web.window.navigator.storage.getDirectory().toDart;
    final file = await _read(directory, filename);
    if (file == null) return;
    final handle = await directory
        .getFileHandle(
          _markerFor(filename),
          web.FileSystemGetFileOptions(create: true),
        )
        .toDart;
    final stream = await handle.createWritable().toDart;
    await stream.write(file.size.toString().toJS).toDart;
    await stream.close().toDart;
  } catch (_) {
    // A missing marker only costs one more download next launch.
  }
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

/// Browsers refuse a model download when the bytes no longer fit, and the
/// refusal arrives only after the whole file has been fetched — the progress
/// bar sits at 99% and then the install fails. These helpers turn that into a
/// question that can be asked *before* starting, and into a message that says
/// what is actually wrong instead of blaming the connection.
library;

/// The Gemma 3 1B web build: 700,383,232 bytes, a little over 700 MB.
const answerModelBytes = 700 * 1024 * 1024;

/// The Gecko search model plus its tokeniser, roughly 115 MB.
const searchModelBytes = 115 * 1024 * 1024;

/// Slack for the PDF cache, the SQLite index and the browser's own overhead.
const storageHeadroomBytes = 128 * 1024 * 1024;

/// What the browser reports it may use, and what it is already using.
class StorageRoom {
  const StorageRoom({
    required this.quotaBytes,
    required this.usedBytes,
    required this.neededBytes,
  });

  final int quotaBytes;
  final int usedBytes;
  final int neededBytes;

  int get freeBytes {
    final free = quotaBytes - usedBytes;
    return free < 0 ? 0 : free;
  }

  bool get enough => freeBytes >= neededBytes;

  int get shortfallBytes {
    final short = neededBytes - freeBytes;
    return short < 0 ? 0 : short;
  }
}

/// The amount to reserve before installing [modelBytes], including the search
/// model when it is not installed yet and room for everything else.
int neededFor({required int modelBytes, required bool searchInstalled}) {
  final search = searchInstalled ? 0 : searchModelBytes;
  return modelBytes + search + storageHeadroomBytes;
}

/// True when a failure is the browser refusing to store the file, rather than
/// a problem that another try could fix. Retrying these just downloads the
/// whole model again for nothing.
bool isStorageFailure(Object failure) {
  final text = failure.toString().toLowerCase();
  return text.contains('quota') ||
      text.contains('no space') ||
      text.contains('out of memory') ||
      text.contains('allocation failed') ||
      text.contains('exceeded the quota');
}

/// The one sentence shown when a download cannot be stored.
String storageShortageMessage(StorageRoom room) {
  final free = _mb(room.freeBytes);
  final needed = _mb(room.neededBytes);
  return 'Not enough browser storage: this download needs about $needed MB '
      'free, but only $free MB is available. Free up disk space (or open the '
      'app in a fresh private window), then tap Retry.';
}

/// The sentence for a storage failure discovered mid-download, when the exact
/// numbers are no longer available.
String storageFailureMessage() {
  return 'This device ran out of browser storage while saving the model. '
      'Free up disk space (or open the app in a fresh private window), then '
      'tap Retry.';
}

/// Whole megabytes, the unit every download message uses.
int _mb(int bytes) => (bytes / (1024 * 1024)).round();

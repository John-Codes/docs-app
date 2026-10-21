/// The stages the chat passes through before it can answer anything.
///
/// Kept web-free on purpose: this is the whole decision about what the chat
/// says while the device is getting ready, and it belongs in a plain unit
/// test rather than only in a browser. Getting it wrong is easy and visible
/// — telling a downloading user to download, or hiding the notice while the
/// manual is still unreadable.
library;

/// The one stage worth showing, or null when the app can already answer.
ReadinessStage? readinessStage({
  required bool searchReady,
  required bool searchDownloading,
  required bool indexing,
}) {
  if (!searchReady) {
    return searchDownloading
        ? ReadinessStage.downloadingSearch
        : ReadinessStage.needsSearch;
  }
  // Search is up; the manual may still be turning into searchable passages,
  // which is the other wait a first question runs into.
  return indexing ? ReadinessStage.indexingManual : null;
}

/// What the chat is waiting on, if anything.
enum ReadinessStage {
  /// The search model is being downloaded right now.
  downloadingSearch,

  /// The search model is not installed and nothing is downloading it.
  needsSearch,

  /// Search works, but the bundled manual has not finished indexing.
  indexingManual,
}

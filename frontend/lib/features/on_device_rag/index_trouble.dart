/// Turns an on-device index failure into something a person can act on.
///
/// The vector store and the embedder fail for a handful of very different
/// reasons — another tab holding the database, a missing model, storage the
/// browser refuses — and raw exception text is a poor thing to show in the
/// chat or the library. Each known cause gets one clear sentence; anything
/// unknown keeps its technical text, so a bug report can carry it along.
library;

/// True when the database is held by another tab, another worker, or this
/// tab: the store refuses a second opener instead of queueing one.
bool isIndexBusy(Object failure) =>
    failure.toString().contains('is already open');

/// What to tell the user about [failure]: one sentence they can act on.
///
/// The technical text is kept as a tail so the message can be pasted into a
/// bug report, and so the busy case stays recognizable by [isIndexBusy]
/// wherever the string is stored. A failure that already explains itself —
/// a page that cannot be split without cutting a word — is passed through
/// untouched: wrapping it would bury the page number and the offending text.
String describeIndexFailure(Object failure) {
  final text = failure.toString().replaceFirst('Exception: ', '');
  if (text.contains('cannot be split without cutting it')) return text;
  if (isIndexBusy(failure)) {
    return 'Another tab of this app still has the documents open. Close the '
        'other Docs tab, then reload this one. ($text)';
  }
  if (text.contains('Web Locks API')) {
    return 'This browser will not store the documents here: the Web Locks '
        'API is missing. Open the app in a normal tab, not a private window '
        'with storage blocked.';
  }
  if (text.contains('search model is not installed')) {
    return 'The on-device search model is not installed. Download it from '
        'the badge at the top, then try again.';
  }
  return 'The on-device index could not run. Reload the page and try again. '
      '($text)';
}

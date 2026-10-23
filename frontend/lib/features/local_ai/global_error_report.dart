import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'client_report.dart';

/// Reports browser errors that escape the app's own try/catch blocks.
///
/// The engine runs async work outside Flutter's zones, so an install can die
/// before any caller sees the exception. Capped per session: a repeating
/// error must not turn into a repeating upload.
void installGlobalErrorReporting() {
  if (!kIsWeb) return;
  var reported = 0;

  void report(String event, JSAny? reason) {
    if (reported >= 5) return;
    reported++;
    reportClientEvent(event, _describe(reason));
  }

  web.window.addEventListener('unhandledrejection', ((web.Event event) {
    report('unhandled_rejection', (event as JSObject)['reason']);
  }).toJS);
  web.window.addEventListener('error', ((web.Event event) {
    final details = event as JSObject;
    report('uncaught_error', details['error'] ?? details['message']);
  }).toJS);
}

/// A JS error turned into something readable, without throwing itself.
String _describe(JSAny? value) {
  if (value == null || value.isUndefinedOrNull) return 'unknown error';
  try {
    final plain = value.dartify();
    if (plain != null) return plain.toString();
  } catch (_) {
    // Some host objects refuse to convert; fall through to a placeholder.
  }
  return 'unreadable browser error';
}

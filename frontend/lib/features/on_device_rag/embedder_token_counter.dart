import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:web/web.dart' as web;

/// The token count the Gecko embedder will actually see for a passage.
///
/// The runtime that embeds also tokenizes: `tokenizeLiteRtText` builds the
/// very id list (task prefix, BOS and EOS included) that embedding later
/// refuses when it is too long, so counting with it makes the passage
/// budget exact instead of a word-count guess.
///
/// Without the runtime (unit tests, before the model loads) a conservative
/// estimate stands in: passages come out smaller than they could, never too
/// long.
int countEmbedderTokens(String text) {
  final prefixed = '${TaskType.retrievalDocument.prefix}$text';
  final length = _tokenCount(prefixed);
  return length ?? _estimate(text);
}

/// The graph's input length, or a safe default before the model loads.
int embedderMaxInputTokens() {
  final max = _maxInputTokens();
  // Two tokens of headroom, so a passage can never land exactly on the
  // limit because of a tokenizer detail.
  return max == null || max < 8 ? 240 : max - 2;
}

int? _tokenCount(String prefixed) {
  try {
    final window = web.window as JSObject;
    final tokenize = window['tokenizeLiteRtText'];
    if (tokenize == null || tokenize.isUndefinedOrNull) return null;
    final ids = (tokenize as JSFunction).callAsFunction(window, prefixed.toJS);
    if (ids == null || ids.isUndefinedOrNull) return null;
    final length = (ids as JSObject)['length'];
    if (length == null || length.isUndefinedOrNull) return null;
    return (length as JSNumber).toDartInt;
  } catch (_) {
    return null;
  }
}

int? _maxInputTokens() {
  try {
    final window = web.window as JSObject;
    final max = window['getLiteRtEmbeddingMaxInputTokens'];
    if (max == null || max.isUndefinedOrNull) return null;
    final value = (max as JSFunction).callAsFunction(window);
    if (value == null || value.isUndefinedOrNull) return null;
    return (value as JSNumber).toDartInt;
  } catch (_) {
    return null;
  }
}

/// Technical prose ran about 1.8 tokens per word on the real manuals, so 2
/// is the safe ceiling; long unbroken runs cost roughly one token per three
/// characters. The task prefix ("title: none | text: ") is charged on top.
int _estimate(String text) {
  final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  final byWords = words * 2;
  final byChars = (text.length / 3).ceil();
  return (byWords > byChars ? byWords : byChars) + 12;
}

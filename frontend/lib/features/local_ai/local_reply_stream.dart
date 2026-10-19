import '../chat/chat_message.dart';
import '../chat/chat_source.dart';
import 'local_chat_bridge.dart';

/// Owns the streaming assistant bubble while the on-device model writes.
///
/// Adds a "thinking" message, grows it as tokens arrive — repainting at
/// most ~10 times a second so token flow never stutters the UI — then
/// finalizes it with its citations. If the turn has to fall back to the
/// cloud the partial bubble is removed, leaving the history clean.
class LocalReplyStream {
  LocalReplyStream(this._messages, this._notify);

  final List<ChatMessage> _messages;
  final void Function() _notify;

  DateTime _lastPaint = DateTime.fromMillisecondsSinceEpoch(0);
  String _pending = '';

  /// Adds the empty streaming bubble the tokens will land in.
  void start() {
    _messages.add(
      ChatMessage(
        text: '',
        isUser: false,
        timestamp: DateTime.now(),
        isLoading: true,
      ),
    );
    _notify();
  }

  /// Called for every generated token; repaints at most every 100 ms.
  void onToken(String token) {
    _pending += token;
    final now = DateTime.now();
    if (now.difference(_lastPaint) < _paintGap) return;
    _lastPaint = now;
    _paint();
  }

  /// Replaces the bubble with the authoritative answer and its citations.
  void finish(LocalAnswer answer) {
    _pending = answer.text;
    _paint(sources: answer.sources);
  }

  /// Removes the partial bubble before the cloud answer arrives.
  void discard() {
    if (_messages.isEmpty || !_messages.last.isLoading) return;
    _messages.removeLast();
    _notify();
  }

  void _paint({List<ChatSource> sources = const []}) {
    if (_messages.isEmpty || _messages.last.isUser) return;
    final current = _messages.last;
    final text = sources.isEmpty ? current.text + _pending : _pending;
    _pending = '';
    _messages[_messages.length - 1] = ChatMessage(
      text: text,
      isUser: false,
      timestamp: current.timestamp,
      sources: sources,
      isLoading: sources.isEmpty,
    );
    _notify();
  }
}

const _paintGap = Duration(milliseconds: 100);

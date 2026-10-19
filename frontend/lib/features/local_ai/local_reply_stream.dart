import '../chat/chat_message.dart';
import '../chat/chat_source.dart';
import 'local_chat_bridge.dart';
import 'typewriter_reveal.dart';

/// Owns the streaming assistant bubble while the on-device model writes.
///
/// Small tokens grow the bubble live (repainted at most ~10x/second). A
/// single batched chunk — what the MediaPipe web engine usually delivers —
/// is instead typed out at reading pace by [TypewriterReveal], so the user
/// always sees text flowing. If the turn falls back to the cloud the
/// partial bubble is removed, leaving the history clean.
class LocalReplyStream {
  LocalReplyStream(this._messages, this._notify);

  final List<ChatMessage> _messages;
  final void Function() _notify;

  DateTime _lastPaint = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _stamp = DateTime.fromMillisecondsSinceEpoch(0);
  int _slot = -1;
  String _pending = '';
  LocalAnswer? _finalAnswer;

  late final TypewriterReveal _typewriter =
      TypewriterReveal(_onRevealPiece, _onRevealDone);

  /// Adds the empty streaming bubble the tokens land in.
  void start() {
    _stamp = DateTime.now();
    _messages.add(
      ChatMessage(
        text: '',
        isUser: false,
        timestamp: _stamp,
        isLoading: true,
      ),
    );
    _slot = _messages.length - 1;
    _notify();
  }

  /// Called for every generated token.
  void onToken(String token) {
    final batched = token.length > _batchedChunk || _typewriter.isActive;
    if (batched) {
      _typewriter.add(token); // whole-sentence chunk: type it out.
      return;
    }
    _pending += token;
    final now = DateTime.now();
    if (now.difference(_lastPaint) < _paintGap) return;
    _lastPaint = now;
    _paint();
  }

  /// Replaces the bubble with the authoritative answer and its citations —
  /// once the typing has finished revealing it.
  void finish(LocalAnswer answer) {
    if (_typewriter.isActive) {
      _finalAnswer = answer; // painted when the reveal drains.
      return;
    }
    _pending = answer.text;
    _paint(sources: answer.sources);
  }

  /// Removes the partial bubble before the cloud answer arrives.
  void discard() {
    _typewriter.stop();
    if (_slot < 0 || _slot >= _messages.length) return;
    final bubble = _messages[_slot];
    if (bubble.timestamp != _stamp || !bubble.isLoading) return;
    _messages.removeAt(_slot);
    _notify();
  }

  void _onRevealPiece(String piece) {
    _pending += piece;
    _paint();
  }

  void _onRevealDone() {
    final answer = _finalAnswer;
    if (answer == null) return;
    _finalAnswer = null;
    _pending = answer.text;
    _paint(sources: answer.sources);
  }

  void _paint({List<ChatSource> sources = const []}) {
    if (_slot < 0 || _slot >= _messages.length) return;
    final current = _messages[_slot];
    if (current.timestamp != _stamp || !current.isLoading) return;
    final text = sources.isEmpty ? current.text + _pending : _pending;
    _pending = '';
    _messages[_slot] = ChatMessage(
      text: text,
      isUser: false,
      timestamp: _stamp,
      sources: sources,
      isLoading: sources.isEmpty,
    );
    _notify();
  }
}

const _paintGap = Duration(milliseconds: 100);
const _batchedChunk = 32; // chars: a real token is a few, a batch is many.

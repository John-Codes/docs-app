import 'dart:async';

/// Types out a large chunk of already-generated text at reading pace, so a
/// web engine that returns the whole answer in one piece still feels like
/// it streams. Small real-time tokens never come through here — this only
/// exists for the batched case.
class TypewriterReveal {
  TypewriterReveal(this._onPiece, this._onDone);

  final void Function(String piece) _onPiece;
  final void Function() _onDone;

  Timer? _timer;
  String _queue = '';
  int _step = 2;

  bool get isActive => _timer != null;

  void add(String text) {
    _queue += text;
    // Aim for roughly 70 ticks (~3 s) no matter how long the answer is,
    // but never paint less than 2 characters per tick.
    final wanted = _queue.length ~/ 70;
    if (wanted > _step) _step = wanted;
    _timer ??= Timer.periodic(_tick, (_) => _drain());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _queue = '';
  }

  void _drain() {
    if (_queue.length <= _step) {
      _timer?.cancel();
      _timer = null;
      if (_queue.isNotEmpty) _onPiece(_queue);
      _queue = '';
      _onDone();
      return;
    }
    _onPiece(_queue.substring(0, _step));
    _queue = _queue.substring(_step);
  }
}

const _tick = Duration(milliseconds: 40);

import 'dart:async';
import 'package:flutter/widgets.dart';

typedef JoystickMoveCallback = bool Function(Offset direction);

/// Reusable mobile movement control adapted from the supplied multiplayer ZIP.
/// Return false while disconnected so the current direction is retried.
/// Releasing always sends Offset.zero.
class VirtualJoystick extends StatefulWidget {
  const VirtualJoystick({
    super.key,
    required this.onMove,
    this.size = 120,
    this.sensitivity = 1,
    this.deadZone = 0.06,
    this.updateInterval = const Duration(milliseconds: 66),
    this.repeatInterval = const Duration(milliseconds: 500),
  })  : assert(size > 0),
        assert(sensitivity >= 0),
        assert(deadZone >= 0 && deadZone < 1);

  final JoystickMoveCallback onMove;
  final double size;
  final double sensitivity;
  final double deadZone;
  final Duration updateInterval;
  final Duration repeatInterval;

  @override
  State<VirtualJoystick> createState() => _VirtualJoystickState();
}

class _VirtualJoystickState extends State<VirtualJoystick> {
  Offset _value = Offset.zero;
  Offset _lastSent = Offset.zero;
  DateTime _lastSentAt = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.updateInterval, (_) => _flush());
  }

  @override
  void didUpdateWidget(covariant VirtualJoystick oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.updateInterval != widget.updateInterval) {
      _timer?.cancel();
      _timer = Timer.periodic(widget.updateInterval, (_) => _flush());
    }
  }

  void _flush() {
    final changed = (_value - _lastSent).distance > 0.04 ||
        (_value == Offset.zero && _lastSent != Offset.zero);
    final repeat = _value != Offset.zero &&
        DateTime.now().difference(_lastSentAt) >= widget.repeatInterval;
    if ((changed || repeat) && widget.onMove(_value)) {
      _lastSent = _value;
      _lastSentAt = DateTime.now();
    }
  }

  void _update(Offset localPosition) {
    final center = Offset(widget.size / 2, widget.size / 2);
    var direction = (localPosition - center) / (widget.size / 2);
    direction *= widget.sensitivity;
    if (direction.distance < widget.deadZone) {
      direction = Offset.zero;
    } else if (direction.distance > 1) {
      direction = direction / direction.distance;
    }
    setState(() => _value = direction);
  }

  void _release() {
    setState(() => _value = Offset.zero);
    _flush();
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_value != Offset.zero || _lastSent != Offset.zero) {
      widget.onMove(Offset.zero);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final knobOffset = _value * (widget.size * 0.32);
    return Semantics(
      label: 'عصا الحركة',
      hint: 'اسحب العصا لتوجيه البطل، واتركها لإيقاف الحركة',
      child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanDown: (details) => _update(details.localPosition),
      onPanUpdate: (details) => _update(details.localPosition),
      onPanEnd: (_) => _release(),
      onPanCancel: _release,
      child: SizedBox.square(
        dimension: widget.size,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: Color(0x55000000),
            shape: BoxShape.circle,
          ),
          child: Transform.translate(
            offset: knobOffset,
            child: Center(
              child: Container(
                width: widget.size * 0.4,
                height: widget.size * 0.4,
                decoration: const BoxDecoration(
                  color: Color(0xDDEEEEEE),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}

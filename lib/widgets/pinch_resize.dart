import 'package:flutter/widgets.dart';

/// İki parmakla yazı boyutunu büyütüp küçültme. Kaydırmayı engellemez:
/// dokunuşlar yalnızca dinlenir, iki parmak açılıp kapandıkça [onChanged] çağrılır.
class PinchResize extends StatefulWidget {
  const PinchResize({super.key, required this.size, required this.onChanged, required this.child,
      this.min = 16, this.max = 48});
  final double size, min, max;
  final ValueChanged<double> onChanged;
  final Widget child;

  @override
  State<PinchResize> createState() => _PinchResizeState();
}

class _PinchResizeState extends State<PinchResize> {
  final _pts = <int, Offset>{};
  double? _startDist, _startSize;

  double _dist() {
    final v = _pts.values.toList();
    return (v[0] - v[1]).distance;
  }

  void _maybeStart() {
    if (_pts.length == 2) {
      _startDist = _dist();
      _startSize = widget.size;
    } else {
      _startDist = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (e) {
        _pts[e.pointer] = e.position;
        _maybeStart();
      },
      onPointerMove: (e) {
        if (!_pts.containsKey(e.pointer)) return;
        _pts[e.pointer] = e.position;
        final d0 = _startDist, s0 = _startSize;
        if (_pts.length == 2 && d0 != null && s0 != null && d0 > 20) {
          final s = (s0 * _dist() / d0).clamp(widget.min, widget.max);
          if ((s - widget.size).abs() >= 0.5) widget.onChanged(s.roundToDouble());
        }
      },
      onPointerUp: (e) {
        _pts.remove(e.pointer);
        _maybeStart();
      },
      onPointerCancel: (e) {
        _pts.remove(e.pointer);
        _maybeStart();
      },
      child: widget.child,
    );
  }
}

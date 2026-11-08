import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Виртуальный стик: отдаёт нормализованный вектор (длина 0..1).
///
/// Работает через [Listener], поэтому левый и правый стик можно держать
/// одновременно двумя пальцами.
class VirtualStick extends StatefulWidget {
  const VirtualStick({
    super.key,
    required this.onChanged,
    this.onReleased,
    this.size = 132,
    this.color = Palette.accent,
    this.icon = Icons.control_camera_rounded,
    this.label,
    this.enabled = true,
  });

  final ValueChanged<Offset> onChanged;
  final VoidCallback? onReleased;
  final double size;
  final Color color;
  final IconData icon;
  final String? label;
  final bool enabled;

  @override
  State<VirtualStick> createState() => _VirtualStickState();
}

class _VirtualStickState extends State<VirtualStick> {
  Offset _drag = Offset.zero;
  int? _pointer;
  bool _active = false;

  void _apply(PointerEvent event) {
    if (!widget.enabled) return;
    final size = context.size;
    if (size == null || size.isEmpty) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.max(12.0, size.width / 2 - 12);
    var delta = event.localPosition - center;
    final distance = delta.distance;
    if (distance > radius) delta = delta / distance * radius;
    setState(() => _drag = delta);
    widget.onChanged(delta / radius);
  }

  void _begin(PointerDownEvent event) {
    if (!widget.enabled || _pointer != null) return;
    _pointer = event.pointer;
    _active = true;
    _apply(event);
  }

  void _move(PointerMoveEvent event) {
    if (event.pointer != _pointer) return;
    _apply(event);
  }

  void _end(PointerEvent event) {
    if (event.pointer != _pointer) return;
    _pointer = null;
    setState(() {
      _drag = Offset.zero;
      _active = false;
    });
    widget.onReleased?.call();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.enabled
        ? widget.color
        : widget.color.withValues(alpha: 0.35);
    final knobSize = widget.size * 0.36;
    return Semantics(
      label: widget.label ?? 'Виртуальный стик',
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _begin,
        onPointerMove: _move,
        onPointerUp: _end,
        onPointerCancel: _end,
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned.fill(
                child: CustomPaint(
                  painter: _StickRingPainter(
                    color: color,
                    active: _active,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.center,
                child: Icon(
                  widget.icon,
                  size: widget.size * 0.19,
                  color: color.withValues(alpha: _active ? 0.45 : 0.3),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 40),
                left: widget.size / 2 - knobSize / 2 + _drag.dx * 0.72,
                top: widget.size / 2 - knobSize / 2 + _drag.dy * 0.72,
                child: Container(
                  width: knobSize,
                  height: knobSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: <Color>[
                        color.withValues(alpha: _active ? 0.55 : 0.28),
                        color.withValues(alpha: _active ? 0.24 : 0.10),
                      ],
                    ),
                    border: Border.all(
                      color: color.withValues(alpha: _active ? 0.95 : 0.55),
                      width: 1.6,
                    ),
                    boxShadow: <BoxShadow>[
                      if (_active)
                        BoxShadow(
                          color: color.withValues(alpha: 0.4),
                          blurRadius: 18,
                        ),
                    ],
                  ),
                  child: Icon(
                    widget.icon,
                    size: knobSize * 0.46,
                    color: color.withValues(alpha: 0.95),
                  ),
                ),
              ),
              if (widget.label != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: -2,
                  child: Text(
                    widget.label!.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                      color: color.withValues(alpha: 0.75),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StickRingPainter extends CustomPainter {
  _StickRingPainter({required this.color, required this.active});

  final Color color;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    final fill = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          color.withValues(alpha: active ? 0.12 : 0.06),
          color.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, fill);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = active ? 2 : 1.4
        ..color = color.withValues(alpha: active ? 0.8 : 0.4),
    );
    canvas.drawCircle(
      center,
      radius * 0.58,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = color.withValues(alpha: 0.16),
    );

    final tick = Paint()
      ..strokeWidth = 1.3
      ..color = color.withValues(alpha: 0.38);
    for (var i = 0; i < 4; i++) {
      final a = i * math.pi / 2 + math.pi / 4;
      final p1 = center + Offset(math.cos(a), math.sin(a)) * (radius * 0.86);
      final p2 = center + Offset(math.cos(a), math.sin(a)) * radius;
      canvas.drawLine(p1, p2, tick);
    }
  }

  @override
  bool shouldRepaint(covariant _StickRingPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.active != active;
}

/// Круглая кнопка способности с индикатором перезарядки.
class AbilityButton extends StatelessWidget {
  const AbilityButton({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
    this.color = Palette.accent,
    this.size = 52,
    this.progress = 0,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final double size;
  final double progress;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final active = enabled && onPressed != null;
    final tint = active ? color : color.withValues(alpha: 0.35);
    return Semantics(
      button: true,
      label: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          GestureDetector(
            onTap: active ? onPressed : null,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0A111B).withValues(alpha: 0.82),
                border: Border.all(
                  color: tint.withValues(alpha: active ? 0.7 : 0.3),
                  width: 1.4,
                ),
                boxShadow: <BoxShadow>[
                  if (active)
                    BoxShadow(
                      color: color.withValues(alpha: 0.16),
                      blurRadius: 16,
                    ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  if (progress > 0.01)
                    SizedBox(
                      width: size - 6,
                      height: size - 6,
                      child: CircularProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        strokeWidth: 3,
                        color: color.withValues(alpha: 0.9),
                        backgroundColor:
                            color.withValues(alpha: 0.10),
                      ),
                    ),
                  Icon(icon, size: size * 0.44, color: tint),
                ],
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
              color: tint.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}

/// Кнопка, которую можно удерживать (огонь).
class HoldButton extends StatefulWidget {
  const HoldButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onDown,
    required this.onUp,
    this.color = Palette.magenta,
    this.size = 64,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onDown;
  final VoidCallback onUp;
  final Color color;
  final double size;
  final bool enabled;

  @override
  State<HoldButton> createState() => _HoldButtonState();
}

class _HoldButtonState extends State<HoldButton> {
  bool _down = false;

  void _press() {
    if (!widget.enabled) return;
    setState(() => _down = true);
    widget.onDown();
  }

  void _release() {
    if (!_down) return;
    setState(() => _down = false);
    widget.onUp();
  }

  @override
  Widget build(BuildContext context) {
    final color =
        widget.enabled ? widget.color : widget.color.withValues(alpha: 0.35);
    return Semantics(
      button: true,
      label: widget.label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (_) => _press(),
            onPointerUp: (_) => _release(),
            onPointerCancel: (_) => _release(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 90),
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: <Color>[
                    color.withValues(alpha: _down ? 0.75 : 0.35),
                    color.withValues(alpha: _down ? 0.35 : 0.12),
                  ],
                ),
                border: Border.all(
                  color: color.withValues(alpha: _down ? 1 : 0.65),
                  width: 1.6,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: color.withValues(alpha: _down ? 0.45 : 0.16),
                    blurRadius: _down ? 26 : 14,
                  ),
                ],
              ),
              child: Icon(
                widget.icon,
                size: widget.size * 0.46,
                color: Colors.white.withValues(alpha: _down ? 1 : 0.85),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            widget.label.toUpperCase(),
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
              color: color.withValues(alpha: 0.95),
            ),
          ),
        ],
      ),
    );
  }
}

/// Нижний слой сенсорного управления: стик движения, стик прицела,
/// огонь, рывок и перезарядка.
class TouchControlsLayer extends StatelessWidget {
  const TouchControlsLayer({
    super.key,
    required this.onMoveChanged,
    required this.onMoveReleased,
    required this.onAimChanged,
    required this.onAimReleased,
    required this.onFireDown,
    required this.onFireUp,
    required this.onDash,
    required this.onReload,
    required this.dashProgress,
    required this.reloadProgress,
    required this.reloading,
    this.enabled = true,
  });

  final ValueChanged<Offset> onMoveChanged;
  final VoidCallback onMoveReleased;
  final ValueChanged<Offset> onAimChanged;
  final VoidCallback onAimReleased;
  final VoidCallback onFireDown;
  final VoidCallback onFireUp;
  final VoidCallback onDash;
  final VoidCallback onReload;
  final double dashProgress;
  final double reloadProgress;
  final bool reloading;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final shortest = MediaQuery.sizeOf(context).shortestSide;
    final veryCompact = shortest < 440;
    final stick = veryCompact ? 104.0 : (shortest < 680 ? 120.0 : 138.0);
    final fire = veryCompact ? 54.0 : 64.0;
    final ability = veryCompact ? 44.0 : 52.0;
    final side = veryCompact ? 12.0 : 18.0;

    return SafeArea(
      minimum: EdgeInsets.only(bottom: side),
      child: Stack(
        children: <Widget>[
          Positioned(
            left: side,
            bottom: side,
            child: VirtualStick(
              size: stick,
              onChanged: onMoveChanged,
              onReleased: onMoveReleased,
              enabled: enabled,
              icon: Icons.open_with_rounded,
              label: 'Движение',
              color: Palette.accent,
            ),
          ),
          Positioned(
            right: side,
            bottom: side,
            child: VirtualStick(
              size: stick,
              onChanged: onAimChanged,
              onReleased: onAimReleased,
              enabled: enabled,
              icon: Icons.my_location_rounded,
              label: 'Прицел / огонь',
              color: Palette.magenta,
            ),
          ),
          Positioned(
            right: stick + side + 18,
            bottom: side + 8,
            child: HoldButton(
              icon: Icons.local_fire_department_rounded,
              label: 'Огонь',
              size: fire,
              onDown: onFireDown,
              onUp: onFireUp,
              enabled: enabled,
            ),
          ),
          Positioned(
            right: stick + side + 18,
            bottom: side + fire + 34,
            child: AbilityButton(
              icon: Icons.bolt_rounded,
              label: 'Рывок',
              size: ability,
              progress: dashProgress,
              onPressed: onDash,
              enabled: enabled,
              color: Palette.gold,
            ),
          ),
          Positioned(
            right: stick + side + ability + 34,
            bottom: side + fire + 34,
            child: AbilityButton(
              icon: Icons.autorenew_rounded,
              label: 'Перезарядка',
              size: ability,
              progress: reloading ? reloadProgress : 0,
              onPressed: onReload,
              enabled: enabled,
              color: Palette.accent,
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/theme.dart';

// ---------------------------------------------------------------------------
// Фон
// ---------------------------------------------------------------------------

class NeonBackground extends StatefulWidget {
  const NeonBackground({super.key, this.animate = true});

  final bool animate;

  @override
  State<NeonBackground> createState() => _NeonBackgroundState();
}

class _NeonBackgroundState extends State<NeonBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 26),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                painter: _BackgroundPainter(_controller.value),
                size: Size.infinite,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BackgroundPainter extends CustomPainter {
  _BackgroundPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final base = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[Color(0xFF070B13), Color(0xFF04060B), Color(0xFF080A10)],
      ).createShader(rect);
    canvas.drawRect(rect, base);

    // Сетка.
    final grid = Paint()
      ..color = const Color(0xFF16202E).withValues(alpha: 0.35)
      ..strokeWidth = 1;
    const step = 64.0;
    final shift = (t * step) % step;
    for (var x = -step + shift; x < size.width + step; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = -step + shift * 0.6; y < size.height + step; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // Свечения.
    void glow(Offset center, double radius, Color color, double strength) {
      final paint = Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            color.withValues(alpha: strength),
            color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, paint);
    }

    final w = size.width;
    final h = size.height;
    glow(
      Offset(w * (0.18 + 0.05 * math.sin(t * math.pi * 2)), h * 0.22),
      math.max(w, h) * 0.42,
      Palette.accent,
      0.10,
    );
    glow(
      Offset(w * (0.82 + 0.04 * math.cos(t * math.pi * 2)), h * 0.75),
      math.max(w, h) * 0.38,
      Palette.magenta,
      0.08,
    );

    // Пылинки.
    final dot = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 34; i++) {
      final seed = i * 12.9898;
      final x = (math.sin(seed) * 0.5 + 0.5) * w +
          math.sin(t * math.pi * 2 + i) * 26;
      final y = ((math.cos(seed * 1.7) * 0.5 + 0.5) * h -
          t * (12 + i % 7) * 2) %
          h;
      final alpha = 0.08 + 0.18 * ((math.sin(t * 6.28 + i * 1.3) + 1) / 2);
      dot.color = (i % 5 == 0 ? Palette.accent : Palette.muted)
          .withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), 1.2 + (i % 3) * 0.7, dot);
    }

    // Виньетка.
    final vignette = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          Colors.transparent,
          Colors.black.withValues(alpha: 0.55),
        ],
        stops: const <double>[0.55, 1],
      ).createShader(rect);
    canvas.drawRect(rect, vignette);
  }

  @override
  bool shouldRepaint(covariant _BackgroundPainter oldDelegate) =>
      oldDelegate.t != t;
}

// ---------------------------------------------------------------------------
// Логотип
// ---------------------------------------------------------------------------

class MazeLogo extends StatelessWidget {
  const MazeLogo({super.key, this.size = 92});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _LogoPainter()),
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size canvasSize) {
    final size = canvasSize.width;
    final rect = Offset.zero & canvasSize;
    final radius = size * 0.22;
    final rr = RRect.fromRectAndRadius(
      rect.deflate(size * 0.05),
      Radius.circular(radius),
    );
    final fill = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[Color(0xFF132335), Color(0xFF081019)],
      ).createShader(rect);
    canvas.drawRRect(rr, fill);
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size * 0.014
        ..color = Palette.accent.withValues(alpha: 0.55),
    );

    final wall = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.035
      ..strokeCap = StrokeCap.round
      ..color = Palette.accent.withValues(alpha: 0.85);

    final pad = size * 0.2;
    final s = size - pad * 2;
    final path = Path()
      ..moveTo(pad, pad + s * 0.1)
      ..lineTo(pad + s * 0.45, pad + s * 0.1)
      ..lineTo(pad + s * 0.45, pad + s * 0.45)
      ..moveTo(pad + s * 0.45, pad + s * 0.45)
      ..lineTo(pad + s * 0.15, pad + s * 0.45)
      ..lineTo(pad + s * 0.15, pad + s * 0.82)
      ..lineTo(pad + s * 0.7, pad + s * 0.82)
      ..moveTo(pad + s, pad)
      ..lineTo(pad + s, pad + s * 0.55)
      ..lineTo(pad + s * 0.62, pad + s * 0.55);
    canvas.drawPath(path, wall);

    final dotCenter = Offset(pad + s * 0.78, pad + s * 0.24);
    canvas.drawCircle(
      dotCenter,
      size * 0.09,
      Paint()
        ..color = Palette.gold.withValues(alpha: 0.25)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size * 0.05),
    );
    canvas.drawCircle(dotCenter, size * 0.045, Paint()..color = Palette.gold);

    // Прицел.
    final reticle = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.012
      ..color = Palette.magenta.withValues(alpha: 0.7);
    final center = Offset(size * 0.5, size * 0.52);
    canvas.drawCircle(center, size * 0.4, reticle);
    for (var i = 0; i < 4; i++) {
      final a = i * math.pi / 2;
      final p1 = center + Offset(math.cos(a), math.sin(a)) * size * 0.4;
      final p2 = center + Offset(math.cos(a), math.sin(a)) * size * 0.47;
      canvas.drawLine(p1, p2, reticle);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Панели и кнопки
// ---------------------------------------------------------------------------

class NeonPanel extends StatelessWidget {
  const NeonPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(22),
    this.borderColor,
    this.radius = 20,
    this.glow = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? borderColor;
  final double radius;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: Palette.panelGradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: borderColor ?? Palette.line.withValues(alpha: 0.9),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
          if (glow)
            BoxShadow(
              color: Palette.accent.withValues(alpha: 0.08),
              blurRadius: 40,
            ),
        ],
      ),
      child: child,
    );
  }
}

class NeonButton extends StatefulWidget {
  const NeonButton({
    super.key,
    required this.label,
    this.subtitle,
    this.icon,
    this.onPressed,
    this.primary = false,
    this.danger = false,
    this.busy = false,
    this.height = 58,
    this.expand = true,
    this.accent,
  });

  final String label;
  final String? subtitle;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool primary;
  final bool danger;
  final bool busy;
  final double height;
  final bool expand;
  final Color? accent;

  @override
  State<NeonButton> createState() => _NeonButtonState();
}

class _NeonButtonState extends State<NeonButton> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.busy;
    final accent = widget.accent ??
        (widget.danger ? Palette.danger : Palette.accent);
    final primary = widget.primary;

    final Color textColor;
    Gradient? gradient;
    Color fill = Colors.transparent;
    Color border = Palette.line;
    if (primary) {
      gradient = widget.danger
          ? const LinearGradient(
              colors: <Color>[Color(0xFFFF6A6E), Color(0xFFC62F55)],
            )
          : const LinearGradient(
              colors: <Color>[Color(0xFF3BE8C8), Color(0xFF37A9FF)],
            );
      textColor = const Color(0xFF031210);
    } else {
      fill = _hover ? const Color(0xFF162233) : Palette.surfaceAlt;
      border = _hover ? accent.withValues(alpha: 0.7) : Palette.line;
      textColor = widget.danger ? Palette.danger : Palette.text;
    }

    final content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (widget.busy)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: primary ? const Color(0xFF031210) : accent,
            ),
          )
        else if (widget.icon != null)
          Icon(widget.icon, size: 21, color: textColor),
        if (widget.icon != null || widget.busy) const SizedBox(width: 12),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                widget.label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: textColor,
                ),
              ),
              if (widget.subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    widget.subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: primary
                          ? const Color(0xFF031210).withValues(alpha: 0.65)
                          : Palette.muted,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (widget.expand && !widget.busy)
          Icon(Icons.arrow_forward_rounded,
              size: 18, color: textColor.withValues(alpha: 0.8)),
      ],
    );

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTap: enabled ? widget.onPressed : null,
        child: AnimatedScale(
          scale: _down ? 0.985 : (_hover && enabled ? 1.012 : 1),
          duration: const Duration(milliseconds: 120),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: widget.height,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              gradient: gradient,
              color: gradient == null ? fill : null,
              borderRadius: BorderRadius.circular(14),
              border: gradient == null ? Border.all(color: border) : null,
              boxShadow: <BoxShadow>[
                if (primary)
                  BoxShadow(
                    color: accent.withValues(alpha: enabled ? 0.35 : 0.1),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  )
                else if (_hover && enabled)
                  BoxShadow(
                    color: accent.withValues(alpha: 0.12),
                    blurRadius: 20,
                  ),
              ],
            ),
            child: Opacity(opacity: enabled ? 1 : 0.5, child: content),
          ),
        ),
      ),
    );
  }
}

class NeonIconButton extends StatelessWidget {
  const NeonIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 44,
    this.color,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Palette.surfaceAlt.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Palette.line),
          ),
          child: Icon(
            icon,
            size: size * 0.46,
            color: onPressed == null
                ? Palette.mutedDark
                : (color ?? Palette.text),
          ),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.text,
    this.color = Palette.accent,
    this.icon,
    this.small = false,
  });

  final String text;
  final Color color;
  final IconData? icon;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 8 : 11,
        vertical: small ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: small ? 11 : 13, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: small ? 10 : 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: Palette.accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 9),
        Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.8,
            color: Palette.muted,
          ),
        ),
        if (trailing != null) ...<Widget>[const Spacer(), trailing!],
      ],
    );
  }
}

class NeonField extends StatelessWidget {
  const NeonField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.maxLength = 16,
    this.onSubmitted,
    this.suffix,
    this.prefixIcon,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String? label;
  final String? hint;
  final int? maxLength;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;
  final IconData? prefixIcon;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (label != null) ...<Widget>[
          SectionLabel(label!),
          const SizedBox(height: 9),
        ],
        TextField(
          controller: controller,
          maxLength: maxLength,
          autofocus: autofocus,
          onSubmitted: onSubmitted,
          textInputAction: TextInputAction.done,
          style: const TextStyle(
            color: Palette.text,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
          decoration: InputDecoration(
            hintText: hint,
            counterText: '',
            prefixIcon:
                prefixIcon == null ? null : Icon(prefixIcon, size: 19),
            suffixIcon: suffix,
          ),
        ),
      ],
    );
  }
}

class SegmentedOptions extends StatelessWidget {
  const SegmentedOptions({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
    this.compact = false,
  });

  final List<String> options;
  final int selected;
  final ValueChanged<int>? onChanged;
  final bool enabled;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF080E17),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Palette.line),
      ),
      child: Row(
        children: <Widget>[
          for (var i = 0; i < options.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: enabled && onChanged != null ? () => onChanged!(i) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: EdgeInsets.symmetric(
                    vertical: compact ? 8 : 11,
                    horizontal: 4,
                  ),
                  decoration: BoxDecoration(
                    color: i == selected
                        ? Palette.accent.withValues(alpha: 0.14)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: i == selected
                          ? Palette.accent.withValues(alpha: 0.5)
                          : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    options[i],
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 10.5 : 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      color: !enabled
                          ? Palette.mutedDark
                          : (i == selected ? Palette.accent : Palette.muted),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class AddressChip extends StatelessWidget {
  const AddressChip({
    super.key,
    required this.label,
    required this.value,
    this.icon = Icons.wifi_tethering_rounded,
    this.copyable = true,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool copyable;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0A111B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Palette.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 15, color: Palette.accent),
          const SizedBox(width: 9),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: Palette.mutedDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: Palette.text,
                ),
              ),
            ],
          ),
          if (copyable) ...<Widget>[
            const SizedBox(width: 10),
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Скопировано'),
                    duration: Duration(milliseconds: 900),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.all(5),
                child: Icon(Icons.copy_rounded,
                    size: 15, color: Palette.muted),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

void showNeonSheet({
  required BuildContext context,
  required String title,
  required Widget child,
  double maxWidth = 620,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: Palette.panelGradient,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Palette.line),
              ),
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          title.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ),
                      NeonIconButton(
                        icon: Icons.close_rounded,
                        size: 34,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Flexible(child: SingleChildScrollView(child: child)),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

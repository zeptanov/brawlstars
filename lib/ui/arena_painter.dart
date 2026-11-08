import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../game/constants.dart';
import '../game/maze.dart';
import '../game/pickups.dart';
import '../game/weapons.dart';
import 'game_view_model.dart';

class ArenaPainter extends CustomPainter {
  ArenaPainter(this.vm) : super(repaint: vm.repaint);

  final GameViewModel vm;

  final Paint _fill = Paint();
  final Map<String, TextPainter> _textCache = <String, TextPainter>{};
  final Map<int, Paint> _weaponPaint = <int, Paint>{};

  static const Color _bg = Color(0xFF04060B);
  static const Color _floorDark = Color(0xFF0A1119);
  static const Color _wallDark = Color(0xFF151F2B);
  static const List<Color> _floors = <Color>[
    Color(0xFF121B26),
    Color(0xFF141E2A),
    Color(0xFF101823),
    Color(0xFF16212D),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, _fill..color = _bg);
    vm.ensureViewport(size);
    final maze = vm.maze;
    if (maze == null) return;

    final scale = vm.scale;
    final shakeOffset = vm.showShake
        ? Offset(
            math.sin(vm.time * 61) * vm.shake * 6,
            math.cos(vm.time * 73) * vm.shake * 5,
          )
        : Offset.zero;
    final center = Offset(size.width / 2, size.height / 2);

    canvas.save();
    canvas.translate(center.dx + shakeOffset.dx, center.dy + shakeOffset.dy);
    canvas.scale(scale);
    canvas.translate(-vm.camera.dx, -vm.camera.dy);

    final halfW = size.width / 2 / scale;
    final halfH = size.height / 2 / scale;
    final view = Rect.fromCenter(
      center: vm.camera,
      width: halfW * 2,
      height: halfH * 2,
    );
    final minX = math.max(0, (view.left / kTileSize).floor() - 1);
    final maxX =
        math.min(maze.size - 1, (view.right / kTileSize).ceil() + 1);
    final minY = math.max(0, (view.top / kTileSize).floor() - 1);
    final maxY =
        math.min(maze.size - 1, (view.bottom / kTileSize).ceil() + 1);

    final self = vm.myActor;
    final spectator = vm.spectator;
    final focus = vm.focusActor;
    final explored = vm.explored.length == maze.size * maze.size
        ? vm.explored
        : null;

    // Память карты вокруг уже увиденных мест.
    if (!spectator && explored != null) {
      _drawMemory(canvas, maze, explored, minX, maxX, minY, maxY);
    }

    if (vm.hostNoFog) {
      _drawTiles(canvas, maze, minX, maxX, minY, maxY);
      _drawZone(canvas, view);
      _drawPickups(canvas, view);
      _drawBullets(canvas, view);
      _drawPlayers(canvas, view);
      _drawEffects(canvas);
    } else if (spectator) {
      if (vm.observerFog && focus != null) {
        final vision = _buildVision(maze, focus.pos);
        canvas.save();
        canvas.clipPath(vision);
        _drawZone(canvas, view);
        _drawTiles(canvas, maze, minX, maxX, minY, maxY);
        _drawPickups(canvas, view);
        _drawBullets(canvas, view);
        _drawPlayers(canvas, view);
        _drawEffects(canvas);
        _drawFogEdge(canvas, focus.pos);
        canvas.restore();
      } else {
        _drawTiles(canvas, maze, minX, maxX, minY, maxY);
        _drawZone(canvas, view);
        _drawPickups(canvas, view);
        _drawBullets(canvas, view);
        _drawPlayers(canvas, view);
        _drawEffects(canvas);
      }
    } else if (self != null) {
      final vision = _buildVision(maze, self.pos);
      canvas.save();
      canvas.clipPath(vision);
      _drawZone(canvas, view);
      _drawTiles(canvas, maze, minX, maxX, minY, maxY);
      _drawPickups(canvas, view);
      _drawBullets(canvas, view);
      _drawPlayers(canvas, view);
      _drawEffects(canvas);
      _drawFogEdge(canvas, self.pos);
      canvas.restore();
    }

    _drawZoneRing(canvas);
    canvas.restore();

    _drawScreenEffects(canvas, size);
  }

  // -------------------------------------------------------------------------
  // Карта
  // -------------------------------------------------------------------------

  void _drawMemory(
    Canvas canvas,
    Maze maze,
    List<int> explored,
    int minX,
    int maxX,
    int minY,
    int maxY,
  ) {
    for (var ty = minY; ty <= maxY; ty++) {
      for (var tx = minX; tx <= maxX; tx++) {
        if (explored[ty * maze.size + tx] == 0) continue;
        final rect = Rect.fromLTWH(
          tx * kTileSize,
          ty * kTileSize,
          kTileSize,
          kTileSize,
        );
        if (maze.wallAt(tx, ty)) {
          canvas.drawRect(rect, _fill..color = _wallDark);
          canvas.drawRect(
            Rect.fromLTWH(rect.left, rect.top, rect.width, 3),
            _fill..color = const Color(0xFF1C2836),
          );
        } else {
          canvas.drawRect(rect, _fill..color = _floorDark);
          canvas.drawRect(
            Rect.fromLTWH(
              rect.left + 20,
              rect.top + 20,
              rect.width - 40,
              rect.height - 40,
            ),
            _fill..color = const Color(0xFF0C141D),
          );
        }
      }
    }
  }

  void _drawTiles(
    Canvas canvas,
    Maze maze,
    int minX,
    int maxX,
    int minY,
    int maxY,
  ) {
    final topPaint = Paint()..color = const Color(0xFF2F4056);
    final edgePaint = Paint()..color = const Color(0xFF0A1018);
    for (var ty = minY; ty <= maxY; ty++) {
      for (var tx = minX; tx <= maxX; tx++) {
        final rect = Rect.fromLTWH(
          tx * kTileSize,
          ty * kTileSize,
          kTileSize,
          kTileSize,
        );
        if (maze.wallAt(tx, ty)) {
          canvas.drawRect(rect, _fill..color = const Color(0xFF222E3D));
          canvas.drawRect(
            Rect.fromLTWH(rect.left, rect.top, rect.width, 5),
            topPaint,
          );
          canvas.drawRect(
            Rect.fromLTWH(rect.left, rect.bottom - 4, rect.width, 4),
            edgePaint,
          );
        } else {
          final hash = (tx * 73856093 ^ ty * 19349663) & 3;
          canvas.drawRect(rect, _fill..color = _floors[hash]);
        }
      }
    }
  }

  Path _buildVision(Maze maze, Offset from) {
    final rays = vm.rayCount;
    final distances = List<double>.filled(rays, kVisionRadius);
    for (var i = 0; i < rays; i++) {
      final angle = i * math.pi * 2 / rays;
      distances[i] = math.min(
        kVisionRadius,
        maze.raycast(from.dx, from.dy, angle, kVisionRadius) - 1.5,
      );
    }
    // Лёгкое сглаживание краёв.
    final smoothed = List<double>.filled(rays, 0);
    for (var i = 0; i < rays; i++) {
      final a = distances[(i - 1 + rays) % rays];
      final b = distances[i];
      final c = distances[(i + 1) % rays];
      smoothed[i] = (a + b * 2 + c) / 4;
    }
    final path = Path();
    for (var i = 0; i < rays; i++) {
      final angle = i * math.pi * 2 / rays;
      final r = math.max(8.0, smoothed[i]);
      final p = from + Offset(math.cos(angle) * r, math.sin(angle) * r);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    return path;
  }

  void _drawFogEdge(Canvas canvas, Offset from) {
    final shader = ui.Gradient.radial(
      from,
      kVisionRadius * 1.02,
      <Color>[
        _bg.withValues(alpha: 0),
        _bg.withValues(alpha: 0.12),
        _bg.withValues(alpha: 0.94),
      ],
      <double>[0, 0.7, 1],
    );
    canvas.drawCircle(
      from,
      kVisionRadius * 1.02,
      Paint()..shader = shader,
    );
  }

  // -------------------------------------------------------------------------
  // Зона
  // -------------------------------------------------------------------------

  void _drawZone(Canvas canvas, Rect view) {
    final zone = vm.zone;
    final zonePath = Path()
      ..addOval(Rect.fromCircle(
        center: Offset(zone.x, zone.y),
        radius: zone.radius,
      ));
    final viewPath = Path()..addRect(view);
    final outside =
        Path.combine(PathOperation.difference, viewPath, zonePath);
    canvas.drawPath(
      outside,
      Paint()..color = Palette.danger.withValues(alpha: 0.055),
    );
  }

  void _drawZoneRing(Canvas canvas) {
    final zone = vm.zone;
    final center = Offset(zone.x, zone.y);
    if (zone.radius <= 1) return;
    final rect = Rect.fromCircle(center: center, radius: zone.radius);
    canvas.drawCircle(
      center,
      zone.radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..color = Palette.danger
            .withValues(alpha: vm.zoneShrinking ? 0.18 : 0.10),
    );
    final segments = 84;
    final dash = math.pi * 2 / segments;
    final phase = (vm.time * 18).floor() % segments;
    for (var i = 0; i < segments; i++) {
      if ((i + phase) % 3 == 0) continue;
      canvas.drawArc(
        rect,
        i * dash,
        dash * 0.62,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..color = Palette.danger.withValues(alpha: 0.72),
      );
    }
    // Метки-«шипы» на кольце.
    for (var i = 0; i < 4; i++) {
      final a = vm.time * 0.12 + i * math.pi / 2;
      final p1 = center +
          Offset(math.cos(a), math.sin(a)) * (zone.radius - 14);
      final p2 = center +
          Offset(math.cos(a), math.sin(a)) * (zone.radius + 14);
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = Palette.danger.withValues(alpha: 0.55)
          ..strokeWidth = 2,
      );
    }
  }

  // -------------------------------------------------------------------------
  // Объекты
  // -------------------------------------------------------------------------

  void _drawPickups(Canvas canvas, Rect view) {
    for (final pickup in vm.pickups) {
      if (!view.inflate(40).contains(pickup.pos)) continue;
      final def = pickupByIndex(pickup.type);
      final color = Color(def.color);
      final pulse = 0.5 + 0.5 * math.sin(vm.time * 3 + pickup.id);
      final glowPaint = Paint()
        ..shader = ui.Gradient.radial(
          pickup.pos,
          30 + pulse * 6,
          <Color>[
            color.withValues(alpha: 0.28),
            color.withValues(alpha: 0),
          ],
        );
      canvas.drawCircle(pickup.pos, 34 + pulse * 6, glowPaint);

      canvas.save();
      canvas.translate(pickup.pos.dx, pickup.pos.dy);
      canvas.rotate(vm.time * 0.7 + pickup.id);
      final side = 13.0 + pulse * 1.5;
      final diamond = Path()
        ..moveTo(0, -side)
        ..lineTo(side, 0)
        ..lineTo(0, side)
        ..lineTo(-side, 0)
        ..close();
      canvas.drawPath(
        diamond,
        Paint()..color = color.withValues(alpha: 0.18),
      );
      canvas.drawPath(
        diamond,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = color.withValues(alpha: 0.9),
      );
      canvas.restore();

      final label = _text(
        def.glyph,
        color,
        size: 13,
        bold: true,
      );
      label.paint(
        canvas,
        pickup.pos - Offset(label.width / 2, label.height / 2),
      );
    }
  }

  void _drawBullets(Canvas canvas, Rect view) {
    for (final bullet in vm.bullets) {
      if (!view.inflate(80).contains(bullet.pos)) continue;
      final def = weaponByIndex(bullet.weapon);
      final color = Color(def.color);
      final tail = bullet.pos - bullet.velocity * 0.028;
      final paint = _weaponPaint.putIfAbsent(
        def.color,
        () => Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 2.4
          ..color = color,
      );
      canvas.drawLine(
        tail,
        bullet.pos,
        Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 6
          ..color = color.withValues(alpha: 0.18),
      );
      canvas.drawLine(tail, bullet.pos, paint);
      canvas.drawCircle(
        bullet.pos,
        2.6,
        Paint()..color = Colors.white.withValues(alpha: 0.9),
      );
    }
  }

  void _drawPlayers(Canvas canvas, Rect view) {
    final myTeam = vm.myActor?.team ?? vm.focusActor?.team ?? -1;
    for (final actor in vm.actors.values) {
      if (!actor.alive) continue;
      if (!view.inflate(90).contains(actor.pos)) continue;
      final isSelf = actor.isSelf;
      final ally = !isSelf && myTeam >= 0 && actor.team == myTeam;
      final color = isSelf
          ? Palette.accent
          : (ally ? const Color(0xFF7FB2FF) : const Color(0xFFFF5C7A));
      final ghost = actor.ghostTime > 0;
      final opacity = ghost ? 0.34 : 1.0;
      final pos = actor.pos;

      canvas.drawOval(
        Rect.fromCenter(
          center: pos + const Offset(3, 7),
          width: 30,
          height: 15,
        ),
        Paint()..color = Colors.black.withValues(alpha: 0.4 * opacity),
      );

      canvas.drawCircle(
        pos,
        28,
        Paint()
          ..shader = ui.Gradient.radial(
            pos,
            30,
            <Color>[
              color.withValues(alpha: 0.22 * opacity),
              color.withValues(alpha: 0),
            ],
          ),
      );

      final dir = Offset(math.cos(actor.aim), math.sin(actor.aim));
      final barrelStart = pos + dir * 6;
      final barrelEnd = pos + dir * 26;
      canvas.drawLine(
        barrelStart,
        barrelEnd,
        Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 6
          ..color = color.withValues(alpha: 0.35 * opacity),
      );
      canvas.drawLine(
        barrelStart,
        barrelEnd,
        Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 3
          ..color = color.withValues(alpha: 0.9 * opacity),
      );

      canvas.drawCircle(
        pos,
        kPlayerRadius,
        Paint()..color = const Color(0xFF0A121B).withValues(alpha: opacity),
      );
      canvas.drawCircle(
        pos,
        kPlayerRadius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..color = color.withValues(alpha: opacity),
      );
      canvas.drawCircle(
        pos + dir * 3,
        4.2,
        Paint()..color = color.withValues(alpha: 0.9 * opacity),
      );

      if (isSelf) {
        final dash = math.pi * 2 / 12;
        final phase = (vm.time * 40).floor() % 12;
        for (var i = 0; i < 12; i++) {
          if ((i + phase) % 2 == 0) continue;
          canvas.drawArc(
            Rect.fromCircle(center: pos, radius: 23),
            i * dash,
            dash * 0.7,
            false,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.4
              ..color = Palette.accent.withValues(alpha: 0.55),
          );
        }
        canvas.drawLine(
          pos + dir * 30,
          pos + dir * (30 + 62 * (actor.speedTime > 0 ? 1.15 : 1)),
          Paint()
            ..strokeCap = StrokeCap.round
            ..strokeWidth = 1.2
            ..color = Palette.accent.withValues(alpha: 0.18),
        );
      }

      if (actor.speedTime > 0) {
        canvas.drawCircle(
          pos,
          kPlayerRadius + 5,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = Palette.gold.withValues(alpha: 0.5),
        );
      }

      if (vm.spectator && actor.id == vm.spectateTargetId) {
        canvas.drawCircle(
          pos,
          kPlayerRadius + 9,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = const Color(0xFFBFD8FF).withValues(alpha: 0.8),
        );
      }

      final labelColor = isSelf
          ? Palette.accent
          : (ally ? const Color(0xFFB9D6FF) : const Color(0xFFFFC2CE));
      final name = _text(
        isSelf ? 'ТЫ' : actor.name,
        labelColor,
        size: 10.5,
        bold: true,
      );
      name.paint(
        canvas,
        pos - Offset(name.width / 2, 47 + name.height / 2 - 14),
      );

      if (!isSelf || actor.hp < kMaxHp) {
        final barWidth = 42.0;
        final barTop = pos.dy - 36;
        final barLeft = pos.dx - barWidth / 2;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(barLeft, barTop, barWidth, 4.5),
            const Radius.circular(2),
          ),
          Paint()..color = Colors.black.withValues(alpha: 0.55),
        );
        final hpRatio = (actor.hp / kMaxHp).clamp(0.0, 1.0);
        final hpColor = hpRatio > 0.55
            ? const Color(0xFF64F5A4)
            : (hpRatio > 0.25 ? Palette.gold : Palette.danger);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(barLeft, barTop, barWidth * hpRatio, 4.5),
            const Radius.circular(2),
          ),
          Paint()..color = hpColor,
        );
        if (actor.shield > 0) {
          final shieldRatio =
              (actor.shield / kMaxShield).clamp(0.0, 1.0);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(
                barLeft,
                barTop - 4,
                barWidth * shieldRatio,
                2.4,
              ),
              const Radius.circular(1),
            ),
            Paint()..color = const Color(0xFF7FB2FF),
          );
        }
      }
    }
  }

  void _drawEffects(Canvas canvas) {
    for (final effect in vm.effects) {
      final t = 1 - (effect.life / effect.maxLife).clamp(0.0, 1.0);
      final alpha = (1 - t).clamp(0.0, 1.0);
      final radius = effect.size * (0.4 + t * 1.8);
      if (effect.ring) {
        canvas.drawCircle(
          effect.pos,
          radius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2 * (1 - t) + 0.6
            ..color = effect.color.withValues(alpha: alpha * 0.9),
        );
      }
      canvas.drawCircle(
        effect.pos,
        effect.size * 0.35 * (1 - t),
        Paint()..color = effect.color.withValues(alpha: alpha * 0.55),
      );
    }
  }

  // -------------------------------------------------------------------------
  // Экранные эффекты
  // -------------------------------------------------------------------------

  void _drawScreenEffects(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final vignette = Paint()
      ..shader = ui.Gradient.radial(
        rect.center,
        math.max(size.width, size.height) * 0.72,
        <Color>[
          Colors.transparent,
          Colors.black.withValues(alpha: 0.45),
        ],
        <double>[0.55, 1],
      );
    canvas.drawRect(rect, vignette);

    final self = vm.myActor;
    if (self != null && !vm.spectator) {
      final lowHp = (1 - self.hp / 40).clamp(0.0, 1.0);
      if (lowHp > 0) {
        final pulse = 0.6 + 0.4 * math.sin(vm.time * 6);
        final shader = ui.Gradient.radial(
          rect.center,
          math.max(size.width, size.height) * 0.66,
          <Color>[
            Colors.transparent,
            Palette.danger.withValues(alpha: 0.34 * lowHp * pulse),
          ],
          <double>[0.5, 1],
        );
        canvas.drawRect(rect, Paint()..shader = shader);
      }
      if (vm.outsideZone) {
        final pulse = 0.65 + 0.35 * math.sin(vm.time * 4);
        final shader = ui.Gradient.radial(
          rect.center,
          math.max(size.width, size.height) * 0.7,
          <Color>[
            Colors.transparent,
            Palette.danger.withValues(alpha: 0.30 * pulse),
          ],
          <double>[0.45, 1],
        );
        canvas.drawRect(rect, Paint()..shader = shader);
      }
    }

    if (vm.spectator) {
      canvas.drawRect(
        rect,
        Paint()..color = const Color(0xFF4A6CFF).withValues(alpha: 0.05),
      );
    }
  }

  TextPainter _text(
    String text,
    Color color, {
    double size = 11,
    bool bold = false,
  }) {
    final key =
        '$text|${color.toARGB32()}|${size.toStringAsFixed(1)}|$bold';
    final cached = _textCache[key];
    if (cached != null) return cached;
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          letterSpacing: 0.2,
          shadows: const <Shadow>[
            Shadow(color: Colors.black87, blurRadius: 3),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    if (_textCache.length > 220) _textCache.clear();
    _textCache[key] = painter;
    return painter;
  }

  @override
  bool shouldRepaint(covariant ArenaPainter oldDelegate) => false;
}

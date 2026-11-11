import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../game/constants.dart';
import '../game/weapons.dart';
import '../net/messages.dart';
import 'game_view_model.dart';
import 'widgets.dart';

// ---------------------------------------------------------------------------
// Данные для HUD
// ---------------------------------------------------------------------------

class KillFeedEntry {
  const KillFeedEntry({
    required this.killerId,
    required this.victimId,
    required this.killer,
    required this.victim,
    required this.weapon,
    required this.createdAt,
  });

  final int killerId;
  final int victimId;
  final String killer;
  final String victim;
  final int weapon;
  final double createdAt;
}

class HudBanner {
  const HudBanner({
    required this.text,
    required this.color,
    required this.icon,
    required this.createdAt,
    this.detail,
    this.duration = 3.0,
  });

  final String text;
  final String? detail;
  final Color color;
  final IconData icon;
  final double createdAt;
  final double duration;
}

class DamageMark {
  const DamageMark({
    required this.angle,
    required this.amount,
    required this.createdAt,
  });

  final double angle;
  final double amount;
  final double createdAt;
}

// ---------------------------------------------------------------------------
// HUD
// ---------------------------------------------------------------------------

class GameHud extends StatelessWidget {
  const GameHud({
    super.key,
    required this.vm,
    required this.snapshot,
    required this.myId,
    required this.ping,
    required this.fps,
    required this.killfeed,
    required this.banners,
    required this.touchControls,
    required this.scoreboardVisible,
    required this.onPause,
    required this.onToggleScoreboard,
    required this.onToggleControls,
    this.compact = false,
  });

  final GameViewModel vm;
  final Snapshot? snapshot;
  final int myId;
  final int ping;
  final int fps;
  final List<KillFeedEntry> killfeed;
  final List<HudBanner> banners;
  final bool touchControls;
  final bool scoreboardVisible;
  final VoidCallback onPause;
  final VoidCallback onToggleScoreboard;
  final VoidCallback onToggleControls;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final me = vm.myActor;
    final bottom = touchControls ? 160.0 : 12.0;
    final radarSize = compact ? 78.0 : 94.0;
    return SafeArea(
      child: Stack(
        children: <Widget>[
          Positioned(
            left: 10,
            right: 10,
            top: 8,
            child: Row(
              children: <Widget>[
                if (!compact) _ZoneBadge(vm: vm, onTap: onToggleScoreboard),
                const Spacer(),
                _MatchBar(vm: vm, compact: compact),
                const Spacer(),
                _TopButtons(
                  size: compact ? 38 : 42,
                  scoreboardVisible: scoreboardVisible,
                  touchControls: touchControls,
                  onPause: onPause,
                  onScoreboard: onToggleScoreboard,
                  onToggleControls: onToggleControls,
                ),
              ],
            ),
          ),
          Positioned(
            right: 12,
            top: (compact ? 54 : 58),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                _RadarCard(
                  vm: vm,
                  snapshot: snapshot,
                  size: radarSize,
                  ping: ping,
                  fps: fps,
                  showStats: !compact || touchControls,
                ),
                const SizedBox(height: 8),
                if (killfeed.isNotEmpty)
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: compact ? 210 : 270),
                    child: _KillFeed(
                      entries: killfeed,
                      myId: myId,
                      now: vm.time,
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            left: 12,
            bottom: bottom,
            child: _VitalsCard(vm: vm, compact: compact),
          ),
          Positioned(
            right: 12,
            bottom: bottom,
            child: _WeaponCard(vm: vm, compact: compact),
          ),
          if (me != null && vm.outsideZone && !vm.spectator)
            Positioned(
              left: 0,
              right: 0,
              bottom: bottom + (compact ? 118 : 132),
              child: const Center(
                child: _DangerPill(
                  text: 'ВНЕ ЗОНЫ · УРОН',
                  icon: Icons.warning_amber_rounded,
                ),
              ),
            ),
          if (banners.isNotEmpty)
            Positioned(
              left: 12,
              right: 12,
              top: compact ? 58 : 66,
              child: IgnorePointer(
                child: Column(
                  children: <Widget>[
                    for (final banner in banners.take(2))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _BannerView(banner: banner, now: vm.time),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ZoneBadge extends StatelessWidget {
  const _ZoneBadge({required this.vm, required this.onTap});

  final GameViewModel vm;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shrinking = vm.zoneShrinking;
    final color = shrinking ? Palette.danger : Palette.muted;
    return GestureDetector(
      onTap: onTap,
      child: _Glass(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.radar_rounded, size: 15, color: color),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'ЗОНА · ЭТАП ${vm.zoneStage + 1}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: color,
                  ),
                ),
                Text(
                  shrinking
                      ? 'СУЖАЕТСЯ'
                      : 'до сужения ${_shortTime(vm.nextZoneIn)}',
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: Palette.mutedDark,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchBar extends StatelessWidget {
  const _MatchBar({required this.vm, required this.compact});

  final GameViewModel vm;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final alive = vm.snapshot?.alivePlayers ?? 0;
    final total = vm.snapshot?.totalPlayers ?? 0;
    final color = vm.zoneShrinking ? Palette.danger : Palette.accent;
    return _Glass(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 11 : 15,
        vertical: compact ? 7 : 8,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.people_alt_rounded, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            '$alive',
            style: TextStyle(
              fontSize: compact ? 15 : 17,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          Text(
            '/$total',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Palette.mutedDark,
            ),
          ),
          Container(
            width: 1,
            height: 16,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            color: Palette.line,
          ),
          Icon(Icons.timer_outlined, size: 15, color: Palette.muted),
          const SizedBox(width: 6),
          Text(
            _clock(vm.matchTime),
            style: TextStyle(
              fontSize: compact ? 13 : 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
          if (compact) ...<Widget>[
            const SizedBox(width: 9),
            Icon(
              vm.zoneShrinking
                  ? Icons.warning_amber_rounded
                  : Icons.zoom_out_map_rounded,
              size: 14,
              color: vm.zoneShrinking ? Palette.danger : Palette.muted,
            ),
          ],
        ],
      ),
    );
  }
}

class _TopButtons extends StatelessWidget {
  const _TopButtons({
    required this.size,
    required this.scoreboardVisible,
    required this.touchControls,
    required this.onPause,
    required this.onScoreboard,
    required this.onToggleControls,
  });

  final double size;
  final bool scoreboardVisible;
  final bool touchControls;
  final VoidCallback onPause;
  final VoidCallback onScoreboard;
  final VoidCallback onToggleControls;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _HudIcon(
          icon: Icons.view_headline_rounded,
          size: size,
          tooltip: 'Таблица (Tab)',
          active: scoreboardVisible,
          onPressed: onScoreboard,
        ),
        const SizedBox(width: 6),
        _HudIcon(
          icon: touchControls ? Icons.keyboard_rounded : Icons.gamepad_rounded,
          size: size,
          tooltip: 'Сменить управление',
          onPressed: onToggleControls,
        ),
        const SizedBox(width: 6),
        _HudIcon(
          icon: Icons.pause_rounded,
          size: size,
          tooltip: 'Пауза (Esc)',
          onPressed: onPause,
        ),
      ],
    );
  }
}

class _HudIcon extends StatelessWidget {
  const _HudIcon({
    required this.icon,
    required this.size,
    required this.onPressed,
    this.tooltip,
    this.active = false,
  });

  final IconData icon;
  final double size;
  final VoidCallback onPressed;
  final String? tooltip;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final button = GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: active
              ? Palette.accent.withValues(alpha: 0.18)
              : Palette.surfaceAlt.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: active ? Palette.accent : Palette.line),
        ),
        child: Icon(
          icon,
          size: size * 0.48,
          color: active ? Palette.accent : Palette.text,
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

class _RadarCard extends StatelessWidget {
  const _RadarCard({
    required this.vm,
    required this.snapshot,
    required this.size,
    required this.ping,
    required this.fps,
    required this.showStats,
  });

  final GameViewModel vm;
  final Snapshot? snapshot;
  final double size;
  final int ping;
  final int fps;
  final bool showStats;

  @override
  Widget build(BuildContext context) {
    return _Glass(
      padding: const EdgeInsets.all(7),
      child: Column(
        children: <Widget>[
          SizedBox(
            width: size,
            height: size,
            child: CustomPaint(painter: _RadarPainter(vm)),
          ),
          if (showStats)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.speed_rounded,
                    size: 10,
                    color: fps >= 48 ? Palette.accent : Palette.gold,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '$fps',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Palette.muted,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Icon(
                    Icons.wifi_rounded,
                    size: 10,
                    color: ping < 80 ? Palette.accent : Palette.gold,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '$ping',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Palette.muted,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter(this.vm) : super(repaint: vm.repaint);

  final GameViewModel vm;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1;
    final bg = Paint()
      ..shader = ui.Gradient.radial(center, radius, <Color>[
        const Color(0xFF071420),
        const Color(0xFF040A10),
      ]);
    canvas.drawCircle(center, radius, bg);
    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
    );

    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = Palette.accent.withValues(alpha: 0.10);
    canvas.drawCircle(center, radius * 0.5, grid);
    canvas.drawCircle(center, radius, grid);
    canvas.drawLine(
      Offset(center.dx, center.dy - radius),
      Offset(center.dx, center.dy + radius),
      grid,
    );
    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx + radius, center.dy),
      grid,
    );

    final me = vm.myActor;
    final range = 1650.0;
    final scale = radius / range;
    final zone = vm.zone;
    if (me != null) {
      final zoneCenter =
          center +
          Offset((zone.x - me.pos.dx) * scale, (zone.y - me.pos.dy) * scale);
      final zonePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = vm.zoneShrinking ? 2.2 : 1.4
        ..color = Palette.danger.withValues(alpha: 0.7);
      canvas.drawCircle(zoneCenter, zone.radius * scale, zonePaint);
      if (!vm.spectator && !zone.contains(me.pos.dx, me.pos.dy)) {
        canvas.drawCircle(
          center,
          radius,
          Paint()..color = Palette.danger.withValues(alpha: 0.14),
        );
      }
    }

    final ping = vm.snapshot?.radar;
    if (ping != null && me != null) {
      final d = math.min(ping.distance * scale, radius * 0.94);
      final p = center + Offset(math.cos(ping.angle), math.sin(ping.angle)) * d;
      final pulse = 0.55 + 0.45 * math.sin(vm.time * 6);
      canvas.drawCircle(
        p,
        10,
        Paint()
          ..shader = ui.Gradient.radial(p, 10, <Color>[
            Palette.gold.withValues(alpha: 0.45 * pulse),
            Palette.gold.withValues(alpha: 0),
          ]),
      );
      canvas.drawCircle(p, 2.8, Paint()..color = Palette.gold);
      canvas.drawLine(
        center,
        p,
        Paint()
          ..strokeWidth = 0.8
          ..color = Palette.gold.withValues(alpha: 0.22),
      );
    }

    if (me != null) {
      if (vm.snapshot?.teams == true) {
        final myTeam = me.team;
        for (final actor in vm.actors.values) {
          if (!actor.alive || actor.isSelf || actor.team != myTeam) continue;
          final delta = actor.pos - me.pos;
          final distance = delta.distance;
          if (distance < 1) continue;
          final markerDistance = math.min(distance * scale, radius * 0.91);
          final marker = center + delta / distance * markerDistance;
          canvas.drawCircle(
            marker,
            5.5,
            Paint()..color = const Color(0xFF7FB2FF).withValues(alpha: 0.25),
          );
          canvas.drawCircle(
            marker,
            3,
            Paint()..color = const Color(0xFF7FB2FF),
          );
          canvas.drawCircle(
            marker,
            4.2,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1
              ..color = Colors.white.withValues(alpha: 0.8),
          );
        }
      }
      final aim = vm.myAim;
      final dir = Offset(math.cos(aim), math.sin(aim));
      final side = Offset(-dir.dy, dir.dx);
      final tip = center + dir * 7;
      final left = center - dir * 4 + side * 4;
      final right = center - dir * 4 - side * 4;
      final path = Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(left.dx, left.dy)
        ..lineTo(right.dx, right.dy)
        ..close();
      canvas.drawPath(path, Paint()..color = Palette.accent);
    }
    canvas.restore();

    final north = TextPainter(
      text: const TextSpan(
        text: 'С',
        style: TextStyle(
          color: Palette.mutedDark,
          fontSize: 8,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    north.paint(canvas, Offset(center.dx - north.width / 2, 2));
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) => false;
}

class _KillFeed extends StatelessWidget {
  const _KillFeed({
    required this.entries,
    required this.myId,
    required this.now,
  });

  final List<KillFeedEntry> entries;
  final int myId;
  final double now;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        for (final entry in entries.take(5))
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: _KillRow(entry: entry, myId: myId, now: now),
          ),
      ],
    );
  }
}

class _KillRow extends StatelessWidget {
  const _KillRow({required this.entry, required this.myId, required this.now});

  final KillFeedEntry entry;
  final int myId;
  final double now;

  @override
  Widget build(BuildContext context) {
    final def = weaponByIndex(entry.weapon);
    final age = (now - entry.createdAt).clamp(0.0, 6.0);
    final opacity = age > 5 ? (6 - age).clamp(0.0, 1.0) : 1.0;
    final mine = entry.killerId == myId;
    final victimMe = entry.victimId == myId;
    final killerColor = mine ? Palette.accent : Palette.text;
    final victimColor = victimMe ? Palette.danger : Palette.muted;
    return Opacity(
      opacity: opacity,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.52),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: (mine ? Palette.accent : Palette.line).withValues(
              alpha: 0.35,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Flexible(
              child: Text(
                entry.killer,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: killerColor,
                ),
              ),
            ),
            const SizedBox(width: 5),
            Icon(_weaponIcon(def.id), size: 12, color: Color(def.color)),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                entry.victim,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: victimColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _weaponIcon(WeaponId id) {
  switch (id) {
    case WeaponId.pistol:
      return Icons.sports_handball_rounded;
    case WeaponId.smg:
      return Icons.bolt_rounded;
    case WeaponId.shotgun:
      return Icons.grain_rounded;
    case WeaponId.rifle:
      return Icons.straighten_rounded;
    case WeaponId.sniper:
      return Icons.gps_fixed_rounded;
  }
}

class _VitalsCard extends StatelessWidget {
  const _VitalsCard({required this.vm, required this.compact});

  final GameViewModel vm;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final me = vm.myActor;
    final hp = me?.hp ?? 0;
    final shield = me?.shield ?? 0;
    final hpRatio = (hp / kMaxHp).clamp(0.0, 1.0);
    final shieldRatio = (shield / kMaxShield).clamp(0.0, 1.0);
    final hpColor = hpRatio > 0.55
        ? const Color(0xFF64F5A4)
        : (hpRatio > 0.25 ? Palette.gold : Palette.danger);
    final width = compact ? 148.0 : 190.0;
    final speed = me?.speedTime ?? 0;
    final ghost = me?.ghostTime ?? 0;
    return _Glass(
      width: width,
      padding: const EdgeInsets.fromLTRB(11, 9, 11, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.favorite_rounded, size: 12, color: hpColor),
              const SizedBox(width: 6),
              Text(
                hp.ceil().toString(),
                style: TextStyle(
                  fontSize: compact ? 17 : 19,
                  fontWeight: FontWeight.w900,
                  color: hpColor,
                  height: 1,
                ),
              ),
              const Spacer(),
              if (shield > 0) ...<Widget>[
                const Icon(
                  Icons.shield_rounded,
                  size: 12,
                  color: Color(0xFF7FB2FF),
                ),
                const SizedBox(width: 4),
                Text(
                  shield.ceil().toString(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF7FB2FF),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          _Bar(value: hpRatio, color: hpColor, height: 7),
          const SizedBox(height: 4),
          _Bar(value: shieldRatio, color: const Color(0xFF7FB2FF), height: 4),
          if (speed > 0 || ghost > 0) ...<Widget>[
            const SizedBox(height: 7),
            Wrap(
              spacing: 5,
              runSpacing: 4,
              children: <Widget>[
                if (speed > 0)
                  _EffectChip(
                    icon: Icons.speed_rounded,
                    label: '${speed.ceil()}с',
                    color: Palette.gold,
                  ),
                if (ghost > 0)
                  _EffectChip(
                    icon: Icons.blur_on_rounded,
                    label: '${ghost.ceil()}с',
                    color: const Color(0xFFC792FF),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _WeaponCard extends StatelessWidget {
  const _WeaponCard({required this.vm, required this.compact});

  final GameViewModel vm;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final me = vm.myActor;
    final def = me == null ? kWeapons.first : weaponByIndex(me.weapon);
    final color = Color(def.color);
    final ammo = me?.ammo ?? 0;
    final width = compact ? 150.0 : 194.0;
    final dash = me?.dashCooldown ?? 0;
    return _Glass(
      width: width,
      padding: const EdgeInsets.fromLTRB(11, 9, 11, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(_weaponIcon(def.id), size: 15, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  def.short.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: Palette.muted,
                  ),
                ),
              ),
              if (me?.reloading == true)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Palette.gold,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                ammo.toString(),
                style: TextStyle(
                  fontSize: compact ? 22 : 26,
                  fontWeight: FontWeight.w900,
                  color: color,
                  height: 1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 2, left: 3),
                child: Text(
                  '/${def.magSize}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Palette.mutedDark,
                  ),
                ),
              ),
              const Spacer(),
              if (me?.reloading == true)
                const Text(
                  'ПЕРЕЗАРЯДКА',
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    color: Palette.gold,
                  ),
                )
              else
                Text(
                  compact ? 'R' : 'R — ПЕРЕЗАРЯДКА',
                  style: const TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    color: Palette.mutedDark,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Icon(
                Icons.bolt_rounded,
                size: 11,
                color: dash > 0 ? Palette.mutedDark : Palette.gold,
              ),
              const SizedBox(width: 3),
              Expanded(
                child: _Bar(
                  value: dash > 0 ? 1 - (dash / 2.6).clamp(0.0, 1.0) : 1,
                  color: dash > 0 ? Palette.mutedDark : Palette.gold,
                  height: 3,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                dash > 0 ? '${dash.toStringAsFixed(1)}с' : 'РЫВОК',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: dash > 0 ? Palette.mutedDark : Palette.gold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.value, required this.color, required this.height});

  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            ColoredBox(color: Colors.black.withValues(alpha: 0.5)),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value.clamp(0.0, 1.0),
              child: ColoredBox(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _EffectChip extends StatelessWidget {
  const _EffectChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 9, color: color),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _DangerPill extends StatelessWidget {
  const _DangerPill({required this.text, required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Palette.danger.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: Palette.danger.withValues(alpha: 0.65)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Palette.danger.withValues(alpha: 0.2),
            blurRadius: 18,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 13, color: Palette.danger),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: Palette.danger,
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerView extends StatelessWidget {
  const _BannerView({required this.banner, required this.now});

  final HudBanner banner;
  final double now;

  @override
  Widget build(BuildContext context) {
    final age = (now - banner.createdAt).clamp(0.0, banner.duration);
    final opacity = age > banner.duration - 0.5
        ? ((banner.duration - age) / 0.5).clamp(0.0, 1.0)
        : 1.0;
    return Opacity(
      opacity: opacity,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: banner.color.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(banner.icon, size: 15, color: banner.color),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  banner.text,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: banner.color,
                  ),
                ),
                if (banner.detail != null)
                  Text(
                    banner.detail!,
                    style: const TextStyle(fontSize: 9.5, color: Palette.muted),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Glass extends StatelessWidget {
  const _Glass({
    required this.child,
    this.padding = EdgeInsets.zero,
    this.width,
  });

  final Widget child;
  final EdgeInsets padding;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: padding,
      decoration: BoxDecoration(
        color: Palette.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Palette.line.withValues(alpha: 0.85)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// Оверлеи
// ---------------------------------------------------------------------------

class ScoreboardOverlay extends StatelessWidget {
  const ScoreboardOverlay({
    super.key,
    required this.snapshot,
    required this.myId,
    required this.onClose,
  });

  final Snapshot snapshot;
  final int myId;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: onClose,
        child: Container(
          color: Colors.black.withValues(alpha: 0.55),
          padding: const EdgeInsets.all(18),
          child: Center(
            child: SingleChildScrollView(
              child: NeonPanel(
                padding: const EdgeInsets.all(18),
                borderColor: Palette.accent.withValues(alpha: 0.4),
                glow: true,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          const Icon(
                            Icons.emoji_events_outlined,
                            size: 20,
                            color: Palette.gold,
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'ТАБЛИЦА',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                            ),
                          ),
                          const Spacer(),
                          Pill(
                            text:
                                '${snapshot.alivePlayers}/${snapshot.totalPlayers} ЖИВЫ',
                            color: Palette.accent,
                            small: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const _ScoreHeader(),
                      const SizedBox(height: 4),
                      for (var i = 0; i < snapshot.scoreboard.length; i++)
                        _ScoreRowView(
                          index: i,
                          row: snapshot.scoreboard[i],
                          name: snapshot.nameOf(snapshot.scoreboard[i].id),
                          isMe: snapshot.scoreboard[i].id == myId,
                          teams: snapshot.teams,
                          myTeam: snapshot.teamOf(myId),
                        ),
                      const SizedBox(height: 12),
                      const Text(
                        'Нажмите, чтобы закрыть · Tab — удерживайте',
                        style: TextStyle(
                          fontSize: 10,
                          color: Palette.mutedDark,
                        ),
                      ),
                    ],
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

class _ScoreHeader extends StatelessWidget {
  const _ScoreHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: <Widget>[
          SizedBox(width: 26, child: _HeaderText('#')),
          Expanded(child: _HeaderText('ИГРОК')),
          SizedBox(width: 44, child: _HeaderText('УБИЙ')),
          SizedBox(width: 66, child: _HeaderText('УРОН')),
          SizedBox(width: 58, child: _HeaderText('СТАТУС')),
        ],
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  const _HeaderText(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 8.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 1,
        color: Palette.mutedDark,
      ),
    );
  }
}

class _ScoreRowView extends StatelessWidget {
  const _ScoreRowView({
    required this.index,
    required this.row,
    required this.name,
    required this.isMe,
    this.teams = false,
    this.myTeam = -1,
  });

  final int index;
  final ScoreRow row;
  final String name;
  final bool isMe;
  final bool teams;
  final int myTeam;

  @override
  Widget build(BuildContext context) {
    final color = isMe ? Palette.accent : Palette.text;
    return Container(
      margin: const EdgeInsets.only(bottom: 3),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isMe
            ? Palette.accent.withValues(alpha: 0.09)
            : Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isMe
              ? Palette.accent.withValues(alpha: 0.3)
              : Colors.transparent,
        ),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 26,
            child: Text(
              '${index + 1}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: index == 0 ? Palette.gold : Palette.muted,
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: <Widget>[
                if (teams) ...<Widget>[
                  _TeamBadge(team: row.team, mine: row.team == myTeam),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    isMe ? '$name · вы' : name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: isMe ? FontWeight.w800 : FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              '${row.kills}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Palette.muted,
              ),
            ),
          ),
          SizedBox(
            width: 66,
            child: Text(
              row.damage.round().toString(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Palette.muted,
              ),
            ),
          ),
          SizedBox(
            width: 58,
            child: Text(
              row.alive ? 'ЖИВ' : 'ВЫБЫЛ',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: row.alive ? Palette.accent : Palette.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ResultsOverlay extends StatelessWidget {
  const ResultsOverlay({
    super.key,
    required this.snapshot,
    required this.myId,
    required this.isHost,
    required this.awaiting,
    required this.onAgain,
    required this.onExit,
    this.lobbyMode = false,
    this.canLobby = false,
    this.awaitingLobby = false,
    this.onLobby,
  });

  final Snapshot snapshot;
  final int myId;
  final bool isHost;
  final bool awaiting;
  final VoidCallback onAgain;
  final VoidCallback onExit;
  final bool lobbyMode;
  final bool canLobby;
  final bool awaitingLobby;
  final VoidCallback? onLobby;

  @override
  Widget build(BuildContext context) {
    final myRow = snapshot.resultOf(myId);
    final myTeam = snapshot.teamOf(myId);
    final win = snapshot.teams
        ? snapshot.winTeam >= 0 && myTeam == snapshot.winTeam
        : myRow?.placement == 1;
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.68),
        padding: const EdgeInsets.all(18),
        child: Center(
          child: SingleChildScrollView(
            child: NeonPanel(
              padding: const EdgeInsets.all(20),
              borderColor: (win ? Palette.gold : Palette.accent).withValues(
                alpha: 0.45,
              ),
              glow: true,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      win
                          ? Icons.emoji_events_rounded
                          : Icons.workspace_premium_outlined,
                      size: 36,
                      color: win ? Palette.gold : Palette.muted,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      win
                          ? (snapshot.teams ? 'ПОБЕДА КОМАНДЫ' : 'ПОБЕДА')
                          : 'МАТЧ ОКОНЧЕН',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: win ? (snapshot.teams ? 21 : 26) : 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                        color: win ? Palette.gold : Palette.text,
                      ),
                    ),
                    if (myRow != null) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        snapshot.teams && myTeam >= 0
                            ? 'Команда ${myTeam + 1} · '
                                  '${myRow.kills} убийств · '
                                  '${myRow.damage.round()} урона'
                            : 'Вы заняли ${myRow.placement}-е место · '
                                  '${myRow.kills} убийств · '
                                  '${myRow.damage.round()} урона',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Palette.muted,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    const _ResultsHeader(),
                    for (final row in snapshot.results)
                      _ResultRowView(
                        row: row,
                        name: snapshot.nameOf(row.id),
                        isMe: row.id == myId,
                        teams: snapshot.teams,
                        myTeam: myTeam,
                      ),
                    const SizedBox(height: 18),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: NeonButton(
                            label: isHost ? 'Реванш' : 'Ждём хоста',
                            subtitle: isHost
                                ? 'Новый лабиринт и спавн'
                                : 'Хост решает, играем ли ещё',
                            icon: Icons.replay_rounded,
                            primary: isHost,
                            busy: awaiting,
                            height: 48,
                            onPressed: isHost && !awaiting ? onAgain : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: NeonButton(
                            label: lobbyMode
                                ? (canLobby ? 'В лобби' : 'Ждём хоста')
                                : 'В меню',
                            subtitle: lobbyMode
                                ? (canLobby
                                      ? 'Сменить настройки комнаты'
                                      : 'Хост вернёт всех в лобби')
                                : 'Вернуться в главное меню',
                            icon: lobbyMode
                                ? Icons.meeting_room_outlined
                                : Icons.exit_to_app_rounded,
                            busy: awaitingLobby,
                            height: 48,
                            onPressed: lobbyMode
                                ? (canLobby && !awaitingLobby ? onLobby : null)
                                : onExit,
                          ),
                        ),
                      ],
                    ),
                    if (lobbyMode) ...<Widget>[
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: onExit,
                        child: const Text(
                          'Покинуть комнату',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Palette.danger,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultsHeader extends StatelessWidget {
  const _ResultsHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: <Widget>[
          SizedBox(width: 34, child: _HeaderText('МЕСТО')),
          Expanded(child: _HeaderText('ИГРОК')),
          SizedBox(width: 48, child: _HeaderText('УБИЙ')),
          SizedBox(width: 60, child: _HeaderText('УРОН')),
          SizedBox(width: 54, child: _HeaderText('ВРЕМЯ')),
        ],
      ),
    );
  }
}

class _ResultRowView extends StatelessWidget {
  const _ResultRowView({
    required this.row,
    required this.name,
    required this.isMe,
    this.teams = false,
    this.myTeam = -1,
  });

  final ResultRow row;
  final String name;
  final bool isMe;
  final bool teams;
  final int myTeam;

  @override
  Widget build(BuildContext context) {
    final medal = row.placement == 1
        ? Palette.gold
        : (row.placement == 2
              ? const Color(0xFFC7D3E3)
              : (row.placement == 3
                    ? const Color(0xFFD79A6A)
                    : Palette.mutedDark));
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: isMe
            ? Palette.accent.withValues(alpha: 0.09)
            : Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isMe
              ? Palette.accent.withValues(alpha: 0.3)
              : Colors.transparent,
        ),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 34,
            child: Text(
              '#${row.placement}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: medal,
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: <Widget>[
                if (teams) ...<Widget>[
                  _TeamBadge(team: row.team, mine: row.team == myTeam),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    isMe ? '$name · вы' : name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: isMe ? FontWeight.w800 : FontWeight.w600,
                      color: isMe ? Palette.accent : Palette.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 48,
            child: Text(
              '${row.kills}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Palette.muted,
              ),
            ),
          ),
          SizedBox(
            width: 60,
            child: Text(
              row.damage.round().toString(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Palette.muted,
              ),
            ),
          ),
          SizedBox(
            width: 54,
            child: Text(
              _clock(row.survived),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Palette.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Помощники
// ---------------------------------------------------------------------------

class _TeamBadge extends StatelessWidget {
  const _TeamBadge({required this.team, required this.mine});

  final int team;
  final bool mine;

  static const List<Color> _colors = <Color>[
    Color(0xFF3BE8C8),
    Color(0xFFFF4E8E),
    Color(0xFFFFC857),
    Color(0xFF7FB2FF),
  ];

  @override
  Widget build(BuildContext context) {
    if (team < 0) return const SizedBox.shrink();
    final color = _colors[team % _colors.length];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: mine ? 0.22 : 0.10),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Text(
        'T${team + 1}',
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
          color: color,
        ),
      ),
    );
  }
}

String _clock(double seconds) {
  final total = seconds.clamp(0, 5999).floor();
  final m = total ~/ 60;
  final s = total % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

String _shortTime(double seconds) {
  final total = seconds.clamp(0, 599).ceil();
  return '${total ~/ 60}:${(total % 60).toString().padLeft(2, '0')}';
}

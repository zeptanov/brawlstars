import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../game/constants.dart';
import '../game/maze.dart';
import '../net/messages.dart';

class RenderActor {
  RenderActor({
    required this.id,
    required this.name,
    required this.isSelf,
    required this.pos,
    required this.aim,
  }) : target = pos,
       targetAim = aim;

  final int id;
  String name;
  bool isSelf;
  Offset pos;
  Offset target;
  double aim;
  double targetAim;
  double hp = kMaxHp;
  double shield = 0;
  bool alive = true;
  int weapon = 0;
  int ammo = 0;
  int team = -1;
  double ghostTime = 0;
  double speedTime = 0;
  double dashCooldown = 0;
  double reloadRemaining = 0;
  bool reloading = false;
}

class PickupView {
  const PickupView(this.id, this.pos, this.type);
  final int id;
  final Offset pos;
  final int type;
}

class BulletView {
  const BulletView(this.pos, this.velocity, this.weapon);
  final Offset pos;
  final Offset velocity;
  final int weapon;
}

class VisualEffect {
  VisualEffect({
    required this.pos,
    required this.color,
    required this.size,
    required this.life,
    this.ring = true,
  }) : maxLife = life;

  final Offset pos;
  final Color color;
  final double size;
  double life;
  final double maxLife;
  final bool ring;
}

/// Всё, что нужно рендереру, в одном месте. Обновляется каждый кадр.
class GameViewModel {
  final ValueNotifier<int> repaint = ValueNotifier<int>(0);

  Maze? maze;
  Snapshot? snapshot;
  int myId = 0;
  int tick = 0;
  final Map<int, RenderActor> actors = <int, RenderActor>{};
  final List<PickupView> pickups = <PickupView>[];
  final List<BulletView> bullets = <BulletView>[];
  final List<VisualEffect> effects = <VisualEffect>[];

  ZoneSnapshot zone = const ZoneSnapshot(0, 0, 1);
  int zoneStage = 0;
  bool zoneShrinking = false;
  double nextZoneIn = 0;
  double matchTime = 0;
  MatchPhase phase = MatchPhase.countdown;

  Uint8List explored = Uint8List(0);
  Offset camera = Offset.zero;
  double scale = 1;
  Size viewport = Size.zero;
  double time = 0;
  double shake = 0;
  bool spectator = false;
  bool observerFog = false;
  int spectateTargetId = 0;
  double myAim = 0;
  bool showShake = true;
  int rayCount = 72;
  bool initialisedCamera = false;
  int _pendingSpectate = 0;

  double _exploreAccum = 0;

  RenderActor? get myActor => actors[myId];

  RenderActor? get focusActor {
    if (!spectator) return myActor;
    final target = actors[spectateTargetId];
    if (target != null && target.alive) return target;
    for (final actor in actors.values) {
      if (actor.alive) return actor;
    }
    return null;
  }

  bool get outsideZone {
    final me = myActor;
    if (me == null || spectator) return false;
    return !zone.contains(me.pos.dx, me.pos.dy);
  }

  void setMaze(Maze? value) {
    if (identical(maze, value)) return;
    maze = value;
    explored = value == null
        ? Uint8List(0)
        : Uint8List(value.size * value.size);
    snapshot = null;
    tick = 0;
    phase = MatchPhase.countdown;
    matchTime = 0;
    spectator = false;
    observerFog = false;
    spectateTargetId = 0;
    _pendingSpectate = 0;
    actors.clear();
    bullets.clear();
    pickups.clear();
    effects.clear();
    initialisedCamera = false;
  }

  void ensureViewport(Size size) {
    if (size == viewport || size.isEmpty) return;
    viewport = size;
    scale = _scaleFor(size);
  }

  double _scaleFor(Size size) {
    final base = math.min(size.width, size.height) / 640.0;
    return base.clamp(0.55, 1.8);
  }

  Offset screenToWorld(Offset local) {
    final center = Offset(viewport.width / 2, viewport.height / 2);
    return (local - center) / scale + camera;
  }

  Offset worldToScreen(Offset world) =>
      (world - camera) * scale +
      Offset(viewport.width / 2, viewport.height / 2);

  void update(Snapshot? snap, double dt, {required bool touch}) {
    time += dt;
    if (dt > 0.1) dt = 0.1;
    if (snap == null) {
      repaint.value++;
      return;
    }
    snapshot = snap;
    tick = snap.tick;
    phase = snap.phase;
    matchTime = snap.matchTime;
    zone = snap.zone;
    zoneStage = snap.zoneStage;
    zoneShrinking = snap.zoneShrinking;
    nextZoneIn = snap.nextZoneEventIn;
    observerFog = snap.fogView;
    if (_pendingSpectate != 0) {
      final row = snap.scoreOf(_pendingSpectate);
      if (row == null || !row.alive) _pendingSpectate = 0;
    }
    if (snap.spectateTarget > 0) {
      if (_pendingSpectate == 0 || snap.spectateTarget == _pendingSpectate) {
        spectateTargetId = snap.spectateTarget;
        if (snap.spectateTarget == _pendingSpectate) _pendingSpectate = 0;
      }
    }

    final seen = <int>{};
    for (final p in snap.players) {
      seen.add(p.id);
      final isSelf = p.id == myId;
      var actor = actors[p.id];
      if (actor == null) {
        actor = RenderActor(
          id: p.id,
          name: snap.names[p.id] ?? 'Игрок ${p.id}',
          isSelf: isSelf,
          pos: Offset(p.x, p.y),
          aim: p.aim,
        );
        actors[p.id] = actor;
      }
      actor
        ..name = snap.names[p.id] ?? actor.name
        ..isSelf = isSelf
        ..target = Offset(p.x, p.y)
        ..targetAim = p.aim
        ..hp = p.hp
        ..shield = p.shield
        ..alive = p.alive
        ..weapon = p.weapon
        ..ammo = p.ammo
        ..team = p.team
        ..ghostTime = p.ghostTime
        ..speedTime = p.speedTime
        ..dashCooldown = p.dashCooldown
        ..reloadRemaining = p.reloadRemaining
        ..reloading = p.reloading;
      if (isSelf) {
        actor.aim = myAim;
        if (!initialisedCamera) {
          actor.pos = actor.target;
        }
      }
    }
    actors.removeWhere((id, _) => !seen.contains(id));

    final self = myActor;
    spectator = self == null || !self.alive;
    if (spectator && _pendingSpectate == 0) {
      final current = actors[spectateTargetId];
      if (current == null || !current.alive || current.isSelf) {
        RenderActor? target;
        for (final row in snap.scoreboard) {
          if (!row.alive || row.id == myId) continue;
          final candidate = actors[row.id];
          if (candidate != null && candidate.alive) {
            target = candidate;
            break;
          }
        }
        if (target == null) {
          for (final a in actors.values) {
            if (a.alive && !a.isSelf) {
              target = a;
              break;
            }
          }
        }
        if (target != null) {
          spectateTargetId = target.id;
          _pendingSpectate = 0;
        }
      }
    }

    final smooth = 1 - math.exp(-dt * 24);
    final selfSmooth = 1 - math.exp(-dt * 30);
    for (final actor in actors.values) {
      if (actor.isSelf) {
        final delta = actor.target - actor.pos;
        actor.pos = delta.distance > 140
            ? actor.target
            : actor.pos + delta * selfSmooth;
        actor.aim = myAim;
      } else {
        final delta = actor.target - actor.pos;
        if (delta.distance > 300) {
          actor.pos = actor.target;
        } else {
          actor.pos += delta * smooth;
        }
        actor.aim = angleLerp(actor.aim, actor.targetAim, smooth);
      }
    }

    bullets
      ..clear()
      ..addAll(
        snap.bullets.map(
          (b) => BulletView(Offset(b.x, b.y), Offset(b.vx, b.vy), b.weapon),
        ),
      );
    pickups
      ..clear()
      ..addAll(
        snap.pickups.map((p) => PickupView(p.id, Offset(p.x, p.y), p.type)),
      );

    final focus = focusActor;
    if (focus != null) {
      var target = focus.pos;
      if (!spectator) {
        target += Offset(math.cos(myAim), math.sin(myAim)) * 48;
      }
      if (!initialisedCamera) {
        camera = target;
        initialisedCamera = true;
      } else {
        final camSmooth = 1 - math.exp(-dt * 9);
        var next = camera + (target - camera) * camSmooth;
        final world = maze?.worldSize ?? 0;
        if (world > 0) {
          next = Offset(next.dx.clamp(0, world), next.dy.clamp(0, world));
        }
        camera = next;
      }
    }

    scale = _scaleFor(viewport);
    if (maze != null && !spectator && focus != null) {
      _exploreAccum += dt;
      if (_exploreAccum >= 0.11) {
        _exploreAccum = 0;
        _markExplored(focus.pos);
        final snapshot = snap;
        if (snapshot.teams && snapshot.allyVision && focus.team >= 0) {
          for (final ally in actors.values) {
            if (ally.alive && !ally.isSelf && ally.team == focus.team) {
              _markExplored(ally.pos);
            }
          }
        }
      }
    }

    for (var i = effects.length - 1; i >= 0; i--) {
      effects[i].life -= dt;
      if (effects[i].life <= 0) effects.removeAt(i);
    }
    shake = math.max(0, shake - dt * 2.6);
    repaint.value++;
  }

  void _markExplored(Offset from) {
    final m = maze;
    if (m == null) return;
    if (explored.length != m.size * m.size) {
      explored = Uint8List(m.size * m.size);
    }
    final rays = rayCount;
    for (var i = 0; i < rays; i++) {
      final angle = i * math.pi * 2 / rays;
      final dist = m.raycast(from.dx, from.dy, angle, kVisionRadius);
      final dx = math.cos(angle);
      final dy = math.sin(angle);
      for (var s = 0.0; s <= dist; s += kTileSize * 0.4) {
        final tx = ((from.dx + dx * s) / kTileSize).floor();
        final ty = ((from.dy + dy * s) / kTileSize).floor();
        if (tx < 0 || ty < 0 || tx >= m.size || ty >= m.size) continue;
        explored[ty * m.size + tx] = 1;
      }
    }
  }

  void addBurst(
    Offset pos,
    Color color, {
    double size = 20,
    double life = 0.45,
    bool ring = true,
  }) {
    if (effects.length > 90) effects.removeAt(0);
    effects.add(
      VisualEffect(pos: pos, color: color, size: size, life: life, ring: ring),
    );
  }

  void kick(double strength) {
    shake = math.max(shake, strength);
  }

  void chooseSpectate(int id) {
    if (id <= 0) return;
    spectateTargetId = id;
    _pendingSpectate = id;
  }
}

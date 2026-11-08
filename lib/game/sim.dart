import 'dart:math' as math;
import 'dart:ui';

import '../net/messages.dart';
import 'constants.dart';
import 'maze.dart';
import 'pickups.dart';
import 'weapons.dart';
import 'zone.dart';

class PlayerSpec {
  const PlayerSpec({
    required this.id,
    required this.name,
    required this.isBot,
    this.team = -1,
  });
  final int id;
  final String name;
  final bool isBot;
  final int team;
}

class SimPlayer {
  SimPlayer({
    required this.id,
    required this.name,
    required this.isBot,
    required this.pos,
    this.team = -1,
  });

  final int id;
  final String name;
  final bool isBot;
  final int team;

  Offset pos;
  double aim = 0;
  double hp = kMaxHp;
  double shield = 0;
  bool alive = true;
  int kills = 0;
  double damageDealt = 0;
  double deathTime = 0;

  /// Время возрождения (matchTime). 0 — возрождение недоступно.
  double respawnAt = 0;

  int weaponIndex = WeaponId.pistol.index;
  int ammo = 12;
  double fireCooldown = 0;
  double reloadTimer = 0;

  double dashCooldown = 0;
  double dashTime = 0;
  double speedTime = 0;
  double ghostTime = 0;
  double radarTime = 0;

  double vx = 0;
  double vy = 0;

  InputState input = InputState.idle;

  WeaponDef get weaponDef => weaponByIndex(weaponIndex);
  bool get reloading => reloadTimer > 0;
}

class SimBullet {
  SimBullet({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.ownerId,
    required this.damage,
    required this.life,
    required this.weaponIndex,
  });

  double x;
  double y;
  final double vx;
  final double vy;
  final int ownerId;
  final double damage;
  double life;
  final int weaponIndex;
}

class SimPickup {
  SimPickup({
    required this.id,
    required this.pos,
    required this.type,
    this.active = true,
    this.respawnAt = 0,
    this.temporary = false,
  });

  final int id;
  Offset pos;
  final PickupType type;
  bool active;
  double respawnAt;
  final bool temporary;
}

/// Авторитетная симуляция матча. Крутится только на сервере.
class GameSim {
  GameSim({
    required this.seed,
    required this.mapSize,
    required List<PlayerSpec> specs,
    required this.tempo,
    required this.botSkill,
    this.teams = false,
    this.friendlyFire = false,
    this.deathVision = 1,
    this.loot = 1,
    this.respawn = false,
  }) : maze = Maze.generate(size: mapSize, seed: seed),
       rng = math.Random(seed ^ 0x0BADC0DE) {
    zone = ZoneTimeline.generate(
      worldSize: maze.worldSize,
      seed: seed ^ 0x2545F491,
      tempo: _tempoFactor(tempo),
    );
    final spawns = _initialSpawns(specs);
    for (var i = 0; i < specs.length; i++) {
      final spec = specs[i];
      final p = SimPlayer(
        id: spec.id,
        name: spec.name,
        isBot: spec.isBot,
        team: spec.team,
        pos: spawns[i % math.max(1, spawns.length)],
      );
      players[p.id] = p;
      if (spec.isBot) {
        _brains[p.id] = BotBrain(
          p.id,
          skill: botSkill,
          seed: seed + p.id * 7919,
        );
      }
    }
    _spawnInitialPickups();
  }

  final int seed;
  final int mapSize;
  final int tempo;
  final double botSkill;
  final bool teams;
  final bool friendlyFire;

  /// 0 — мёртвый наблюдатель видит только туман выбранного игрока,
  /// 1 — мёртвый наблюдатель видит всю карту.
  final int deathVision;
  final int loot;

  /// Возрождение павших бойцов рядом с живым союзником (только в командах).
  final bool respawn;
  final Maze maze;
  final math.Random rng;
  final Map<int, SimPlayer> players = <int, SimPlayer>{};
  final List<SimBullet> bullets = <SimBullet>[];
  final List<SimPickup> pickups = <SimPickup>[];
  final List<GameEvent> events = <GameEvent>[];
  final Map<int, BotBrain> _brains = <int, BotBrain>{};

  late final ZoneTimeline zone;
  MatchPhase phase = MatchPhase.countdown;
  double phaseTime = kCountdownSeconds.toDouble();
  double matchTime = 0;
  double endTime = 0;
  int tick = 0;
  int _lastZoneStage = 0;
  int _nextPickupId = 1;
  bool _resultsReady = false;
  List<ResultRow> results = const <ResultRow>[];
  int winTeam = -1;

  ZoneSample get zoneNow => zone.sample(matchTime);
  int get aliveCount => players.values.where((p) => p.alive).length;

  static double _tempoFactor(int tempo) {
    switch (tempo) {
      case 0:
        return 0.8;
      case 2:
        return 1.28;
      default:
        return 1.0;
    }
  }

  // -------------------------------------------------------------------------
  // Создание мира
  // -------------------------------------------------------------------------

  int _weightedPickupType() {
    final total = kPickups.fold<int>(0, (s, p) => s + (p.weight ?? 1));
    var roll = rng.nextInt(total);
    for (var i = 0; i < kPickups.length; i++) {
      roll -= kPickups[i].weight ?? 1;
      if (roll < 0) return i;
    }
    return 0;
  }

  void _spawnInitialPickups() {
    final base = (mapSize / 61 * 26).round().clamp(16, 34);
    final multiplier = loot == 0 ? 0.6 : (loot == 2 ? 1.45 : 1.0);
    final count = (base * multiplier).round();
    final spawns = players.values.map((p) => p.pos).toList();
    for (var i = 0; i < count; i++) {
      Offset pos = maze.randomFloorPoint(rng);
      var attempts = 0;
      while (attempts++ < 40 && spawns.any((s) => (s - pos).distance < 260)) {
        pos = maze.randomFloorPoint(rng);
      }
      pickups.add(
        SimPickup(
          id: _nextPickupId++,
          pos: pos,
          type: PickupType.values[_weightedPickupType()],
        ),
      );
    }
  }

  SimPickup _spawnPickupAt(
    PickupType type,
    Offset pos, {
    bool temporary = false,
  }) {
    final pk = SimPickup(
      id: _nextPickupId++,
      pos: pos,
      type: type,
      temporary: temporary,
    );
    pickups.add(pk);
    return pk;
  }

  PickupType? _pickupForWeapon(int index) {
    switch (WeaponId.values[index.clamp(0, WeaponId.values.length - 1)]) {
      case WeaponId.smg:
        return PickupType.smg;
      case WeaponId.shotgun:
        return PickupType.shotgun;
      case WeaponId.rifle:
        return PickupType.rifle;
      case WeaponId.sniper:
        return PickupType.sniper;
      case WeaponId.pistol:
        return null;
    }
  }

  // -------------------------------------------------------------------------
  // Подключение и выход игроков
  // -------------------------------------------------------------------------

  SimPlayer addPlayer(PlayerSpec spec) {
    final p = SimPlayer(
      id: spec.id,
      name: spec.name,
      isBot: spec.isBot,
      team: spec.team,
      pos: _safeSpawnForJoin(),
    );
    players[p.id] = p;
    if (spec.isBot) {
      _brains[p.id] = BotBrain(p.id, skill: botSkill, seed: seed + p.id * 7919);
    }
    events.add(JoinEvent(p.id));
    return p;
  }

  void removePlayer(int id) {
    if (players.remove(id) != null) {
      _brains.remove(id);
      events.add(LeaveEvent(id));
    }
  }

  List<Offset> _initialSpawns(List<PlayerSpec> specs) {
    final z = zone.sample(0);
    final result = <Offset>[];
    final used = <Offset>[];
    final anchors = <int, Offset>{};
    for (final spec in specs) {
      if (teams && spec.team >= 0) {
        var anchor = anchors[spec.team];
        if (anchor == null) {
          anchor = _spreadPoint(z, used, 360);
          anchors[spec.team] = anchor;
          used.add(anchor);
        }
        final pos = _nearPoint(anchor, z, used);
        result.add(pos);
        used.add(pos);
      } else {
        final pos = _spreadPoint(z, used, 300);
        result.add(pos);
        used.add(pos);
      }
    }
    return result;
  }

  Offset _spreadPoint(ZoneSample z, List<Offset> used, double minDist) {
    final maxR = z.radius * 0.8;
    Offset? fallback;
    for (var i = 0; i < 180; i++) {
      final a = rng.nextDouble() * math.pi * 2;
      final r = math.sqrt(rng.nextDouble()) * maxR;
      final pos = z.center + Offset(math.cos(a) * r, math.sin(a) * r);
      if (!maze.isOpenWorld(pos.dx, pos.dy)) continue;
      fallback ??= pos;
      if (used.every((u) => (u - pos).distance >= minDist)) return pos;
    }
    return fallback ?? _safeSpawnForJoin();
  }

  Offset _nearPoint(Offset anchor, ZoneSample z, List<Offset> used) {
    for (var i = 0; i < 80; i++) {
      final a = rng.nextDouble() * math.pi * 2;
      final r = 70 + rng.nextDouble() * 95;
      final pos = anchor + Offset(math.cos(a) * r, math.sin(a) * r);
      if (!z.contains(pos.dx, pos.dy) || !maze.isOpenWorld(pos.dx, pos.dy)) {
        continue;
      }
      if (used.any((u) => (u - pos).distance < 48)) continue;
      return pos;
    }
    return anchor;
  }

  Offset _safeSpawnForJoin() {
    final z = zoneNow;
    for (var i = 0; i < 120; i++) {
      final a = rng.nextDouble() * math.pi * 2;
      final r = math.sqrt(rng.nextDouble()) * z.radius * 0.75;
      final pos = z.center + Offset(math.cos(a) * r, math.sin(a) * r);
      if (!z.contains(pos.dx, pos.dy)) continue;
      if (!maze.isOpenWorld(pos.dx, pos.dy)) continue;
      final far = players.values.every(
        (p) => !p.alive || (p.pos - pos).distance > 360,
      );
      if (far) return pos;
    }
    final fallback = maze.randomFloorPoint(
      rng,
      center: z.center,
      radius: z.radius * 0.55,
    );
    if (z.contains(fallback.dx, fallback.dy)) return fallback;
    return z.center;
  }

  // -------------------------------------------------------------------------
  // Основной шаг
  // -------------------------------------------------------------------------

  void step(double dt) {
    if (phase == MatchPhase.finished) return;
    tick++;

    if (phase == MatchPhase.countdown) {
      phaseTime -= dt;
      if (phaseTime <= 0) {
        phase = MatchPhase.running;
        phaseTime = 0;
        matchTime = 0;
        _lastZoneStage = 0;
      }
      return;
    }

    matchTime += dt;
    final z = zoneNow;
    if (z.stage != _lastZoneStage) {
      _lastZoneStage = z.stage;
      events.add(ZoneEvent(z.stage));
    }

    _updateBots(dt);
    _updateRespawns();

    for (final p in players.values) {
      if (!p.alive) continue;
      _stepPlayer(p, dt, z);
    }

    _stepBullets(dt);
    _updatePickups();
    _checkVictory();
  }

  void _stepPlayer(SimPlayer p, double dt, ZoneSample z) {
    p.fireCooldown = math.max(0, p.fireCooldown - dt);
    p.dashCooldown = math.max(0, p.dashCooldown - dt);
    p.dashTime = math.max(0, p.dashTime - dt);
    p.speedTime = math.max(0, p.speedTime - dt);
    p.ghostTime = math.max(0, p.ghostTime - dt);
    p.radarTime = math.max(0, p.radarTime - dt);
    p.aim = p.input.aim;

    final def = p.weaponDef;
    if (p.reloadTimer > 0) {
      p.reloadTimer -= dt;
      if (p.reloadTimer <= 0) {
        p.reloadTimer = 0;
        p.ammo = def.magSize;
      }
    } else if (p.input.reload) {
      if (p.ammo < def.magSize) {
        p.reloadTimer = def.reloadTime;
      }
    } else if (p.input.fire) {
      _tryShoot(p);
    }

    if (p.input.dash && p.dashCooldown <= 0) {
      p.dashTime = 0.17;
      p.dashCooldown = 2.6;
    }

    var mx = p.input.moveX;
    var my = p.input.moveY;
    final mag = math.sqrt(mx * mx + my * my);
    if (mag > 1) {
      mx /= mag;
      my /= mag;
    }
    final speed =
        kBaseSpeed *
        (p.speedTime > 0 ? 1.32 : 1.0) *
        (p.dashTime > 0 ? 3.05 : 1.0);
    final old = p.pos;
    p.pos = maze.moveCircle(p.pos, Offset(mx, my) * speed * dt, kPlayerRadius);
    p.vx = (p.pos.dx - old.dx) / dt;
    p.vy = (p.pos.dy - old.dy) / dt;

    _collectPickups(p);

    if (!z.contains(p.pos.dx, p.pos.dy)) {
      _damage(p, z.damage * dt, null, 0, silent: true);
    }
  }

  void _updateBots(double dt) {
    for (final p in players.values) {
      if (!p.alive || !p.isBot) continue;
      _brains[p.id]?.update(this, p, dt);
    }
  }

  // -------------------------------------------------------------------------
  // Возрождение
  // -------------------------------------------------------------------------

  bool _hasLivingAlly(SimPlayer p) {
    if (!teams || p.team < 0) return false;
    for (final other in players.values) {
      if (other.id != p.id && other.team == p.team && other.alive) return true;
    }
    return false;
  }

  SimPlayer? _livingAllyOf(SimPlayer p) {
    if (!teams || p.team < 0) return null;
    for (final other in players.values) {
      if (other.id != p.id && other.team == p.team && other.alive) {
        return other;
      }
    }
    return null;
  }

  void _updateRespawns() {
    if (!respawn || !teams) return;
    for (final p in players.values) {
      if (p.alive || p.respawnAt <= 0) continue;
      if (matchTime < p.respawnAt) continue;
      if (!_hasLivingAlly(p)) {
        p.respawnAt = 0;
        continue;
      }
      _respawnPlayer(p);
    }
  }

  void _respawnPlayer(SimPlayer p) {
    final ally = _livingAllyOf(p);
    final z = zoneNow;
    p.pos = ally != null ? _respawnPointNear(ally.pos, z) : _safeSpawnForJoin();
    p.alive = true;
    p.respawnAt = 0;
    p.deathTime = 0;
    p.hp = kMaxHp;
    p.shield = 0;
    p.weaponIndex = WeaponId.pistol.index;
    p.ammo = weaponByIndex(p.weaponIndex).magSize;
    p.fireCooldown = 0;
    p.reloadTimer = 0;
    p.dashCooldown = 0;
    p.dashTime = 0;
    p.speedTime = 0;
    p.ghostTime = 0;
    p.radarTime = 0;
    p.vx = 0;
    p.vy = 0;
    events.add(RespawnEvent(p.id));
  }

  Offset _respawnPointNear(Offset anchor, ZoneSample z) {
    for (var i = 0; i < 90; i++) {
      final a = rng.nextDouble() * math.pi * 2;
      final r = 52 + rng.nextDouble() * 92;
      final pos = anchor + Offset(math.cos(a) * r, math.sin(a) * r);
      if (!z.contains(pos.dx, pos.dy)) continue;
      if (!maze.isOpenWorld(pos.dx, pos.dy)) continue;
      return pos;
    }
    if (z.contains(anchor.dx, anchor.dy) &&
        maze.isOpenWorld(anchor.dx, anchor.dy)) {
      return anchor;
    }
    return _safeSpawnForJoin();
  }

  void _tryShoot(SimPlayer p) {
    final def = p.weaponDef;
    if (p.fireCooldown > 0 || p.reloadTimer > 0) return;
    if (p.ammo <= 0) {
      p.reloadTimer = def.reloadTime;
      return;
    }
    p.ammo--;
    p.fireCooldown = def.fireInterval;
    for (var i = 0; i < def.pellets; i++) {
      final angle = p.aim + (rng.nextDouble() - 0.5) * def.spread * 2;
      final sx = p.pos.dx + math.cos(angle) * (kPlayerRadius + 7);
      final sy = p.pos.dy + math.sin(angle) * (kPlayerRadius + 7);
      bullets.add(
        SimBullet(
          x: sx,
          y: sy,
          vx: math.cos(angle) * def.bulletSpeed,
          vy: math.sin(angle) * def.bulletSpeed,
          ownerId: p.id,
          damage: def.damage,
          life: def.range / def.bulletSpeed,
          weaponIndex: def.id.index,
        ),
      );
    }
    if (p.ammo <= 0) {
      p.reloadTimer = def.reloadTime;
    }
  }

  void _stepBullets(double dt) {
    for (var i = bullets.length - 1; i >= 0; i--) {
      final b = bullets[i];
      b.life -= dt;
      if (b.life <= 0) {
        bullets.removeAt(i);
        continue;
      }
      final total = Offset(b.vx, b.vy) * dt;
      final steps = (total.distance / 8).ceil().clamp(1, 24);
      final sdx = total.dx / steps;
      final sdy = total.dy / steps;
      var dead = false;
      for (var s = 0; s < steps; s++) {
        final nx = b.x + sdx;
        final ny = b.y + sdy;
        if (maze.circleHitsWall(nx, ny, 2)) {
          dead = true;
          break;
        }
        b.x = nx;
        b.y = ny;
        for (final p in players.values) {
          if (!p.alive || p.id == b.ownerId) continue;
          final shooter = players[b.ownerId];
          if (!friendlyFire &&
              shooter != null &&
              shooter.team >= 0 &&
              p.team == shooter.team) {
            continue;
          }
          final dx = p.pos.dx - b.x;
          final dy = p.pos.dy - b.y;
          final rr = kPlayerRadius + 3;
          if (dx * dx + dy * dy <= rr * rr) {
            final shotAngle = math.atan2(b.vy, b.vx);
            final attacker = players[b.ownerId];
            _damage(p, b.damage, attacker, shotAngle);
            dead = true;
            break;
          }
        }
        if (dead) break;
      }
      if (dead) bullets.removeAt(i);
    }
  }

  void _damage(
    SimPlayer victim,
    double amount,
    SimPlayer? attacker,
    double angle, {
    bool silent = false,
  }) {
    if (!victim.alive || amount <= 0) return;
    var remaining = amount;
    if (victim.shield > 0) {
      final absorbed = math.min(victim.shield, remaining);
      victim.shield -= absorbed;
      remaining -= absorbed;
    }
    victim.hp -= remaining;
    if (attacker != null) {
      attacker.damageDealt += amount;
    }
    if (!silent) {
      events.add(DamageEvent(victim.id, attacker?.id ?? -1, amount, angle));
    }
    if (victim.hp <= 0) {
      _kill(victim, attacker);
    }
  }

  void _kill(SimPlayer victim, SimPlayer? attacker) {
    if (!victim.alive) return;
    victim.alive = false;
    victim.hp = 0;
    victim.deathTime = matchTime;
    if (attacker != null && attacker.id != victim.id) {
      attacker.kills++;
    }
    events.add(KillEvent(attacker?.id ?? -1, victim.id, victim.weaponIndex));

    final dropType = _pickupForWeapon(victim.weaponIndex);
    if (dropType != null) {
      _spawnPickupAt(dropType, victim.pos, temporary: true);
    }
    if (rng.nextDouble() < 0.34) {
      _spawnPickupAt(PickupType.medkit, victim.pos, temporary: true);
    }

    if (respawn && teams) {
      if (_hasLivingAlly(victim)) {
        victim.respawnAt = matchTime + kRespawnDelay;
      } else {
        // Живых союзников не осталось — возрождение невозможно,
        // сбрасываем таймеры у всех павших членов команды.
        victim.respawnAt = 0;
        for (final ally in players.values) {
          if (ally.id != victim.id && ally.team == victim.team && !ally.alive) {
            ally.respawnAt = 0;
          }
        }
      }
    }
  }

  void _collectPickups(SimPlayer p) {
    for (final pk in pickups) {
      if (!pk.active) continue;
      if ((pk.pos - p.pos).distance > kPlayerRadius + 20) continue;
      final type = pk.type;
      final def = pickupByIndex(type.index);
      var consumed = false;
      if (def.weapon != null) {
        final weaponIndex = def.weapon!.index;
        final wd = weaponByIndex(weaponIndex);
        if (p.weaponIndex != weaponIndex || p.ammo < wd.magSize) {
          p.weaponIndex = weaponIndex;
          p.ammo = wd.magSize;
          p.reloadTimer = 0;
          p.fireCooldown = 0;
          consumed = true;
        }
      } else {
        switch (type) {
          case PickupType.medkit:
            if (p.hp < kMaxHp) {
              p.hp = math.min(kMaxHp, p.hp + 45);
              consumed = true;
            }
          case PickupType.shield:
            if (p.shield < kMaxShield) {
              p.shield = math.min(kMaxShield, p.shield + 40);
              consumed = true;
            }
          case PickupType.speed:
            p.speedTime = 12;
            consumed = true;
          case PickupType.radar:
            p.radarTime = 10;
            consumed = true;
          case PickupType.ghost:
            p.ghostTime = 7;
            consumed = true;
          case PickupType.smg:
          case PickupType.shotgun:
          case PickupType.rifle:
          case PickupType.sniper:
            consumed = false;
        }
      }
      if (consumed) {
        pk.active = false;
        pk.respawnAt = matchTime + 22;
        events.add(PickupEvent(p.id, type.index));
      }
    }
  }

  void _updatePickups() {
    for (var i = pickups.length - 1; i >= 0; i--) {
      final pk = pickups[i];
      if (!pk.active) {
        if (pk.temporary) {
          pickups.removeAt(i);
        } else if (matchTime >= pk.respawnAt) {
          pk.pos = maze.randomFloorPoint(rng);
          pk.active = true;
        }
      }
    }
  }

  void _checkVictory() {
    if (phase != MatchPhase.running || _resultsReady) return;
    if (players.isEmpty) return;

    final aliveTeams = <int>{
      for (final p in players.values)
        if (p.alive || p.respawnAt > 0) p.team,
    };
    if (teams) {
      if (aliveTeams.length > 1) return;
    } else {
      if (aliveCount > 1) return;
    }

    phase = MatchPhase.finished;
    endTime = matchTime;
    _resultsReady = true;
    final rows = <ResultRow>[];
    if (teams) {
      final teamsMap = <int, List<SimPlayer>>{};
      for (final p in players.values) {
        teamsMap.putIfAbsent(p.team, () => <SimPlayer>[]).add(p);
      }
      final teamIds = teamsMap.keys.toList();
      if (aliveTeams.length == 1) {
        winTeam = aliveTeams.first;
      } else if (teamIds.isNotEmpty) {
        teamIds.sort((a, b) => _teamSurvival(b).compareTo(_teamSurvival(a)));
        winTeam = teamIds.first;
      }
      teamIds.sort((a, b) {
        if (a == winTeam) return -1;
        if (b == winTeam) return 1;
        final bySurvival = _teamSurvival(b).compareTo(_teamSurvival(a));
        if (bySurvival != 0) return bySurvival;
        return _teamKills(b).compareTo(_teamKills(a));
      });
      for (var i = 0; i < teamIds.length; i++) {
        final team = teamIds[i];
        final members = teamsMap[team]!
          ..sort((a, b) {
            if (a.alive != b.alive) return a.alive ? -1 : 1;
            if (a.kills != b.kills) return b.kills.compareTo(a.kills);
            return b.damageDealt.compareTo(a.damageDealt);
          });
        for (final p in members) {
          rows.add(
            ResultRow(
              id: p.id,
              placement: i + 1,
              kills: p.kills,
              damage: p.damageDealt,
              survived: p.alive ? endTime : p.deathTime,
              team: team,
            ),
          );
        }
      }
    } else {
      winTeam = -1;
      final ordered = players.values.toList()
        ..sort((a, b) {
          if (a.alive != b.alive) return a.alive ? -1 : 1;
          return b.deathTime.compareTo(a.deathTime);
        });
      for (var i = 0; i < ordered.length; i++) {
        final p = ordered[i];
        rows.add(
          ResultRow(
            id: p.id,
            placement: i + 1,
            kills: p.kills,
            damage: p.damageDealt,
            survived: p.alive ? endTime : p.deathTime,
          ),
        );
      }
    }
    results = rows;
  }

  double _teamSurvival(int team) {
    var best = 0.0;
    for (final p in players.values) {
      if (p.team != team) continue;
      final value = p.alive ? endTime : p.deathTime;
      if (value > best) best = value;
    }
    return best;
  }

  int _teamKills(int team) {
    var total = 0;
    for (final p in players.values) {
      if (p.team == team) total += p.kills;
    }
    return total;
  }

  List<GameEvent> takeEvents() {
    if (events.isEmpty) return const <GameEvent>[];
    final copy = List<GameEvent>.of(events);
    events.clear();
    return copy;
  }

  // -------------------------------------------------------------------------
  // Снимок состояния для конкретного игрока (туман войны на сервере)
  // -------------------------------------------------------------------------

  bool _canSee(
    SimPlayer? observer,
    Offset target, {
    double extra = 0,
    bool ghost = false,
    bool spectator = false,
  }) {
    if (spectator || observer == null) return true;
    final d = (target - observer.pos).distance;
    if (d > kVisionRadius + extra) return false;
    if (ghost && d > kGhostVisibleRadius) return false;
    return maze.lineOfSight(
      observer.pos.dx,
      observer.pos.dy,
      target.dx,
      target.dy,
    );
  }

  RadarPing? _radarFor(SimPlayer? observer) {
    if (observer == null || !observer.alive || observer.radarTime <= 0) {
      return null;
    }
    SimPlayer? nearest;
    var best = double.infinity;
    for (final p in players.values) {
      if (!p.alive || p.id == observer.id) continue;
      if (observer.team >= 0 && p.team == observer.team) continue;
      final d = (p.pos - observer.pos).distance;
      if (d < best) {
        best = d;
        nearest = p;
      }
    }
    if (nearest == null) return null;
    final a = math.atan2(
      nearest.pos.dy - observer.pos.dy,
      nearest.pos.dx - observer.pos.dx,
    );
    return RadarPing(a, best);
  }

  SimPlayer? _spectateTargetFor(int observerId, int spectateId) {
    final chosen = players[spectateId];
    if (chosen != null && chosen.alive && chosen.id != observerId) {
      return chosen;
    }
    SimPlayer? fallback;
    for (final p in players.values) {
      if (!p.alive || p.id == observerId) continue;
      if (fallback == null || p.id < fallback.id) fallback = p;
    }
    return fallback;
  }

  Snapshot buildSnapshot(
    int observerId,
    List<GameEvent> tickEvents, {
    int spectateId = 0,
  }) {
    final observer = players[observerId];
    final dead = observer == null || !observer.alive;
    final target = dead ? _spectateTargetFor(observerId, spectateId) : null;
    final fogSpectator = dead && deathVision == 0 && target != null;
    final viewer = fogSpectator ? target : observer;
    final spectator = dead && !fogSpectator;
    final z = zoneNow;

    final playerSnaps = <PlayerSnapshot>[];
    for (final p in players.values) {
      final isSelf = p.id == observerId;
      final ally =
          viewer != null &&
          viewer.team >= 0 &&
          p.team == viewer.team &&
          p.id != viewer.id;
      final visible =
          isSelf ||
          ally ||
          (p.alive &&
              _canSee(
                viewer,
                p.pos,
                ghost: p.ghostTime > 0,
                spectator: spectator,
              ));
      if (!visible) continue;
      playerSnaps.add(
        PlayerSnapshot(
          id: p.id,
          x: p.pos.dx,
          y: p.pos.dy,
          aim: p.aim,
          hp: p.hp,
          shield: p.shield,
          alive: p.alive,
          weapon: p.weaponIndex,
          ammo: p.ammo,
          speedTime: p.speedTime,
          ghostTime: p.ghostTime,
          dashCooldown: p.dashCooldown,
          reloading: p.reloading,
          team: p.team,
          reloadRemaining: p.reloadTimer,
        ),
      );
    }

    final bulletSnaps = <BulletSnapshot>[];
    for (final b in bullets) {
      if (!spectator &&
          !_canSee(viewer, Offset(b.x, b.y), extra: 80, spectator: false)) {
        continue;
      }
      bulletSnaps.add(BulletSnapshot(b.x, b.y, b.vx, b.vy, b.weaponIndex));
    }

    final pickupSnaps = <PickupSnapshot>[];
    for (final pk in pickups) {
      if (!pk.active) continue;
      if (!spectator && !_canSee(viewer, pk.pos, extra: 30, spectator: false)) {
        continue;
      }
      pickupSnaps.add(
        PickupSnapshot(pk.id, pk.pos.dx, pk.pos.dy, pk.type.index),
      );
    }

    final scoreboard =
        players.values
            .map((p) => ScoreRow(p.id, p.kills, p.alive, p.damageDealt, p.team))
            .toList()
          ..sort((a, b) {
            if (a.alive != b.alive) return a.alive ? -1 : 1;
            if (a.kills != b.kills) return b.kills.compareTo(a.kills);
            return b.damage.compareTo(a.damage);
          });

    final names = <int, String>{for (final p in players.values) p.id: p.name};

    final visibleEvents = <GameEvent>[];
    for (final e in tickEvents) {
      switch (e) {
        case KillEvent():
          visibleEvents.add(e);
        case ZoneEvent():
          visibleEvents.add(e);
        case JoinEvent():
          visibleEvents.add(e);
        case LeaveEvent():
          visibleEvents.add(e);
        case RespawnEvent():
          visibleEvents.add(e);
        case DamageEvent d:
          if (spectator ||
              (viewer != null &&
                  (d.victimId == viewer.id || d.attackerId == viewer.id))) {
            visibleEvents.add(e);
          }
        case PickupEvent u:
          if (spectator || (viewer != null && u.playerId == viewer.id)) {
            visibleEvents.add(e);
          }
      }
    }

    return Snapshot(
      tick: tick,
      phase: phase,
      phaseTime: phase == MatchPhase.countdown ? math.max(0, phaseTime) : 0,
      matchTime: matchTime,
      alivePlayers: aliveCount,
      totalPlayers: players.length,
      zone: ZoneSnapshot(z.center.dx, z.center.dy, z.radius),
      zoneShrinking: z.shrinking,
      zoneStage: z.stage,
      nextZoneEventIn: z.nextChangeIn,
      players: playerSnaps,
      bullets: bulletSnaps,
      pickups: pickupSnaps,
      scoreboard: scoreboard,
      results: results,
      names: names,
      events: visibleEvents,
      radar: _radarFor(observer),
      teams: teams,
      winTeam: winTeam,
      deathVision: deathVision,
      fogView: fogSpectator,
      spectateTarget: target?.id ?? 0,
      respawn: respawn,
      respawnRemaining: observer != null && !observer.alive
          ? math.max(0.0, observer.respawnAt - matchTime).toDouble()
          : 0,
    );
  }

  // -------------------------------------------------------------------------
  // API для ботов
  // -------------------------------------------------------------------------

  SimPlayer? findVisibleEnemy(SimPlayer me, double maxDist) {
    final limit = math.min(maxDist, kVisionRadius);
    SimPlayer? best;
    var bestDist = limit;
    for (final p in players.values) {
      if (!p.alive || p.id == me.id) continue;
      if (me.team >= 0 && p.team == me.team) continue;
      final d = (p.pos - me.pos).distance;
      if (d > bestDist) continue;
      if (p.ghostTime > 0 && d > kGhostVisibleRadius) continue;
      if (!maze.lineOfSight(me.pos.dx, me.pos.dy, p.pos.dx, p.pos.dy)) {
        continue;
      }
      best = p;
      bestDist = d;
    }
    return best;
  }

  Offset botObjective(SimPlayer me) {
    final z = zoneNow;
    if ((me.pos - z.center).distance > z.radius * 0.72) {
      final a = rng.nextDouble() * math.pi * 2;
      final r = z.radius * 0.32;
      return z.center + Offset(math.cos(a) * r, math.sin(a) * r);
    }
    SimPickup? best;
    var bestDist = 720.0;
    for (final pk in pickups) {
      if (!pk.active) continue;
      final d = (pk.pos - me.pos).distance;
      if (d < bestDist) {
        best = pk;
        bestDist = d;
      }
    }
    if (best != null && rng.nextDouble() < 0.72) {
      return best.pos;
    }
    for (var i = 0; i < 40; i++) {
      final a = rng.nextDouble() * math.pi * 2;
      final r = math.sqrt(rng.nextDouble()) * z.radius * 0.62;
      final p = z.center + Offset(math.cos(a) * r, math.sin(a) * r);
      if (maze.isOpenWorld(p.dx, p.dy)) return p;
    }
    return maze.randomFloorPoint(rng, center: z.center, radius: z.radius * 0.6);
  }
}

// ---------------------------------------------------------------------------
// ИИ ботов
// ---------------------------------------------------------------------------

class BotBrain {
  BotBrain(this.playerId, {required this.skill, required int seed})
    : _rng = math.Random(seed);

  final int playerId;
  final double skill;
  final math.Random _rng;

  double _think = 0;
  List<Offset> _path = const <Offset>[];
  int _pathIndex = 0;
  Offset? _objective;
  int? _enemyId;
  double _acquire = 0;
  double _strafeTimer = 0;
  double _strafeDir = 1;
  double _burst = 0;
  double _burstPause = 0;
  Offset _lastPos = Offset.zero;
  double _stuckCheck = 0;
  bool _dashWish = false;

  void update(GameSim sim, SimPlayer me, double dt) {
    if (!me.alive) return;
    _think -= dt;
    _strafeTimer -= dt;
    _burstPause = math.max(0, _burstPause - dt);
    _stuckCheck += dt;

    final def = me.weaponDef;
    final enemy = sim.findVisibleEnemy(me, kVisionRadius);
    if (enemy != null) {
      if (_enemyId != enemy.id) {
        _enemyId = enemy.id;
        _acquire =
            math.max(0.08, 0.55 - 0.22 * skill) + _rng.nextDouble() * 0.16;
      }
      _acquire -= dt;
      final dist = (enemy.pos - me.pos).distance;
      final lead = dist / def.bulletSpeed * 0.8;
      final predicted = enemy.pos + Offset(enemy.vx, enemy.vy) * lead;
      final desired = math.atan2(
        predicted.dy - me.pos.dy,
        predicted.dx - me.pos.dx,
      );
      final noise = (0.018 + 0.052 / skill) * (_rng.nextDouble() * 2 - 1);
      me.aim = desired + noise;

      if (_strafeTimer <= 0) {
        _strafeDir = _rng.nextBool() ? 1 : -1;
        _strafeTimer = 0.5 + _rng.nextDouble() * 0.85;
      }
      final perp = desired + math.pi / 2 * _strafeDir;
      var forward = 0.0;
      if (dist > 340) {
        forward = 1.0;
      } else if (dist < 155) {
        forward = -1.0;
      }
      var mx = math.cos(desired) * forward + math.cos(perp) * 0.85;
      var my = math.sin(desired) * forward + math.sin(perp) * 0.85;

      final z = sim.zoneNow;
      if (!z.contains(me.pos.dx, me.pos.dy)) {
        final toCenter = z.center - me.pos;
        final len = math.max(1.0, toCenter.distance);
        mx += toCenter.dx / len * 1.5;
        my += toCenter.dy / len * 1.5;
      }
      final mag = math.sqrt(mx * mx + my * my);
      if (mag > 1) {
        mx /= mag;
        my /= mag;
      }

      var fire = false;
      if (_acquire <= 0 && me.ammo > 0) {
        if (def.automatic) {
          if (_burstPause <= 0) {
            if (_burst <= 0) {
              _burst = 0.35 + _rng.nextDouble() * 0.45;
            }
            _burst -= dt;
            fire = true;
            if (_burst <= 0) {
              _burst = 0;
              _burstPause = 0.18 + _rng.nextDouble() * 0.3;
            }
          }
        } else if (_burstPause <= 0) {
          fire = true;
          _burstPause = def.fireInterval + 0.18 + _rng.nextDouble() * 0.3;
        }
      }

      if (me.dashCooldown <= 0 && me.hp < 52 && _rng.nextDouble() < 0.02) {
        _dashWish = true;
      }

      me.input = InputState(
        moveX: mx,
        moveY: my,
        aim: me.aim,
        fire: fire,
        dash: _dashWish,
        reload: me.ammo == 0,
      );
      _dashWish = false;
      _objective = null;
      _path = const <Offset>[];
      return;
    }

    _enemyId = null;
    _acquire = 0;

    if (_think <= 0 ||
        _objective == null ||
        (_objective! - me.pos).distance < 70) {
      _objective = sim.botObjective(me);
      _path = sim.maze.findPath(me.pos, _objective!);
      _pathIndex = 0;
      _think = 0.9 + _rng.nextDouble() * 1.2;
    }

    while (_pathIndex < _path.length &&
        (_path[_pathIndex] - me.pos).distance < 42) {
      _pathIndex++;
    }
    var target = _pathIndex < _path.length ? _path[_pathIndex] : _objective!;
    var dir = target - me.pos;
    if (dir.distance < 2) {
      dir = Offset(math.cos(me.aim), math.sin(me.aim));
    }
    final len = math.max(0.001, dir.distance);
    var mx = dir.dx / len;
    var my = dir.dy / len;

    final z = sim.zoneNow;
    if (!z.contains(me.pos.dx, me.pos.dy)) {
      final toCenter = z.center - me.pos;
      final l = math.max(1.0, toCenter.distance);
      mx = mx * 0.35 + toCenter.dx / l;
      my = my * 0.35 + toCenter.dy / l;
    }

    final mag = math.sqrt(mx * mx + my * my);
    if (mag > 1) {
      mx /= mag;
      my /= mag;
    }

    if (_stuckCheck > 0.9) {
      if ((me.pos - _lastPos).distance < 6) {
        _objective = null;
        _think = 0;
        _path = const <Offset>[];
      }
      _lastPos = me.pos;
      _stuckCheck = 0;
    }

    me.aim = math.atan2(my, mx);
    me.input = InputState(
      moveX: mx,
      moveY: my,
      aim: me.aim,
      reload: me.ammo < def.magSize * 0.35,
    );
  }
}

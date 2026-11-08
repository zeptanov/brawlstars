import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../game/constants.dart';

enum MatchPhase { countdown, running, finished }

/// Ввод игрока, отправляется на сервер 30 раз в секунду.
@immutable
class InputState {
  const InputState({
    this.moveX = 0,
    this.moveY = 0,
    this.aim = 0,
    this.fire = false,
    this.dash = false,
    this.reload = false,
  });

  final double moveX;
  final double moveY;
  final double aim;
  final bool fire;
  final bool dash;
  final bool reload;

  static const InputState idle = InputState();

  Map<String, dynamic> toJson() => <String, dynamic>{
        'mx': double.parse(moveX.toStringAsFixed(2)),
        'my': double.parse(moveY.toStringAsFixed(2)),
        'a': double.parse(aim.toStringAsFixed(3)),
        if (fire) 'f': 1,
        if (dash) 'd': 1,
        if (reload) 'r': 1,
      };

  factory InputState.fromJson(Map<String, dynamic> j) => InputState(
        moveX: _d(j['mx']),
        moveY: _d(j['my']),
        aim: _d(j['a']),
        fire: (j['f'] as num?)?.toInt() == 1,
        dash: (j['d'] as num?)?.toInt() == 1,
        reload: (j['r'] as num?)?.toInt() == 1,
      );
}

double _d(Object? v, [double fallback = 0]) =>
    v is num ? v.toDouble() : fallback;

int _i(Object? v, [int fallback = 0]) =>
    v is num ? v.toInt() : fallback;

class PlayerSnapshot {
  const PlayerSnapshot({
    required this.id,
    required this.x,
    required this.y,
    required this.aim,
    required this.hp,
    required this.shield,
    required this.alive,
    required this.weapon,
    required this.ammo,
    required this.speedTime,
    required this.ghostTime,
    required this.dashCooldown,
    required this.reloading,
    this.team = -1,
    this.reloadRemaining = 0,
  });

  final int id;
  final double x;
  final double y;
  final double aim;
  final double hp;
  final double shield;
  final bool alive;
  final int weapon;
  final int ammo;
  final double speedTime;
  final double ghostTime;
  final double dashCooldown;
  final bool reloading;
  final int team;
  final double reloadRemaining;

  List<Object?> toList() => <Object?>[
        id,
        (x * 10).round(),
        (y * 10).round(),
        (aim * 100).round(),
        hp.round(),
        shield.round(),
        alive ? 1 : 0,
        weapon,
        ammo,
        (speedTime * 10).round(),
        (ghostTime * 10).round(),
        (dashCooldown * 100).round(),
        reloading ? 1 : 0,
        team,
        (reloadRemaining * 100).round(),
      ];

  factory PlayerSnapshot.fromList(List<Object?> l) => PlayerSnapshot(
        id: _i(l[0]),
        x: _i(l[1]) / 10.0,
        y: _i(l[2]) / 10.0,
        aim: _i(l[3]) / 100.0,
        hp: _d(l[4]),
        shield: _d(l[5]),
        alive: _i(l[6]) == 1,
        weapon: _i(l[7]),
        ammo: _i(l[8]),
        speedTime: _i(l[9]) / 10.0,
        ghostTime: _i(l[10]) / 10.0,
        dashCooldown: _i(l[11]) / 100.0,
        reloading: _i(l[12]) == 1,
        team: l.length > 13 ? _i(l[13], -1) : -1,
        reloadRemaining: l.length > 14 ? _i(l[14]) / 100.0 : 0,
      );
}

class BulletSnapshot {
  const BulletSnapshot(this.x, this.y, this.vx, this.vy, this.weapon);
  final double x;
  final double y;
  final double vx;
  final double vy;
  final int weapon;

  List<Object?> toList() =>
      <Object?>[(x * 10).round(), (y * 10).round(), vx.round(), vy.round(), weapon];

  factory BulletSnapshot.fromList(List<Object?> l) => BulletSnapshot(
        _i(l[0]) / 10.0,
        _i(l[1]) / 10.0,
        _d(l[2]),
        _d(l[3]),
        _i(l[4]),
      );
}

class PickupSnapshot {
  const PickupSnapshot(this.id, this.x, this.y, this.type);
  final int id;
  final double x;
  final double y;
  final int type;

  List<Object?> toList() =>
      <Object?>[id, (x * 10).round(), (y * 10).round(), type];

  factory PickupSnapshot.fromList(List<Object?> l) => PickupSnapshot(
        _i(l[0]),
        _i(l[1]) / 10.0,
        _i(l[2]) / 10.0,
        _i(l[3]),
      );
}

class ZoneSnapshot {
  const ZoneSnapshot(this.x, this.y, this.radius);
  final double x;
  final double y;
  final double radius;

  bool contains(double px, double py, {double margin = 0}) {
    final dx = px - x;
    final dy = py - y;
    return dx * dx + dy * dy <= (radius + margin) * (radius + margin);
  }

  List<Object?> toList() => <Object?>[x.round(), y.round(), radius.round()];

  factory ZoneSnapshot.fromList(List<Object?> l) => ZoneSnapshot(
        _d(l[0]),
        _d(l[1]),
        _d(l[2]),
      );
}

class ScoreRow {
  const ScoreRow(this.id, this.kills, this.alive, this.damage, [this.team = -1]);
  final int id;
  final int kills;
  final bool alive;
  final double damage;
  final int team;

  List<Object?> toList() =>
      <Object?>[id, kills, alive ? 1 : 0, damage.round(), team];

  factory ScoreRow.fromList(List<Object?> l) => ScoreRow(
        _i(l[0]),
        _i(l[1]),
        _i(l[2]) == 1,
        _d(l[3]),
        l.length > 4 ? _i(l[4], -1) : -1,
      );
}

class ResultRow {
  const ResultRow({
    required this.id,
    required this.placement,
    required this.kills,
    required this.damage,
    required this.survived,
    this.team = -1,
  });

  final int id;
  final int placement;
  final int kills;
  final double damage;
  final double survived;
  final int team;

  List<Object?> toList() => <Object?>[
        id,
        placement,
        kills,
        damage.round(),
        (survived * 10).round(),
        team,
      ];

  factory ResultRow.fromList(List<Object?> l) => ResultRow(
        id: _i(l[0]),
        placement: _i(l[1]),
        kills: _i(l[2]),
        damage: _d(l[3]),
        survived: _i(l[4]) / 10.0,
        team: l.length > 5 ? _i(l[5], -1) : -1,
      );
}

class RadarPing {
  const RadarPing(this.angle, this.distance);
  final double angle;
  final double distance;

  List<Object?> toList() => <Object?>[(angle * 1000).round(), distance.round()];

  factory RadarPing.fromList(List<Object?> l) =>
      RadarPing(_i(l[0]) / 1000.0, _d(l[1]));
}

class Snapshot {
  const Snapshot({
    required this.tick,
    required this.phase,
    required this.phaseTime,
    required this.matchTime,
    required this.alivePlayers,
    required this.totalPlayers,
    required this.zone,
    required this.zoneShrinking,
    required this.zoneStage,
    required this.nextZoneEventIn,
    required this.players,
    required this.bullets,
    required this.pickups,
    required this.scoreboard,
    required this.results,
    required this.names,
    required this.events,
    required this.radar,
    this.teams = false,
    this.winTeam = -1,
    this.deathVision = 1,
    this.fogView = false,
    this.spectateTarget = 0,
    this.respawn = false,
    this.respawnRemaining = 0,
  });

  final int tick;
  final MatchPhase phase;
  final double phaseTime;
  final double matchTime;
  final int alivePlayers;
  final int totalPlayers;
  final ZoneSnapshot zone;
  final bool zoneShrinking;
  final int zoneStage;
  final double nextZoneEventIn;
  final List<PlayerSnapshot> players;
  final List<BulletSnapshot> bullets;
  final List<PickupSnapshot> pickups;
  final List<ScoreRow> scoreboard;
  final List<ResultRow> results;
  final Map<int, String> names;
  final List<GameEvent> events;
  final RadarPing? radar;
  final bool teams;
  final int winTeam;
  final int deathVision;
  final bool fogView;
  final int spectateTarget;
  final bool respawn;
  final double respawnRemaining;

  PlayerSnapshot? playerById(int id) {
    for (final p in players) {
      if (p.id == id) return p;
    }
    return null;
  }

  String nameOf(int id) => names[id] ?? 'Игрок $id';

  ScoreRow? scoreOf(int id) {
    for (final row in scoreboard) {
      if (row.id == id) return row;
    }
    return null;
  }

  int teamOf(int id) => scoreOf(id)?.team ?? -1;

  ResultRow? resultOf(int id) {
    for (final r in results) {
      if (r.id == id) return r;
    }
    return null;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        't': 's',
        'k': tick,
        'ph': phase.index,
        'pt': double.parse(phaseTime.toStringAsFixed(2)),
        'tm': double.parse(matchTime.toStringAsFixed(1)),
        'al': alivePlayers,
        'tot': totalPlayers,
        'z': zone.toList(),
        'zs': zoneShrinking ? 1 : 0,
        'zst': zoneStage,
        'zn': double.parse(nextZoneEventIn.toStringAsFixed(1)),
        'p': players.map((p) => p.toList()).toList(),
        'b': bullets.map((b) => b.toList()).toList(),
        'u': pickups.map((p) => p.toList()).toList(),
        'sc': scoreboard.map((s) => s.toList()).toList(),
        'nm': names.entries.map((e) => <Object?>[e.key, e.value]).toList(),
        'e': events.map((e) => e.toList()).toList(),
        if (results.isNotEmpty) 'res': results.map((r) => r.toList()).toList(),
        if (radar != null) 'rd': radar!.toList(),
        if (teams) 'tms': 1,
        if (winTeam >= 0) 'wt': winTeam,
        'dv': deathVision,
        if (fogView) 'fog': 1,
        if (spectateTarget > 0) 'sp': spectateTarget,
        if (respawn) 'rs': 1,
        if (respawnRemaining > 0)
          'rt': double.parse(respawnRemaining.toStringAsFixed(1)),
      };

  factory Snapshot.fromJson(Map<String, dynamic> j) {
    final names = <int, String>{};
    final rawNames = j['nm'];
    if (rawNames is List) {
      for (final e in rawNames) {
        if (e is List && e.length >= 2) {
          names[_i(e[0])] = '${e[1]}';
        }
      }
    }
    final results = <ResultRow>[];
    final rawRes = j['res'];
    if (rawRes is List) {
      for (final e in rawRes) {
        if (e is List) results.add(ResultRow.fromList(e.cast<Object?>()));
      }
    }
    final events = <GameEvent>[];
    final rawEvents = j['e'];
    if (rawEvents is List) {
      for (final e in rawEvents) {
        if (e is List) {
          final ev = GameEvent.fromList(e.cast<Object?>());
          if (ev != null) events.add(ev);
        }
      }
    }
    final zones = (j['z'] as List?)?.cast<Object?>() ?? <Object?>[0, 0, 1];
    return Snapshot(
      tick: _i(j['k']),
      phase: MatchPhase.values[_i(j['ph']).clamp(0, 2)],
      phaseTime: _d(j['pt']),
      matchTime: _d(j['tm']),
      alivePlayers: _i(j['al']),
      totalPlayers: _i(j['tot']),
      zone: ZoneSnapshot.fromList(zones),
      zoneShrinking: _i(j['zs']) == 1,
      zoneStage: _i(j['zst']),
      nextZoneEventIn: _d(j['zn']),
      players: _list(j['p']).map(PlayerSnapshot.fromList).toList(),
      bullets: _list(j['b']).map(BulletSnapshot.fromList).toList(),
      pickups: _list(j['u']).map(PickupSnapshot.fromList).toList(),
      scoreboard: _list(j['sc']).map(ScoreRow.fromList).toList(),
      results: results,
      names: names,
      events: events,
      radar: j['rd'] is List
          ? RadarPing.fromList((j['rd'] as List).cast<Object?>())
          : null,
      teams: _i(j['tms']) == 1,
      winTeam: _i(j['wt'], -1),
      deathVision: _i(j['dv'], 1),
      fogView: _i(j['fog']) == 1,
      spectateTarget: _i(j['sp']),
      respawn: _i(j['rs']) == 1,
      respawnRemaining: _d(j['rt']),
    );
  }

  static List<List<Object?>> _list(Object? value) {
    if (value is! List) return const <List<Object?>>[];
    return value
        .whereType<List>()
        .map((e) => e.cast<Object?>())
        .toList(growable: false);
  }
}

// ---------------------------------------------------------------------------
// События матча
// ---------------------------------------------------------------------------

sealed class GameEvent {
  const GameEvent();

  List<Object?> toList();

  static GameEvent? fromList(List<Object?> l) {
    if (l.isEmpty) return null;
    switch ('${l[0]}') {
      case 'k':
        return KillEvent(_i(l[1]), _i(l[2]), _i(l[3]));
      case 'd':
        return DamageEvent(_i(l[1]), _i(l[2]), _d(l[3]), _d(l[4]));
      case 'u':
        return PickupEvent(_i(l[1]), _i(l[2]));
      case 'j':
        return JoinEvent(_i(l[1]));
      case 'r':
        return RespawnEvent(_i(l[1]));
      case 'x':
        return LeaveEvent(_i(l[1]));
      case 'z':
        return ZoneEvent(_i(l[1]));
    }
    return null;
  }
}

class KillEvent extends GameEvent {
  const KillEvent(this.killerId, this.victimId, this.weapon);
  final int killerId;
  final int victimId;
  final int weapon;

  @override
  List<Object?> toList() => <Object?>['k', killerId, victimId, weapon];
}

class DamageEvent extends GameEvent {
  const DamageEvent(this.victimId, this.attackerId, this.amount, this.angle);
  final int victimId;
  final int attackerId;
  final double amount;
  final double angle;

  @override
  List<Object?> toList() =>
      <Object?>['d', victimId, attackerId, amount.round(), angle];
}

class PickupEvent extends GameEvent {
  const PickupEvent(this.playerId, this.type);
  final int playerId;
  final int type;

  @override
  List<Object?> toList() => <Object?>['u', playerId, type];
}

class JoinEvent extends GameEvent {
  const JoinEvent(this.playerId);
  final int playerId;

  @override
  List<Object?> toList() => <Object?>['j', playerId];
}

class LeaveEvent extends GameEvent {
  const LeaveEvent(this.playerId);
  final int playerId;

  @override
  List<Object?> toList() => <Object?>['x', playerId];
}

class RespawnEvent extends GameEvent {
  const RespawnEvent(this.playerId);
  final int playerId;

  @override
  List<Object?> toList() => <Object?>['r', playerId];
}

class ZoneEvent extends GameEvent {
  const ZoneEvent(this.stage);
  final int stage;

  @override
  List<Object?> toList() => <Object?>['z', stage];
}

// ---------------------------------------------------------------------------
// Лобби
// ---------------------------------------------------------------------------

class LobbyPlayer {
  const LobbyPlayer(this.id, this.name, this.isBot, [this.team = -1]);
  final int id;
  final String name;
  final bool isBot;
  final int team;

  List<Object?> toList() => <Object?>[id, name, isBot ? 1 : 0, team];

  factory LobbyPlayer.fromList(List<Object?> l) => LobbyPlayer(
        _i(l[0]),
        '${l[1]}',
        _i(l[2]) == 1,
        l.length > 3 ? _i(l[3], -1) : -1,
      );
}

class ChatLine {
  const ChatLine(this.authorId, this.author, this.text);
  final int authorId;
  final String author;
  final String text;

  List<Object?> toList() => <Object?>[authorId, author, text];

  factory ChatLine.fromList(List<Object?> l) =>
      ChatLine(_i(l[0]), '${l[1]}', '${l[2]}');
}

class LobbyState {
  const LobbyState({
    required this.roomName,
    required this.players,
    required this.hostId,
    required this.started,
    required this.paused,
    required this.botCount,
    required this.maxPlayers,
    required this.mapSize,
    required this.tempo,
    required this.skill,
    required this.chat,
    required this.allowPause,
    required this.code,
    this.teams = false,
    this.deathVision = 1,
    this.loot = 1,
    this.friendlyFire = false,
    this.respawn = false,
  });

  final String roomName;
  final List<LobbyPlayer> players;
  final int hostId;
  final bool started;
  final bool paused;
  final int botCount;
  final int maxPlayers;
  final int mapSize;
  final int tempo;
  final int skill;
  final List<ChatLine> chat;
  final bool allowPause;
  final String code;
  final bool teams;
  final int deathVision;
  final int loot;
  final bool friendlyFire;
  final bool respawn;

  factory LobbyState.fromJson(Map<String, dynamic> j) {
    final players = <LobbyPlayer>[];
    final raw = j['p'];
    if (raw is List) {
      for (final e in raw) {
        if (e is List) players.add(LobbyPlayer.fromList(e.cast<Object?>()));
      }
    }
    final chat = <ChatLine>[];
    final rawChat = j['chat'];
    if (rawChat is List) {
      for (final e in rawChat) {
        if (e is List) chat.add(ChatLine.fromList(e.cast<Object?>()));
      }
    }
    return LobbyState(
      roomName: '${j['room'] ?? 'Комната'}',
      players: players,
      hostId: _i(j['host']),
      started: _i(j['started']) == 1,
      paused: _i(j['paused']) == 1,
      botCount: _i(j['bots']),
      maxPlayers: _i(j['max'], kMaxPlayers),
      mapSize: _i(j['map'], kDefaultMapSize),
      tempo: _i(j['tempo'], 1),
      skill: _i(j['skill'], 1),
      chat: chat,
      allowPause: _i(j['canPause']) == 1,
      code: '${j['code'] ?? ''}',
      teams: _i(j['tms']) == 1,
      deathVision: _i(j['dv'], 1),
      loot: _i(j['loot'], 1),
      friendlyFire: _i(j['ff']) == 1,
      respawn: _i(j['rs']) == 1,
    );
  }
}

// ---------------------------------------------------------------------------
// Утилиты
// ---------------------------------------------------------------------------

double lerpDouble(double a, double b, double t) => a + (b - a) * t;

double angleLerp(double a, double b, double t) {
  var diff = (b - a) % (math.pi * 2);
  if (diff > math.pi) diff -= math.pi * 2;
  if (diff < -math.pi) diff += math.pi * 2;
  return a + diff * t;
}

double clampDouble(double v, double lo, double hi) =>
    v < lo ? lo : (v > hi ? hi : v);

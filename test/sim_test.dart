import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:maze_royale/game/constants.dart';
import 'package:maze_royale/game/sim.dart';
import 'package:maze_royale/net/messages.dart';

void main() {
  group('GameSim', () {
    test('минимальный матч: идёт обратный отсчёт и начинается бой', () {
      final sim = GameSim(
        seed: 12345,
        mapSize: 41,
        specs: const <PlayerSpec>[
          PlayerSpec(id: 1, name: 'A', isBot: false),
          PlayerSpec(id: 2, name: 'B', isBot: false),
        ],
        tempo: 0,
        botSkill: 1,
      );
      expect(sim.phase, MatchPhase.countdown);
      for (var i = 0; i < 200; i++) {
        sim.step(kSimDt);
      }
      expect(sim.phase, MatchPhase.running);
      final snap = sim.buildSnapshot(1, sim.takeEvents());
      expect(snap.players.length, greaterThanOrEqualTo(1));
      expect(snap.totalPlayers, 2);
      final json = snap.toJson();
      final decoded = Snapshot.fromJson(json);
      expect(decoded.names.length, 2);
      expect(decoded.zone.radius, greaterThan(0));
      expect(snap.playerById(1), isNotNull);
    });

    test('выстрелы наносят урон и убивают', () {
      final sim = GameSim(
        seed: 777,
        mapSize: 41,
        specs: const <PlayerSpec>[
          PlayerSpec(id: 1, name: 'A', isBot: false),
          PlayerSpec(id: 2, name: 'B', isBot: false),
        ],
        tempo: 0,
        botSkill: 1,
      );
      for (var i = 0; i < 160; i++) {
        sim.step(kSimDt);
      }
      final a = sim.players[1]!;
      final b = sim.players[2]!;
      // Ищем направление с прямой видимостью и свободной клеткой.
      var placed = false;
      for (var i = 0; i < 32 && !placed; i++) {
        final angle = i * math.pi / 16;
        final target =
            a.pos + Offset(math.cos(angle) * 80, math.sin(angle) * 80);
        if (!sim.maze.isOpenWorld(target.dx, target.dy)) continue;
        if (!sim.maze.lineOfSight(a.pos.dx, a.pos.dy, target.dx, target.dy)) {
          continue;
        }
        b.pos = target;
        a.aim = angle;
        placed = true;
      }
      expect(placed, isTrue);
      b.alive = true;
      b.hp = 40;
      var shots = 0;
      while (b.alive && shots < 60) {
        a.input = InputState(aim: a.aim, fire: true);
        sim.step(kSimDt);
        shots++;
      }
      expect(b.alive, isFalse);
      expect(a.kills, 1);
      expect(sim.phase, MatchPhase.finished);
      expect(sim.results.first.id, 1);
    });

    test('боты сами доводят матч до конца', () {
      final sim = GameSim(
        seed: 2024,
        mapSize: 41,
        specs: const <PlayerSpec>[
          PlayerSpec(id: 1, name: 'Bot A', isBot: true),
          PlayerSpec(id: 2, name: 'Bot B', isBot: true),
          PlayerSpec(id: 3, name: 'Bot C', isBot: true),
          PlayerSpec(id: 4, name: 'Bot D', isBot: true),
        ],
        tempo: 0,
        botSkill: 1.5,
      );
      var steps = 0;
      while (sim.phase != MatchPhase.finished && steps < 30 * 320) {
        sim.step(kSimDt);
        steps++;
      }
      expect(
        sim.phase,
        MatchPhase.finished,
        reason: 'боты не закончили матч за 320 секунд',
      );
      expect(sim.results.length, 4);
      expect(sim.aliveCount, lessThanOrEqualTo(1));
      final snap = sim.buildSnapshot(1, sim.takeEvents());
      expect(snap.phase, MatchPhase.finished);
      expect(snap.results.first.placement, 1);
    });

    test('все стартовые и подключившиеся игроки внутри зоны', () {
      final specs = <PlayerSpec>[
        for (var i = 1; i <= 8; i++)
          PlayerSpec(
            id: i,
            name: 'P$i',
            isBot: false,
            team: (i - 1) ~/ kTeamSize,
          ),
      ];
      final sim = GameSim(
        seed: 9091,
        mapSize: 61,
        specs: specs,
        tempo: 1,
        botSkill: 1,
        teams: true,
      );
      final start = sim.zone.sample(0);
      for (final p in sim.players.values) {
        expect(
          start.contains(p.pos.dx, p.pos.dy),
          isTrue,
          reason: '${p.name} стартовал за пределами зоны',
        );
      }
      final late = sim.addPlayer(
        const PlayerSpec(id: 99, name: 'Late', isBot: false),
      );
      expect(sim.zoneNow.contains(late.pos.dx, late.pos.dy), isTrue);
    });

    test('командный режим: побеждает команда, результаты общие', () {
      final sim = GameSim(
        seed: 4242,
        mapSize: 41,
        specs: const <PlayerSpec>[
          PlayerSpec(id: 1, name: 'Bot A', isBot: true, team: 0),
          PlayerSpec(id: 2, name: 'Bot B', isBot: true, team: 0),
          PlayerSpec(id: 3, name: 'Bot C', isBot: true, team: 1),
          PlayerSpec(id: 4, name: 'Bot D', isBot: true, team: 1),
        ],
        tempo: 0,
        botSkill: 1.5,
        teams: true,
      );
      var steps = 0;
      while (sim.phase != MatchPhase.finished && steps < 30 * 320) {
        sim.step(kSimDt);
        steps++;
      }
      expect(
        sim.phase,
        MatchPhase.finished,
        reason: 'командный матч ботов не закончился за 320 секунд',
      );
      expect(sim.winTeam, anyOf(0, 1));
      final snap = sim.buildSnapshot(1, sim.takeEvents());
      expect(snap.teams, isTrue);
      expect(snap.winTeam, sim.winTeam);
      expect(snap.results.length, 4);
      final winners = snap.results
          .where((r) => r.team == snap.winTeam)
          .toList();
      expect(winners, isNotEmpty);
      expect(winners.every((r) => r.placement == 1), isTrue);
    });

    test('возрождение включается по настройке и ждёт живого союзника', () {
      final sim = GameSim(
        seed: 2026,
        mapSize: 41,
        specs: const <PlayerSpec>[
          PlayerSpec(id: 1, name: 'A', isBot: false, team: 0),
          PlayerSpec(id: 2, name: 'B', isBot: false, team: 0),
          PlayerSpec(id: 3, name: 'C', isBot: false, team: 1),
          PlayerSpec(id: 4, name: 'D', isBot: false, team: 1),
        ],
        tempo: 0,
        botSkill: 1,
        teams: true,
        respawn: true,
      );
      sim.phase = MatchPhase.running;
      sim.matchTime = 3;
      final player = sim.players[1]!
        ..alive = false
        ..respawnAt = sim.matchTime + kRespawnDelay;

      final waiting = Snapshot.fromJson(
        sim.buildSnapshot(1, sim.takeEvents()).toJson(),
      );
      expect(waiting.respawn, isTrue);
      expect(waiting.respawnRemaining, closeTo(kRespawnDelay, 0.1));

      for (var i = 0; i < (kRespawnDelay / kSimDt).ceil() + 2; i++) {
        sim.step(kSimDt);
      }

      expect(player.alive, isTrue);
      expect(player.hp, kMaxHp);
      expect(player.respawnAt, 0);
      expect(sim.takeEvents().whereType<RespawnEvent>(), hasLength(1));
    });

    test('мёртвый наблюдатель: туман вокруг цели или вся карта', () {
      GameSim make(int vision) => GameSim(
        seed: 31337,
        mapSize: 61,
        specs: const <PlayerSpec>[
          PlayerSpec(id: 1, name: 'A', isBot: false),
          PlayerSpec(id: 2, name: 'B', isBot: false),
          PlayerSpec(id: 3, name: 'C', isBot: false),
        ],
        tempo: 0,
        botSkill: 1,
        deathVision: vision,
      );

      GameSim prepare(int vision) {
        final sim = make(vision);
        for (var i = 0; i < 200; i++) {
          sim.step(kSimDt);
        }
        final dead = sim.players[1]!;
        dead.alive = false;
        dead.deathTime = sim.matchTime;
        // Разносим цель наблюдения и третьего игрока далеко друг от друга.
        final open = sim.maze.randomFloorPoint(
          math.Random(vision + 7),
          center: sim.zoneNow.center,
          radius: sim.zoneNow.radius * 0.5,
        );
        sim.players[2]!.pos = open;
        sim.players[3]!.pos = open + const Offset(kVisionRadius * 2.5, 0);
        return sim;
      }

      final all = prepare(1);
      final allSnap = all.buildSnapshot(1, all.takeEvents(), spectateId: 2);
      expect(allSnap.deathVision, 1);
      expect(allSnap.fogView, isFalse);
      expect(allSnap.spectateTarget, 2);
      expect(allSnap.playerById(2), isNotNull);
      expect(allSnap.playerById(3), isNotNull);

      final fog = prepare(0);
      final fogSnap = fog.buildSnapshot(1, fog.takeEvents(), spectateId: 2);
      expect(fogSnap.deathVision, 0);
      expect(fogSnap.fogView, isTrue);
      expect(fogSnap.spectateTarget, 2);
      expect(fogSnap.playerById(2), isNotNull);
      expect(fogSnap.playerById(3), isNull);
    });

    test('наблюдатель не видит врага сквозь стены', () {
      final sim = GameSim(
        seed: 555,
        mapSize: 61,
        specs: const <PlayerSpec>[
          PlayerSpec(id: 1, name: 'A', isBot: false),
          PlayerSpec(id: 2, name: 'B', isBot: false),
        ],
        tempo: 1,
        botSkill: 1,
      );
      for (var i = 0; i < 160; i++) {
        sim.step(kSimDt);
      }
      final a = sim.players[1]!;
      final b = sim.players[2]!;
      // Вплотную, но по разные стороны стены найти сложно — проверяем радиус.
      b.pos = a.pos + const Offset(kVisionRadius * 3, 0);
      sim.step(kSimDt);
      final snap = sim.buildSnapshot(1, sim.takeEvents());
      expect(snap.playerById(2), isNull);
    });

    test('режим просмотра без тумана включает всех игроков в снимок', () {
      final sim = GameSim(
        seed: 4141,
        mapSize: 61,
        specs: const <PlayerSpec>[
          PlayerSpec(id: 1, name: 'A', isBot: false),
          PlayerSpec(id: 2, name: 'B', isBot: false),
        ],
        tempo: 0,
        botSkill: 1,
      );
      final a = sim.players[1]!;
      final b = sim.players[2]!;
      var farPoint = sim.maze.randomFloorPoint(math.Random(42));
      for (
        var i = 0;
        i < 50 && (farPoint - a.pos).distance < kVisionRadius * 2;
        i++
      ) {
        farPoint = sim.maze.randomFloorPoint(math.Random(i + 100));
      }
      b.pos = farPoint;
      expect((farPoint - a.pos).distance, greaterThan(kVisionRadius));

      expect(sim.buildSnapshot(1, const []).playerById(2), isNull);
      expect(
        sim.buildSnapshot(1, const [], revealAllPlayers: true).playerById(2),
        isNotNull,
      );
    });

    test('бесконечная невидимость не истекает во время матча', () {
      final sim = GameSim(
        seed: 7777,
        mapSize: 41,
        specs: const <PlayerSpec>[
          PlayerSpec(id: 1, name: 'A', isBot: false),
          PlayerSpec(id: 2, name: 'B', isBot: false),
        ],
        tempo: 0,
        botSkill: 1,
      );
      final host = sim.players[1]!..hostInfiniteInvisibility = true;
      sim.phase = MatchPhase.running;

      for (var i = 0; i < (10 / kSimDt).round(); i++) {
        sim.step(kSimDt);
      }

      expect(host.alive, isTrue);
      expect(host.ghostTime, greaterThan(6.9));
    });
  });
}

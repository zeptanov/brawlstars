import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:maze_royale/game/constants.dart';
import 'package:maze_royale/game/maze.dart';

void main() {
  group('Maze', () {
    test('генерируется для всех размеров и полностью связная', () {
      for (final size in kMapSizes) {
        for (var seed = 1; seed <= 5; seed++) {
          final maze = Maze.generate(size: size, seed: seed * 7919);
          final floors = <int>[];
          for (var y = 0; y < size; y++) {
            for (var x = 0; x < size; x++) {
              if (!maze.wallAt(x, y)) floors.add(y * size + x);
            }
          }
          expect(floors.length, greaterThan(size * size ~/ 3),
              reason: 'size=$size seed=$seed');

          final start = floors.first;
          final seen = <int>{start};
          final queue = <int>[start];
          while (queue.isNotEmpty) {
            final cur = queue.removeLast();
            final cx = cur % size;
            final cy = cur ~/ size;
            for (final d in const <List<int>>[
              <int>[1, 0],
              <int>[-1, 0],
              <int>[0, 1],
              <int>[0, -1],
            ]) {
              final nx = cx + d[0];
              final ny = cy + d[1];
              if (maze.wallAt(nx, ny)) continue;
              final idx = ny * size + nx;
              if (seen.add(idx)) queue.add(idx);
            }
          }
          expect(seen.length, floors.length,
              reason: 'несвязные клетки: size=$size seed=$seed');
        }
      }
    });

    test('точки спавна не в стенах и разнесены', () {
      final maze = Maze.generate(size: 61, seed: 42);
      final points = maze.spawnPoints(8, 42);
      expect(points.length, 8);
      for (final p in points) {
        expect(maze.isOpenWorld(p.dx, p.dy), isTrue);
      }
      for (var i = 0; i < points.length; i++) {
        for (var j = i + 1; j < points.length; j++) {
          expect((points[i] - points[j]).distance, greaterThan(300));
        }
      }
    });

    test('луч упирается в стену и LOS работает', () {
      final maze = Maze.generate(size: 61, seed: 7);
      var blocked = 0;
      for (var i = 0; i < 200; i++) {
        final x = 100.0 + (i * 53) % 2400;
        final y = 120.0 + (i * 97) % 2400;
        if (maze.wallAtWorld(x, y)) continue;
        final a = i * 0.37;
        final dist = maze.raycast(x, y, a, 300);
        expect(dist, greaterThanOrEqualTo(0));
        expect(dist, lessThanOrEqualTo(300));
        if (dist < 1) blocked++;
      }
      expect(blocked, lessThan(200));
    });

    test('круг не проходит сквозь стену', () {
      final maze = Maze.generate(size: 41, seed: 3);
      final start = maze.spawnPoints(1, 3).first;
      var pos = start;
      for (var i = 0; i < 500; i++) {
        pos = maze.moveCircle(
          pos,
          Offset(math.cos(i * 0.31) * 14, math.sin(i * 0.31) * 14),
          kPlayerRadius,
        );
        expect(maze.circleHitsWall(pos.dx, pos.dy, kPlayerRadius), isFalse);
      }
    });

    test('BFS-путь ведёт до цели', () {
      final maze = Maze.generate(size: 61, seed: 11);
      final a = maze.spawnPoints(1, 11).first;
      final target = maze.randomFloorPoint(math.Random(5));
      final path = maze.findPath(a, target);
      expect(path, isNotEmpty);
      expect((path.last - target).distance, lessThan(kTileSize * 2));
      for (final point in path) {
        expect(maze.wallAtWorld(point.dx, point.dy), isFalse);
      }
    });
  });
}

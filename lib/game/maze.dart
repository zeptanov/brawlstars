import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'constants.dart';

/// Процедурный лабиринт: сетка комнат, двери, укрытия.
///
/// Карта детерминирована seed'ом: сервер и клиенты генерируют одно и то же.
class Maze {
  Maze._(this.size, this.seed, this._walls) : worldSize = size * kTileSize;

  final int size;
  final int seed;
  final Uint8List _walls;
  final double worldSize;

  static const int roomBlock = 10;

  int get roomsPerAxis => (size - 1) ~/ roomBlock;
  double get half => worldSize / 2;

  factory Maze.generate({
    required int size,
    required int seed,
    int generation = 0,
  }) {
    final rooms = (size - 1) ~/ roomBlock;
    assert((size - 1) % roomBlock == 0, 'size must be 10k+1');
    final style = generation.clamp(0, kMapGenerationCount - 1);
    final cells = size * size;
    final walls = Uint8List(cells)..fillRange(0, cells, 1);
    final rng = math.Random(seed);

    void setFloor(int x, int y) {
      if (x <= 0 || y <= 0 || x >= size - 1 || y >= size - 1) return;
      walls[y * size + x] = 0;
    }

    void setWall(int x, int y) {
      if (x <= 1 || y <= 1 || x >= size - 2 || y >= size - 2) return;
      walls[y * size + x] = 1;
    }

    // 1. Комнаты.
    for (var ry = 0; ry < rooms; ry++) {
      for (var rx = 0; rx < rooms; rx++) {
        final x0 = rx * roomBlock + 1;
        final y0 = ry * roomBlock + 1;
        for (var y = 0; y < roomBlock - 1; y++) {
          for (var x = 0; x < roomBlock - 1; x++) {
            setFloor(x0 + x, y0 + y);
          }
        }
      }
    }

    // 2. Укрытия внутри комнат (не перекрывают двери у краёв).
    for (var ry = 0; ry < rooms; ry++) {
      for (var rx = 0; rx < rooms; rx++) {
        final x0 = rx * roomBlock + 1;
        final y0 = ry * roomBlock + 1;
        if (style == 1) {
          for (final offset in <int>[3, 6]) {
            for (var y = 1; y < roomBlock - 2; y++) {
              if (y == 2 || y == 7) continue;
              setWall(x0 + offset, y0 + y);
            }
          }
          continue;
        }
        if (rng.nextDouble() < (style == 2 ? 0.88 : 0.28)) continue;
        final cx = x0 + 4;
        final cy = y0 + 4;
        switch (rng.nextInt(6)) {
          case 0:
            for (var y = 0; y < 2; y++) {
              for (var x = 0; x < 2; x++) {
                setWall(cx - 2 + x, cy - 2 + y);
                setWall(cx + 1 + x, cy + 1 + y);
              }
            }
          case 1:
            for (var x = -2; x <= 2; x++) {
              setWall(cx + x, cy);
            }
          case 2:
            for (var y = -2; y <= 2; y++) {
              setWall(cx, cy + y);
            }
          case 3:
            for (var x = -2; x <= 1; x++) {
              setWall(cx + x, cy - 1);
            }
            for (var y = -1; y <= 2; y++) {
              setWall(cx - 2, cy + y);
            }
          case 4:
            for (var x = -1; x <= 1; x++) {
              setWall(cx + x, cy - 2);
              setWall(cx + x, cy + 2);
            }
          case 5:
            setWall(cx - 2, cy - 2);
            setWall(cx - 1, cy - 2);
            setWall(cx + 2, cy + 1);
            setWall(cx + 2, cy + 2);
        }
      }
    }

    // 3. Двери между комнатами — карта всегда связная.
    for (var ry = 0; ry < rooms; ry++) {
      for (var rx = 0; rx < rooms; rx++) {
        if (rx < rooms - 1) {
          final wallX = (rx + 1) * roomBlock;
          final width = style == 2 ? 5 : 3;
          final doorY =
              ry * roomBlock +
              (style == 2 ? 1 : 2) +
              rng.nextInt(style == 2 ? 5 : 5);
          for (var y = 0; y < width; y++) {
            setFloor(wallX, doorY + y);
          }
        }
        if (ry < rooms - 1) {
          final wallY = (ry + 1) * roomBlock;
          final width = style == 2 ? 5 : 3;
          final doorX =
              rx * roomBlock +
              (style == 2 ? 1 : 2) +
              rng.nextInt(style == 2 ? 5 : 5);
          for (var x = 0; x < width; x++) {
            setFloor(doorX + x, wallY);
          }
        }
      }
    }

    return Maze._(size, seed, walls);
  }

  bool wallAt(int tx, int ty) {
    if (tx < 0 || ty < 0 || tx >= size || ty >= size) return true;
    return _walls[ty * size + tx] != 0;
  }

  bool wallAtWorld(double x, double y) =>
      wallAt((x / kTileSize).floor(), (y / kTileSize).floor());

  bool isOpenTile(int tx, int ty) {
    if (wallAt(tx, ty)) return false;
    return !wallAt(tx - 1, ty) &&
        !wallAt(tx + 1, ty) &&
        !wallAt(tx, ty - 1) &&
        !wallAt(tx, ty + 1);
  }

  bool isOpenWorld(double x, double y) =>
      isOpenTile((x / kTileSize).floor(), (y / kTileSize).floor());

  /// Пересечение круга и стен.
  bool circleHitsWall(double x, double y, double radius) {
    final r = radius - 0.6;
    final minX = ((x - r) / kTileSize).floor();
    final maxX = ((x + r) / kTileSize).floor();
    final minY = ((y - r) / kTileSize).floor();
    final maxY = ((y + r) / kTileSize).floor();
    for (var ty = minY; ty <= maxY; ty++) {
      for (var tx = minX; tx <= maxX; tx++) {
        if (!wallAt(tx, ty)) continue;
        final left = tx * kTileSize;
        final top = ty * kTileSize;
        final closestX = x.clamp(left, left + kTileSize);
        final closestY = y.clamp(top, top + kTileSize);
        final dx = x - closestX;
        final dy = y - closestY;
        if (dx * dx + dy * dy < r * r) return true;
      }
    }
    return false;
  }

  /// Двигает круг, скользя вдоль стен. Без туннелирования.
  Offset moveCircle(Offset from, Offset delta, double radius) {
    var x = from.dx;
    var y = from.dy;
    final dist = delta.distance;
    if (dist < 0.0001) return from;
    final steps = (dist / 6.0).ceil().clamp(1, 48);
    final sx = delta.dx / steps;
    final sy = delta.dy / steps;
    for (var i = 0; i < steps; i++) {
      if (!circleHitsWall(x + sx, y, radius)) x += sx;
      if (!circleHitsWall(x, y + sy, radius)) y += sy;
    }
    return Offset(x, y);
  }

  /// DDA-луч: расстояние до первой стены (не больше [maxDist]).
  double raycast(double sx, double sy, double angle, double maxDist) {
    final dx = math.cos(angle);
    final dy = math.sin(angle);
    var mapX = (sx / kTileSize).floor();
    var mapY = (sy / kTileSize).floor();
    if (wallAt(mapX, mapY)) return 0;

    final deltaDistX = dx.abs() < 1e-9
        ? double.infinity
        : (kTileSize / dx).abs();
    final deltaDistY = dy.abs() < 1e-9
        ? double.infinity
        : (kTileSize / dy).abs();

    final stepX = dx >= 0 ? 1 : -1;
    final stepY = dy >= 0 ? 1 : -1;

    var sideDistX = dx > 0
        ? ((mapX + 1) * kTileSize - sx) / dx
        : dx < 0
        ? (sx - mapX * kTileSize) / -dx
        : double.infinity;
    var sideDistY = dy > 0
        ? ((mapY + 1) * kTileSize - sy) / dy
        : dy < 0
        ? (sy - mapY * kTileSize) / -dy
        : double.infinity;

    var dist = 0.0;
    for (var guard = 0; guard < 512; guard++) {
      if (sideDistX < sideDistY) {
        dist = sideDistX;
        mapX += stepX;
        sideDistX += deltaDistX;
      } else {
        dist = sideDistY;
        mapY += stepY;
        sideDistY += deltaDistY;
      }
      if (dist > maxDist) return maxDist;
      if (wallAt(mapX, mapY)) return dist;
    }
    return maxDist;
  }

  bool lineOfSight(double x1, double y1, double x2, double y2) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist < 1) return true;
    final free = raycast(x1, y1, math.atan2(dy, dx), dist);
    return free >= dist - 1.5;
  }

  Offset tileCenter(int tx, int ty) =>
      Offset((tx + 0.5) * kTileSize, (ty + 0.5) * kTileSize);

  /// Свободная точка рядом с желаемой (с запасом от стен).
  Offset? freeSpotNear(Offset near, math.Random rng, {double maxTiles = 6}) {
    final baseX = (near.dx / kTileSize).floor();
    final baseY = (near.dy / kTileSize).floor();
    for (var radius = 0; radius <= maxTiles; radius++) {
      final candidates = <Offset>[];
      for (var dy = -radius; dy <= radius; dy++) {
        for (var dx = -radius; dx <= radius; dx++) {
          if (radius > 0 && dx.abs() != radius && dy.abs() != radius) {
            continue;
          }
          final tx = baseX + dx;
          final ty = baseY + dy;
          if (isOpenTile(tx, ty)) candidates.add(tileCenter(tx, ty));
        }
      }
      if (candidates.isNotEmpty) {
        final c = candidates[rng.nextInt(candidates.length)];
        return c + Offset(rng.nextDouble() * 8 - 4, rng.nextDouble() * 8 - 4);
      }
    }
    return null;
  }

  List<Offset> roomCenters() {
    final rooms = roomsPerAxis;
    final result = <Offset>[];
    for (var ry = 0; ry < rooms; ry++) {
      for (var rx = 0; rx < rooms; rx++) {
        result.add(
          Offset(
            (rx * roomBlock + 5.5) * kTileSize,
            (ry * roomBlock + 5.5) * kTileSize,
          ),
        );
      }
    }
    return result;
  }

  /// Точки спавна, максимально разнесённые по карте.
  List<Offset> spawnPoints(int count, int spawnSeed) {
    final rng = math.Random(spawnSeed ^ 0x5f3759df);
    final rooms = roomsPerAxis;
    final candidates = <({int rx, int ry, Offset pos})>[];
    for (var ry = 0; ry < rooms; ry++) {
      for (var rx = 0; rx < rooms; rx++) {
        candidates.add((
          rx: rx,
          ry: ry,
          pos: Offset(
            (rx * roomBlock + 5.5) * kTileSize,
            (ry * roomBlock + 5.5) * kTileSize,
          ),
        ));
      }
    }
    candidates.shuffle(rng);
    final picked = <({int rx, int ry, Offset pos})>[];
    for (final c in candidates) {
      if (picked.length >= count) break;
      final ok = picked.every(
        (p) => (p.rx - c.rx).abs() >= 2 || (p.ry - c.ry).abs() >= 2,
      );
      if (ok) picked.add(c);
    }
    for (final c in candidates) {
      if (picked.length >= count) break;
      picked.add(c);
    }
    final rng2 = math.Random(spawnSeed);
    return picked
        .take(count)
        .map((c) => freeSpotNear(c.pos, rng2) ?? c.pos)
        .toList();
  }

  /// Точка на карте для пикапа/блуждания.
  Offset randomFloorPoint(math.Random rng, {Offset? center, double? radius}) {
    for (var attempt = 0; attempt < 240; attempt++) {
      double x;
      double y;
      if (center != null && radius != null) {
        final a = rng.nextDouble() * math.pi * 2;
        final r = math.sqrt(rng.nextDouble()) * radius;
        x = center.dx + math.cos(a) * r;
        y = center.dy + math.sin(a) * r;
      } else {
        x = (2 + rng.nextDouble() * (size - 6)) * kTileSize;
        y = (2 + rng.nextDouble() * (size - 6)) * kTileSize;
      }
      if (!isOpenWorld(x, y)) continue;
      return Offset(x, y);
    }
    return tileCenter(size ~/ 2, size ~/ 2);
  }

  /// BFS-путь по центрам клеток (для ботов).
  List<Offset> findPath(Offset from, Offset to, {int maxNodes = 9000}) {
    final startX = (from.dx / kTileSize).floor().clamp(1, size - 2);
    final startY = (from.dy / kTileSize).floor().clamp(1, size - 2);
    final goalX = (to.dx / kTileSize).floor().clamp(1, size - 2);
    final goalY = (to.dy / kTileSize).floor().clamp(1, size - 2);
    final start = startY * size + startX;
    final goal = goalY * size + goalX;
    if (start == goal) return <Offset>[to];
    if (wallAt(goalX, goalY)) return const <Offset>[];

    final prev = Int32List(size * size)..fillRange(0, size * size, -1);
    prev[start] = start;
    final queue = ListQueue<int>()..add(start);
    var found = false;
    var visited = 0;
    while (queue.isNotEmpty) {
      final cur = queue.removeFirst();
      if (cur == goal) {
        found = true;
        break;
      }
      if (++visited > maxNodes) break;
      final cx = cur % size;
      final cy = cur ~/ size;
      for (var k = 0; k < 4; k++) {
        final nx = cx + (k == 0 ? 1 : (k == 1 ? -1 : 0));
        final ny = cy + (k == 2 ? 1 : (k == 3 ? -1 : 0));
        if (wallAt(nx, ny)) continue;
        final idx = ny * size + nx;
        if (prev[idx] != -1) continue;
        prev[idx] = cur;
        queue.add(idx);
      }
    }
    if (!found) return const <Offset>[];
    final tiles = <int>[];
    var cur = goal;
    var guard = 0;
    while (cur != start && guard++ < 9000) {
      tiles.add(cur);
      cur = prev[cur];
      if (cur < 0) return const <Offset>[];
    }
    tiles.add(start);
    final points = tiles.reversed
        .map((idx) => tileCenter(idx % size, idx ~/ size))
        .toList();
    return _smoothPath(points, from);
  }

  /// Убирает лишние точки, если между ними прямая видимость.
  List<Offset> _smoothPath(List<Offset> path, Offset from) {
    if (path.length <= 2) return path;
    final result = <Offset>[];
    var anchor = from;
    var i = 0;
    while (i < path.length) {
      var best = i;
      for (var j = path.length - 1; j > i; j--) {
        if (lineOfSight(anchor.dx, anchor.dy, path[j].dx, path[j].dy)) {
          best = j;
          break;
        }
      }
      result.add(path[best]);
      anchor = path[best];
      if (best == i) {
        i++;
      } else {
        i = best + 1;
      }
    }
    return result;
  }
}

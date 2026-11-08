import 'dart:math' as math;
import 'dart:ui';

/// Один этап жизни зоны: ожидание или сжатие.
class ZonePhase {
  ZonePhase({
    required this.start,
    required this.end,
    required this.fromRadius,
    required this.toRadius,
    required this.fromCenter,
    required this.toCenter,
    required this.shrinking,
    required this.stage,
  });

  final double start;
  final double end;
  final double fromRadius;
  final double toRadius;
  final Offset fromCenter;
  final Offset toCenter;
  final bool shrinking;
  final int stage;
}

class ZoneSample {
  const ZoneSample({
    required this.center,
    required this.radius,
    required this.shrinking,
    required this.stage,
    required this.damage,
    required this.nextChangeIn,
  });

  final Offset center;
  final double radius;
  final bool shrinking;
  final int stage;
  final double damage;
  final double nextChangeIn;

  bool contains(double x, double y) {
    final dx = x - center.dx;
    final dy = y - center.dy;
    return dx * dx + dy * dy <= radius * radius;
  }
}

/// Расписание сужения зоны. Одинаково на сервере и клиенте (только сервер применяет урон).
class ZoneTimeline {
  ZoneTimeline._(this.initialRadius, this.startCenter, this.phases);

  final double initialRadius;
  final Offset startCenter;
  final List<ZonePhase> phases;

  static const List<double> _fractions = <double>[1.0, 0.72, 0.52, 0.36, 0.22, 0.10];
  static const List<double> _pauses = <double>[13, 10, 9, 8, 7];
  static const List<double> _shrinks = <double>[18, 15, 13, 11, 9];
  static const List<double> _damage = <double>[2, 5, 9, 14, 20, 28];

  double get endTime => phases.isEmpty ? 0 : phases.last.end;

  factory ZoneTimeline.generate({
    required double worldSize,
    required int seed,
    required double tempo,
  }) {
    final rng = math.Random(seed);
    final initialRadius = worldSize * 0.46;
    final center = Offset(worldSize / 2, worldSize / 2);
    final phases = <ZonePhase>[];
    var t = 0.0;
    var radius = initialRadius;
    var current = center;

    // Стартовое ожидание.
    final firstWait = _pauses[0] * tempo;
    phases.add(ZonePhase(
      start: t,
      end: t + firstWait,
      fromRadius: radius,
      toRadius: radius,
      fromCenter: current,
      toCenter: current,
      shrinking: false,
      stage: 0,
    ));
    t += firstWait;

    for (var i = 1; i < _fractions.length; i++) {
      final targetRadius = initialRadius * _fractions[i];
      final maxDrift = math.max(0.0, (radius - targetRadius) * 0.55);
      final angle = rng.nextDouble() * math.pi * 2;
      final dist = maxDrift * rng.nextDouble();
      var targetCenter = current + Offset(math.cos(angle) * dist, math.sin(angle) * dist);
      final min = worldSize * 0.18;
      final max = worldSize * 0.82;
      targetCenter = Offset(
        targetCenter.dx.clamp(min, max),
        targetCenter.dy.clamp(min, max),
      );
      final duration = _shrinks[i - 1] * tempo;
      phases.add(ZonePhase(
        start: t,
        end: t + duration,
        fromRadius: radius,
        toRadius: targetRadius,
        fromCenter: current,
        toCenter: targetCenter,
        shrinking: true,
        stage: i,
      ));
      t += duration;
      radius = targetRadius;
      current = targetCenter;

      if (i < _fractions.length - 1) {
        final wait = _pauses[i] * tempo;
        phases.add(ZonePhase(
          start: t,
          end: t + wait,
          fromRadius: radius,
          toRadius: radius,
          fromCenter: current,
          toCenter: current,
          shrinking: false,
          stage: i,
        ));
        t += wait;
      }
    }

    return ZoneTimeline._(initialRadius, center, phases);
  }

  ZoneSample sample(double time) {
    if (phases.isEmpty) {
      return ZoneSample(
        center: startCenter,
        radius: initialRadius,
        shrinking: false,
        stage: 0,
        damage: _damage[0],
        nextChangeIn: 999,
      );
    }
    final t = time.clamp(0.0, phases.last.end);
    ZonePhase phase = phases.first;
    for (final p in phases) {
      if (t >= p.start && t <= p.end) {
        phase = p;
        break;
      }
      if (t > p.end) phase = p;
    }
    if (!phase.shrinking) {
      return ZoneSample(
        center: phase.fromCenter,
        radius: phase.fromRadius,
        shrinking: false,
        stage: phase.stage,
        damage: _damage[phase.stage.clamp(0, _damage.length - 1)],
        nextChangeIn: math.max(0, phase.end - t),
      );
    }
    var progress = (t - phase.start) / math.max(0.001, phase.end - phase.start);
    progress = progress.clamp(0.0, 1.0);
    final eased = progress * progress * (3 - 2 * progress);
    final radius = phase.fromRadius + (phase.toRadius - phase.fromRadius) * eased;
    final center = Offset(
      phase.fromCenter.dx + (phase.toCenter.dx - phase.fromCenter.dx) * eased,
      phase.fromCenter.dy + (phase.toCenter.dy - phase.fromCenter.dy) * eased,
    );
    return ZoneSample(
      center: center,
      radius: radius,
      shrinking: true,
      stage: phase.stage,
      damage: _damage[phase.stage.clamp(0, _damage.length - 1)],
      nextChangeIn: math.max(0, phase.end - t),
    );
  }
}

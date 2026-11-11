import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../app/game_audio.dart';
import '../app/room.dart';
import '../app/settings.dart';
import '../app/theme.dart';
import '../game/constants.dart';
import '../game/pickups.dart';
import '../game/weapons.dart';
import '../net/game_client.dart';
import '../net/messages.dart';
import 'arena_painter.dart';
import 'controls.dart';
import 'game_view_model.dart';
import 'hud.dart';
import 'in_game_settings_panel.dart';
import 'widgets.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.room, this.fromLobby = false});

  final Room room;

  /// Экран открыт из лобби комнаты: после матча можно вернуться туда,
  /// не пересоздавая комнату.
  final bool fromLobby;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  final GameViewModel _vm = GameViewModel();
  final AppSettings _settings = AppSettings.instance;
  final GameAudio _audio = GameAudio.instance;
  final FocusNode _focusNode = FocusNode(debugLabel: 'maze-royale-game');
  final ValueNotifier<Offset> _crosshair = ValueNotifier<Offset>(Offset.zero);
  final Set<LogicalKeyboardKey> _pressed = <LogicalKeyboardKey>{};
  final List<KillFeedEntry> _killfeed = <KillFeedEntry>[];
  final List<HudBanner> _banners = <HudBanner>[];
  final List<DamageMark> _damageMarks = <DamageMark>[];

  late final Ticker _ticker;

  StreamSubscription<GameEvent>? _eventSub;
  StreamSubscription<String>? _noticeSub;

  double _lastElapsed = 0;
  double _inputAccum = 0;
  double _hudAccum = 0;
  double _fpsAccum = 0;
  int _fpsFrames = 0;
  int _fps = 60;

  double _aim = 0;
  double _nextShotSoundAt = 0;
  Offset _leftStick = Offset.zero;
  Offset _rightStick = Offset.zero;
  Offset _pointer = Offset.zero;
  bool _hasPointer = false;
  bool _touchControls = false;
  bool _touchFire = false;
  bool _touchHoldFire = false;
  bool _mouseFire = false;
  bool _spaceFire = false;
  bool _dashPending = false;
  bool _reloadPending = false;
  bool _reloadSoundStateKnown = false;
  bool _wasReloading = false;
  int? _directTouchPointer;

  bool _scoreboard = false;
  bool _menuOpen = false;
  bool _leaving = false;
  bool _awaitingRematch = false;
  double _awaitingSince = 0;
  bool _recordedResult = false;
  int _sentSpectate = 0;
  bool _awaitingLobby = false;
  bool _exitPromptOpen = false;

  double _hitAt = -10;
  double _killAt = -10;
  MatchPhase _lastPhase = MatchPhase.countdown;
  int _lastZoneStage = -1;
  int _warnedZoneStage = -1;

  GameClient get _client => widget.room.client;

  @override
  void initState() {
    super.initState();
    _audio
      ..bind(_settings)
      ..startMatchMusic();
    _touchControls = _settings.isTouchDefault;
    _ticker = createTicker(_onTick)..start();
    _eventSub = _client.events.stream.listen(_onGameEvent);
    _noticeSub = _client.notices.stream.listen(_onNotice);
    _client.error.addListener(_onClientChanged);
    _client.lobby.addListener(_onClientChanged);
    _client.latency.addListener(_onClientChanged);
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      unawaited(
        SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]),
      );
      unawaited(
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _openSettings() {
    unawaited(_audio.playUi());
    showNeonSheet(
      context: context,
      title: 'Настройки игры',
      maxWidth: 560,
      child: InGameSettingsPanel(
        settings: _settings,
        onInputModeChanged: (mode) {
          _settings.setInputMode(mode);
          final touchControls = _settings.isTouchDefault;
          if (_touchControls != touchControls && mounted) {
            setState(() => _touchControls = touchControls);
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    final events = _eventSub;
    if (events != null) unawaited(events.cancel());
    final notices = _noticeSub;
    if (notices != null) unawaited(notices.cancel());
    _client.error.removeListener(_onClientChanged);
    _client.lobby.removeListener(_onClientChanged);
    _client.latency.removeListener(_onClientChanged);
    _ticker.dispose();
    unawaited(_audio.stopMatchMusic());
    _focusNode.dispose();
    _crosshair.dispose();
    if (!_leaving) unawaited(widget.room.close());
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      unawaited(
        SystemChrome.setPreferredOrientations(DeviceOrientation.values),
      );
      unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    }
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Кадр
  // -------------------------------------------------------------------------

  void _onTick(Duration elapsed) {
    if (!mounted) return;
    final now = elapsed.inMicroseconds / 1000000.0;
    var dt = now - _lastElapsed;
    if (_lastElapsed == 0 || dt <= 0) dt = 1 / 60;
    _lastElapsed = now;
    dt = dt.clamp(0.0, 0.1);

    final client = _client;
    if (!identical(_vm.maze, client.maze)) {
      _vm.setMaze(client.maze);
      _onNewWorld();
    }
    _vm.myId = client.id;
    _vm.showShake = _settings.screenShake;
    _vm.rayCount = _settings.fogRays;

    _updateAim(client);
    _vm.myAim = _aim;

    final snapshot = client.snapshot.value;
    _vm.update(snapshot, dt, touch: _touchControls);
    _playReloadSoundOnStart();
    if (snapshot != null) _checkTransitions(snapshot, client);
    _syncSpectate(client);
    _recordResult(client);
    _pruneHud();
    _sendInput(client, dt);
    _updateFps(dt);

    _hudAccum += dt;
    if (_hudAccum >= 0.1) {
      _hudAccum = 0;
      if (mounted) setState(() {});
    }
  }

  void _playReloadSoundOnStart() {
    final actor = _vm.myActor;
    if (actor == null) {
      _reloadSoundStateKnown = false;
      return;
    }

    if (_reloadSoundStateKnown && !_wasReloading && actor.reloading) {
      unawaited(_audio.playReload());
    }
    _wasReloading = actor.reloading;
    _reloadSoundStateKnown = true;
  }

  void _updateAim(GameClient client) {
    final snap = client.snapshot.value;
    final self = snap?.playerById(client.id);
    final pos = self != null ? Offset(self.x, self.y) : _vm.myActor?.pos;
    if (pos == null) return;

    if (_touchControls) {
      if (_rightStick.distance > 0.14) {
        _aim = math.atan2(_rightStick.dy, _rightStick.dx);
        if (_touchFire) _applyAimAssist(pos, 0.35);
      } else if (_touchHoldFire) {
        _applyAimAssist(pos, 0.9);
      }
      return;
    }

    if (_hasPointer && !_vm.spectator) {
      final world = _vm.screenToWorld(_pointer);
      final dx = world.dx - pos.dx;
      final dy = world.dy - pos.dy;
      if (dx.abs() + dy.abs() > 0.01) {
        _aim = math.atan2(dy, dx);
      }
      _crosshair.value = _pointer;
    }
  }

  void _applyAimAssist(Offset from, double strength) {
    final myTeam = _vm.myActor?.team ?? -1;
    RenderActor? best;
    var bestDiff = 0.42;
    for (final actor in _vm.actors.values) {
      if (actor.isSelf || !actor.alive) continue;
      if (myTeam >= 0 && actor.team == myTeam) continue;
      final delta = actor.pos - from;
      final distance = delta.distance;
      if (distance > 880 || distance < 1) continue;
      final target = math.atan2(delta.dy, delta.dx);
      var diff = (target - _aim) % (math.pi * 2);
      if (diff > math.pi) diff -= math.pi * 2;
      diff = diff.abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        best = actor;
      }
    }
    if (best == null) return;
    final delta = best.pos - from;
    _aim = angleLerp(_aim, math.atan2(delta.dy, delta.dx), strength);
  }

  void _syncSpectate(GameClient client) {
    if (!_vm.spectator) {
      _sentSpectate = 0;
      return;
    }
    final id = _vm.spectateTargetId;
    if (id <= 0 || id == _sentSpectate) return;
    _sentSpectate = id;
    client.spectate(id);
  }

  void _sendInput(GameClient client, double dt) {
    _inputAccum += dt;
    if (_inputAccum < kInputInterval) return;
    _inputAccum = 0;
    if (!client.isConnected || client.paused || _leaving) return;

    final move = _touchControls ? _leftStick : _keyboardMove();
    final firing =
        !_vm.spectator &&
        !_menuOpen &&
        (_mouseFire || _spaceFire || _touchFire || _touchHoldFire);
    final actor = _vm.myActor;
    if (firing &&
        actor != null &&
        actor.ammo > 0 &&
        !actor.reloading &&
        _vm.time >= _nextShotSoundAt) {
      unawaited(_audio.playWeapon(actor.weapon));
      _nextShotSoundAt = _vm.time + weaponByIndex(actor.weapon).fireInterval;
    }
    if (_dashPending) unawaited(_audio.playDash());
    client.sendInput(
      InputState(
        moveX: move.dx,
        moveY: move.dy,
        aim: _aim,
        fire: firing,
        dash: _dashPending,
        reload: _reloadPending,
      ),
    );
    _dashPending = false;
    _reloadPending = false;
  }

  Offset _keyboardMove() {
    var x = 0.0;
    var y = 0.0;
    if (_isDown(LogicalKeyboardKey.keyA) ||
        _isDown(LogicalKeyboardKey.arrowLeft)) {
      x -= 1;
    }
    if (_isDown(LogicalKeyboardKey.keyD) ||
        _isDown(LogicalKeyboardKey.arrowRight)) {
      x += 1;
    }
    if (_isDown(LogicalKeyboardKey.keyW) ||
        _isDown(LogicalKeyboardKey.arrowUp)) {
      y -= 1;
    }
    if (_isDown(LogicalKeyboardKey.keyS) ||
        _isDown(LogicalKeyboardKey.arrowDown)) {
      y += 1;
    }
    var delta = Offset(x, y);
    if (delta.distance > 1) delta = delta / delta.distance;
    return delta;
  }

  bool _isDown(LogicalKeyboardKey key) => _pressed.contains(key);

  void _updateFps(double dt) {
    _fpsAccum += dt;
    _fpsFrames++;
    if (_fpsAccum >= 1) {
      _fps = (_fpsFrames / _fpsAccum).round().clamp(1, 999);
      _fpsAccum = 0;
      _fpsFrames = 0;
    }
  }

  void _onNewWorld() {
    _lastPhase = MatchPhase.countdown;
    _lastZoneStage = -1;
    _warnedZoneStage = -1;
    _recordedResult = false;
    _awaitingRematch = false;
    _awaitingLobby = false;
    _sentSpectate = 0;
    _scoreboard = false;
    _leftStick = Offset.zero;
    _rightStick = Offset.zero;
    _touchFire = false;
    _touchHoldFire = false;
    if (mounted) {
      setState(() {
        _killfeed.clear();
        _banners.clear();
        _damageMarks.clear();
        _hitAt = -10;
        _killAt = -10;
      });
    }
  }

  void _checkTransitions(Snapshot snap, GameClient client) {
    if (snap.phase == MatchPhase.running && _lastPhase != MatchPhase.running) {
      _addBanner(
        HudBanner(
          text: 'В БОЙ',
          detail: 'Найдите оружие и оставайтесь в зоне',
          color: Palette.accent,
          icon: Icons.play_arrow_rounded,
          createdAt: _vm.time,
        ),
      );
      unawaited(HapticFeedback.mediumImpact());
    }
    _lastPhase = snap.phase;

    if (_lastZoneStage < 0) {
      _lastZoneStage = snap.zoneStage;
    } else if (snap.zoneStage > _lastZoneStage) {
      _lastZoneStage = snap.zoneStage;
      _addBanner(
        HudBanner(
          text: 'ЗОНА СУЖАЕТСЯ · ЭТАП ${snap.zoneStage + 1}',
          detail: 'Следующее кольцо уже близко',
          color: Palette.danger,
          icon: Icons.zoom_out_map_rounded,
          createdAt: _vm.time,
          duration: 3.6,
        ),
      );
      unawaited(HapticFeedback.heavyImpact());
    }

    if (!snap.zoneShrinking &&
        snap.nextZoneEventIn > 0.15 &&
        snap.nextZoneEventIn <= 5.2 &&
        _warnedZoneStage != snap.zoneStage) {
      _warnedZoneStage = snap.zoneStage;
      _addBanner(
        HudBanner(
          text: 'СУЖЕНИЕ ЧЕРЕЗ ${snap.nextZoneEventIn.ceil()} С',
          detail: 'Двигайтесь к центру',
          color: Palette.gold,
          icon: Icons.timer_outlined,
          createdAt: _vm.time,
          duration: 2.4,
        ),
      );
    }

    if (snap.phase == MatchPhase.finished && _menuOpen) {
      _menuOpen = false;
    }
  }

  void _recordResult(GameClient client) {
    final snap = _vm.snapshot;
    if (snap == null || _recordedResult || snap.phase != MatchPhase.finished) {
      return;
    }
    final row = snap.resultOf(client.id);
    if (row == null) return;
    _recordedResult = true;
    final won = snap.teams
        ? snap.winTeam >= 0 && snap.teamOf(client.id) == snap.winTeam
        : row.placement == 1;
    _settings.recordMatch(
      placement: row.placement,
      kills: row.kills,
      damage: row.damage,
      won: won,
    );
  }

  // -------------------------------------------------------------------------
  // События
  // -------------------------------------------------------------------------

  void _onGameEvent(GameEvent event) {
    if (!mounted) return;
    switch (event) {
      case KillEvent e:
        _onKill(e);
      case DamageEvent e:
        _onDamage(e);
      case PickupEvent e:
        _onPickup(e);
      case ZoneEvent():
        unawaited(HapticFeedback.selectionClick());
      case RespawnEvent e:
        if (e.playerId == _client.id) {
          unawaited(_audio.playRespawn());
          _addBanner(
            HudBanner(
              text: 'ВЫ ВОЗРОДИЛИСЬ',
              detail: 'Союзник удержал позицию',
              color: Palette.accent,
              icon: Icons.restart_alt_rounded,
              createdAt: _vm.time,
              duration: 2.4,
            ),
          );
          unawaited(HapticFeedback.mediumImpact());
        } else if (_isAlly(e.playerId)) {
          unawaited(_audio.playRespawn());
          _addBanner(
            HudBanner(
              text: 'СОЮЗНИК ВЕРНУЛСЯ',
              detail: _client.snapshot.value?.nameOf(e.playerId),
              color: Palette.accent,
              icon: Icons.restart_alt_rounded,
              createdAt: _vm.time,
              duration: 2.8,
            ),
          );
          unawaited(HapticFeedback.selectionClick());
        }
      case JoinEvent():
      case LeaveEvent():
        break;
    }
  }

  void _onKill(KillEvent event) {
    final snap = _vm.snapshot;
    final killer = event.killerId < 0
        ? 'Зона'
        : (snap?.nameOf(event.killerId) ?? 'Игрок ${event.killerId}');
    final victim = snap?.nameOf(event.victimId) ?? 'Игрок ${event.victimId}';
    final respawnDelay =
        _client.lobby.value?.respawnDelay ?? kDefaultRespawnDelay;
    if (event.victimId == _client.id || _isAlly(event.victimId)) {
      unawaited(_audio.playExplosion());
    }
    if (event.victimId != _client.id && _isAlly(event.victimId)) {
      _addBanner(
        HudBanner(
          text: 'НАПАРНИК УСТРАНЁН',
          detail: snap?.respawn == true
              ? 'Возвращение через $respawnDelay сек., если союзник жив'
              : victim,
          color: Palette.danger,
          icon: Icons.person_off_outlined,
          createdAt: _vm.time,
          duration: 3.2,
        ),
      );
    }
    final victimActor = _vm.actors[event.victimId];
    if (victimActor != null) {
      _vm.addBurst(
        victimActor.pos,
        const Color(0xFFFF5C7A),
        size: 34,
        life: 0.55,
      );
    }

    setState(() {
      _killfeed.insert(
        0,
        KillFeedEntry(
          killerId: event.killerId,
          victimId: event.victimId,
          killer: killer,
          victim: victim,
          weapon: event.weapon,
          createdAt: _vm.time,
        ),
      );
      while (_killfeed.length > 6) {
        _killfeed.removeLast();
      }
      if (event.killerId == _client.id) {
        _killAt = _vm.time;
        _hitAt = _vm.time;
      }
    });

    if (event.killerId == _client.id) {
      unawaited(_audio.playKill());
      _addBanner(
        HudBanner(
          text: 'УСТРАНЁН $victim',
          detail: weaponByIndex(event.weapon).short,
          color: Palette.gold,
          icon: Icons.gps_fixed_rounded,
          createdAt: _vm.time,
          duration: 2.2,
        ),
      );
      _vm.kick(0.3);
      unawaited(HapticFeedback.mediumImpact());
    } else if (event.victimId == _client.id) {
      _addBanner(
        HudBanner(
          text: 'ВАС УСТРАНИЛИ',
          detail: killer == 'Зона'
              ? 'Не оставайтесь вне зоны'
              : 'Наблюдайте за матчем',
          color: Palette.danger,
          icon: Icons.dangerous_rounded,
          createdAt: _vm.time,
          duration: 3.4,
        ),
      );
      _vm.kick(1);
      unawaited(HapticFeedback.heavyImpact());
    }
  }

  bool _isAlly(int playerId) {
    final snapshot = _client.snapshot.value;
    if (snapshot == null || !snapshot.teams || playerId == _client.id) {
      return false;
    }
    final myTeam = snapshot.teamOf(_client.id);
    return myTeam >= 0 && snapshot.teamOf(playerId) == myTeam;
  }

  void _onDamage(DamageEvent event) {
    final me = _vm.myActor;
    if (event.attackerId == _client.id && event.victimId != _client.id) {
      unawaited(_audio.playHit());
      setState(() => _hitAt = _vm.time);
      return;
    }
    if (event.victimId != _client.id || me == null) return;

    unawaited(_audio.playDamage());
    final attacker = _vm.actors[event.attackerId];
    final angle = attacker != null
        ? math.atan2(attacker.pos.dy - me.pos.dy, attacker.pos.dx - me.pos.dx)
        : event.angle + math.pi;
    setState(() {
      _damageMarks.add(
        DamageMark(angle: angle, amount: event.amount, createdAt: _vm.time),
      );
      while (_damageMarks.length > 8) {
        _damageMarks.removeAt(0);
      }
    });
    _vm.kick(0.18 + math.min(0.4, event.amount / 90));
    unawaited(HapticFeedback.lightImpact());
  }

  void _onPickup(PickupEvent event) {
    if (event.playerId != _client.id) return;
    unawaited(_audio.playPickup());
    final def = pickupByIndex(event.type);
    final color = Color(def.color);
    final me = _vm.myActor;
    if (me != null) {
      _vm.addBurst(me.pos, color, size: 22, life: 0.5);
    }
    _addBanner(
      HudBanner(
        text: def.name.toUpperCase(),
        detail: def.weapon != null ? 'Оружие в руках' : 'Эффект активирован',
        color: color,
        icon: def.weapon != null
            ? Icons.gps_fixed_rounded
            : Icons.auto_awesome_rounded,
        createdAt: _vm.time,
        duration: 1.9,
      ),
    );
    unawaited(HapticFeedback.selectionClick());
  }

  void _onNotice(String message) {
    if (!mounted || message.trim().isEmpty) return;
    _addBanner(
      HudBanner(
        text: message,
        color: Palette.gold,
        icon: Icons.info_outline_rounded,
        createdAt: _vm.time,
        duration: 4.5,
      ),
    );
  }

  void _addBanner(HudBanner banner) {
    if (!mounted) return;
    setState(() {
      _banners.insert(0, banner);
      while (_banners.length > 4) {
        _banners.removeLast();
      }
    });
  }

  void _pruneHud() {
    final now = _vm.time;
    _killfeed.removeWhere((e) => now - e.createdAt > 6);
    _banners.removeWhere((b) => now - b.createdAt > b.duration);
    _damageMarks.removeWhere((d) => now - d.createdAt > 1.2);
    if (_awaitingRematch && now - _awaitingSince > 4) {
      _awaitingRematch = false;
    }
  }

  void _onClientChanged() {
    if (!mounted || _leaving) return;
    final lobby = _client.lobby.value;
    if (widget.fromLobby && lobby != null && !lobby.started) {
      _leaveToLobby();
      return;
    }
    setState(() {});
  }

  // -------------------------------------------------------------------------
  // Ввод
  // -------------------------------------------------------------------------

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    if (event is KeyDownEvent) {
      _pressed.add(key);
      if (key == LogicalKeyboardKey.escape) {
        if (_menuOpen) {
          _resume();
        } else if (!_resultsVisible) {
          _openMenu();
        }
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.tab) {
        if (!_scoreboard) setState(() => _scoreboard = true);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.shiftLeft ||
          key == LogicalKeyboardKey.shiftRight) {
        _dashPending = true;
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyR) {
        _reloadPending = true;
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.space) {
        _spaceFire = true;
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyQ && _vm.spectator) {
        _cycleSpectate(-1);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyE && _vm.spectator) {
        _cycleSpectate(1);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyC) {
        _toggleControls();
        return KeyEventResult.handled;
      }
      if (_isGameKey(key)) return KeyEventResult.handled;
    } else if (event is KeyUpEvent) {
      _pressed.remove(key);
      if (key == LogicalKeyboardKey.tab && _scoreboard) {
        setState(() => _scoreboard = false);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.space) {
        _spaceFire = false;
        return KeyEventResult.handled;
      }
      if (_isGameKey(key)) return KeyEventResult.handled;
    } else if (event is KeyRepeatEvent) {
      _pressed.add(key);
      if (_isGameKey(key)) return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  bool _isGameKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.keyW ||
        key == LogicalKeyboardKey.keyA ||
        key == LogicalKeyboardKey.keyS ||
        key == LogicalKeyboardKey.keyD ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.keyR ||
        key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight ||
        key == LogicalKeyboardKey.keyQ ||
        key == LogicalKeyboardKey.keyE;
  }

  void _setPointer(Offset local) {
    _pointer = local;
    _hasPointer = true;
    _crosshair.value = local;
  }

  void _onPointerDown(PointerDownEvent event) {
    _focusNode.requestFocus();
    if (event.kind == PointerDeviceKind.mouse) {
      _setPointer(event.localPosition);
      if (event.buttons & kPrimaryMouseButton != 0) {
        _mouseFire = true;
      }
    } else if (event.kind == PointerDeviceKind.touch &&
        !_touchControls &&
        _directTouchPointer == null) {
      _directTouchPointer = event.pointer;
      _aimAt(event.localPosition);
      _touchFire = true;
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.kind == PointerDeviceKind.mouse) {
      _setPointer(event.localPosition);
      if (event.buttons & kPrimaryMouseButton == 0) _mouseFire = false;
    } else if (event.pointer == _directTouchPointer) {
      _aimAt(event.localPosition);
    }
  }

  void _onPointerHover(PointerHoverEvent event) {
    if (event.kind == PointerDeviceKind.mouse) {
      _setPointer(event.localPosition);
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (event.kind == PointerDeviceKind.mouse) {
      _mouseFire = false;
    } else if (event.pointer == _directTouchPointer) {
      _directTouchPointer = null;
      _touchFire = false;
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer == _directTouchPointer) {
      _directTouchPointer = null;
      _touchFire = false;
    }
    if (event.kind == PointerDeviceKind.mouse) _mouseFire = false;
  }

  void _aimAt(Offset local) {
    final snap = _client.snapshot.value;
    final self = snap?.playerById(_client.id);
    final pos = self != null ? Offset(self.x, self.y) : _vm.myActor?.pos;
    if (pos == null) return;
    final world = _vm.screenToWorld(local);
    final dx = world.dx - pos.dx;
    final dy = world.dy - pos.dy;
    if (dx.abs() + dy.abs() < 0.01) return;
    _aim = math.atan2(dy, dx);
    _crosshair.value = local;
  }

  void _onLeftStick(Offset value) {
    _leftStick = value;
  }

  void _onAimStick(Offset value) {
    _rightStick = value;
    final magnitude = value.distance;
    if (magnitude > 0.14) {
      _aim = math.atan2(value.dy, value.dx);
    }
    _touchFire = magnitude > 0.5;
  }

  void _onAimReleased() {
    _rightStick = Offset.zero;
    _touchFire = false;
  }

  void _onFireDown() {
    _touchHoldFire = true;
    unawaited(HapticFeedback.selectionClick());
  }

  void _onFireUp() {
    _touchHoldFire = false;
  }

  void _cycleSpectate(int delta) {
    final snap = _client.snapshot.value;
    final ids = <int>[];
    if (snap != null) {
      for (final row in snap.scoreboard) {
        if (row.alive && row.id != _client.id) ids.add(row.id);
      }
    } else {
      for (final actor in _vm.actors.values) {
        if (actor.alive && !actor.isSelf) ids.add(actor.id);
      }
    }
    if (ids.isEmpty) return;
    ids.sort();
    var index = ids.indexOf(_vm.spectateTargetId);
    if (index < 0) index = 0;
    index = (index + delta) % ids.length;
    if (index < 0) index += ids.length;
    setState(() => _vm.chooseSpectate(ids[index]));
  }

  void _toggleControls() {
    setState(() {
      _touchControls = !_touchControls;
      _leftStick = Offset.zero;
      _rightStick = Offset.zero;
      _touchFire = false;
      _touchHoldFire = false;
      _mouseFire = false;
      _spaceFire = false;
    });
    _settings.setInputMode(_touchControls ? 1 : 2);
    _focusNode.requestFocus();
  }

  // -------------------------------------------------------------------------
  // Меню и выход
  // -------------------------------------------------------------------------

  bool get _resultsVisible {
    final snap = _vm.snapshot;
    return snap != null &&
        snap.phase == MatchPhase.finished &&
        snap.results.isNotEmpty;
  }

  void _openMenu() {
    if (_leaving || _resultsVisible) return;
    unawaited(_audio.playUi());
    setState(() {
      _menuOpen = true;
      _mouseFire = false;
      _spaceFire = false;
      _touchFire = false;
      _touchHoldFire = false;
      _leftStick = Offset.zero;
      _rightStick = Offset.zero;
      _dashPending = false;
      _reloadPending = false;
    });
    if (widget.room.isPractice && !_client.paused) {
      _client.togglePause();
    }
  }

  void _resume() {
    unawaited(_audio.playUi());
    if (widget.room.isPractice && _client.paused) {
      _client.togglePause();
    }
    setState(() => _menuOpen = false);
    _pressed.clear();
    _focusNode.requestFocus();
  }

  void _handleBack() {
    if (_menuOpen) {
      _resume();
    } else if (_resultsVisible) {
      unawaited(_exitToMenu());
    } else {
      _openMenu();
    }
  }

  void _playAgain() {
    if (_awaitingRematch) return;
    setState(() {
      _awaitingRematch = true;
      _awaitingSince = _vm.time;
    });
    _client.playAgain();
  }

  void _requestLobby() {
    if (_leaving || _awaitingLobby) return;
    if (!widget.fromLobby || !_client.isHost) return;
    setState(() => _awaitingLobby = true);
    _client.returnToLobby();
  }

  void _leaveToLobby() {
    if (_leaving) return;
    setState(() {
      _leaving = true;
      _awaitingLobby = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  Future<void> _exitToMenu() async {
    if (_leaving || _exitPromptOpen) return;
    unawaited(_audio.playUi());
    _exitPromptOpen = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Palette.surfaceAlt,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Palette.line),
        ),
        title: const Text('Выйти из игры?'),
        content: Text(
          widget.room.isPractice
              ? 'Тренировка завершится, и вы вернётесь в главное меню.'
              : 'Вы покинете комнату. Для друзей она закроется, если вы хост.',
          style: const TextStyle(color: Palette.muted),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              unawaited(_audio.playUi());
              Navigator.of(context).pop(false);
            },
            child: const Text('Продолжить игру'),
          ),
          TextButton(
            onPressed: () {
              unawaited(_audio.playUi());
              Navigator.of(context).pop(true);
            },
            child: const Text('Выйти', style: TextStyle(color: Palette.danger)),
          ),
        ],
      ),
    );
    _exitPromptOpen = false;
    if (confirmed != true || !mounted || _leaving) return;
    setState(() => _leaving = true);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    try {
      await widget.room.close();
    } catch (_) {
      // Комната могла быть уже закрыта.
    }
    if (!mounted) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  // -------------------------------------------------------------------------
  // Разметка
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final client = _client;
    final media = MediaQuery.sizeOf(context);
    final compact = media.width < 680 || media.height < 470;
    final snapshot = _vm.snapshot;
    final results = _resultsVisible;
    final error = client.error.value;

    return PopScope<Object?>(
      canPop: _leaving,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || _leaving) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: Palette.bg,
        body: Focus(
          focusNode: _focusNode,
          autofocus: true,
          onKeyEvent: _onKey,
          onFocusChange: (focused) {
            if (!focused) _pressed.clear();
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              _vm.ensureViewport(constraints.biggest);
              return Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  RepaintBoundary(
                    child: MouseRegion(
                      cursor: _touchControls
                          ? SystemMouseCursors.basic
                          : SystemMouseCursors.none,
                      child: Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: _onPointerDown,
                        onPointerMove: _onPointerMove,
                        onPointerHover: _onPointerHover,
                        onPointerUp: _onPointerUp,
                        onPointerCancel: _onPointerCancel,
                        child: CustomPaint(
                          painter: ArenaPainter(_vm),
                          isComplex: true,
                          willChange: true,
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _CombatOverlayPainter(
                          vm: _vm,
                          crosshair: _crosshair,
                          touch: _touchControls,
                          hasPointer: _hasPointer,
                          damage: _damageMarks,
                          hitAt: _hitAt,
                          killAt: _killAt,
                          firing:
                              _mouseFire ||
                              _spaceFire ||
                              _touchFire ||
                              _touchHoldFire,
                        ),
                      ),
                    ),
                  ),
                  GameHud(
                    vm: _vm,
                    snapshot: snapshot,
                    myId: client.id,
                    ping: client.latency.value,
                    fps: _fps,
                    killfeed: _killfeed,
                    banners: _banners,
                    touchControls: _touchControls,
                    scoreboardVisible: _scoreboard,
                    compact: compact,
                    onPause: _openMenu,
                    onToggleScoreboard: () {
                      setState(() => _scoreboard = !_scoreboard);
                    },
                    onToggleControls: _toggleControls,
                  ),
                  if (_touchControls &&
                      !_vm.spectator &&
                      !results &&
                      !_menuOpen)
                    Positioned.fill(
                      child: TouchControlsLayer(
                        onMoveChanged: _onLeftStick,
                        onMoveReleased: () => _leftStick = Offset.zero,
                        onAimChanged: _onAimStick,
                        onAimReleased: _onAimReleased,
                        onFireDown: _onFireDown,
                        onFireUp: _onFireUp,
                        onDash: () => _dashPending = true,
                        onReload: () => _reloadPending = true,
                        dashProgress: _myDashProgress,
                        reloadProgress: _myReloadProgress,
                        reloading: _vm.myActor?.reloading == true,
                        enabled: !_leaving,
                      ),
                    ),
                  if (snapshot != null &&
                      snapshot.phase == MatchPhase.countdown &&
                      !_menuOpen &&
                      !results)
                    _CountdownOverlay(
                      seconds: snapshot.phaseTime,
                      touch: _touchControls,
                      compact: compact,
                    ),
                  if (_scoreboard && snapshot != null && !results)
                    ScoreboardOverlay(
                      snapshot: snapshot,
                      myId: client.id,
                      onClose: () => setState(() => _scoreboard = false),
                    ),
                  if (_menuOpen)
                    _GameMenu(
                      practice: widget.room.isPractice,
                      touchControls: _touchControls,
                      paused: client.paused,
                      onResume: _resume,
                      onSettings: _openSettings,
                      onToggleControls: _toggleControls,
                      onExit: () => unawaited(_exitToMenu()),
                      lobbyMode: widget.fromLobby,
                      canLobby: widget.fromLobby && client.isHost,
                      awaitingLobby: _awaitingLobby,
                      onLobby: _requestLobby,
                      compact: compact,
                    ),
                  if (snapshot != null &&
                      !results &&
                      (_vm.spectator ||
                          (snapshot.respawn && snapshot.respawnRemaining > 0)))
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: _touchControls ? 236 : 104,
                      child: Center(child: _gameStatusBar(snapshot)),
                    ),
                  if (results)
                    ResultsOverlay(
                      snapshot: snapshot!,
                      myId: client.id,
                      isHost: client.isHost,
                      awaiting: _awaitingRematch,
                      onAgain: _playAgain,
                      onExit: () => unawaited(_exitToMenu()),
                      lobbyMode: widget.fromLobby,
                      canLobby: widget.fromLobby && client.isHost,
                      awaitingLobby: _awaitingLobby,
                      onLobby: _requestLobby,
                    ),
                  if (error != null && !_leaving)
                    _ErrorOverlay(
                      message: error,
                      onExit: () => unawaited(_exitToMenu()),
                    ),
                  if (_leaving) const _LeavingOverlay(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  double get _myDashProgress {
    final cooldown = _vm.myActor?.dashCooldown ?? 0;
    if (cooldown <= 0) return 0;
    return (1 - cooldown / 2.6).clamp(0.0, 1.0);
  }

  double get _myReloadProgress {
    final actor = _vm.myActor;
    if (actor == null || !actor.reloading) return 0;
    final total = weaponByIndex(actor.weapon).reloadTime;
    if (total <= 0) return 0;
    return (1 - actor.reloadRemaining / total).clamp(0.0, 1.0);
  }

  Widget _gameStatusBar(Snapshot snapshot) {
    final focus = _vm.focusActor;
    final respawnRemaining = snapshot.respawnRemaining;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (snapshot.respawn && respawnRemaining > 0) ...<Widget>[
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Palette.accent.withValues(alpha: 0.45)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.restart_alt_rounded,
                  size: 16,
                  color: Palette.accent,
                ),
                const SizedBox(width: 7),
                Text(
                  'ВОЗРОЖДЕНИЕ ЧЕРЕЗ ${respawnRemaining.ceil()} С · СОЮЗНИК ЖИВ',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: Palette.accent,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (_vm.spectator)
          _SpectatorBar(
            name: focus?.name,
            onPrev: () => _cycleSpectate(-1),
            onNext: () => _cycleSpectate(1),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Экранный прицел, хитмаркеры и индикаторы урона
// ---------------------------------------------------------------------------

class _CombatOverlayPainter extends CustomPainter {
  _CombatOverlayPainter({
    required this.vm,
    required this.crosshair,
    required this.touch,
    required this.hasPointer,
    required this.damage,
    required this.hitAt,
    required this.killAt,
    required this.firing,
  }) : super(repaint: Listenable.merge(<Listenable>[vm.repaint, crosshair]));

  final GameViewModel vm;
  final ValueNotifier<Offset> crosshair;
  final bool touch;
  final bool hasPointer;
  final List<DamageMark> damage;
  final double hitAt;
  final double killAt;
  final bool firing;

  @override
  void paint(Canvas canvas, Size size) {
    if (vm.maze == null) return;
    final center = size.center(Offset.zero);

    for (final mark in damage) {
      final t = (vm.time - mark.createdAt) / 1.15;
      if (t < 0 || t > 1) continue;
      final alpha = (1 - t).clamp(0.0, 1.0);
      final radius = math.min(size.width, size.height) * 0.25;
      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawArc(
        rect,
        mark.angle - 0.24,
        0.48,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 6 * (1 - t * 0.55)
          ..color = Palette.danger.withValues(alpha: alpha * 0.8),
      );
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius + 7),
        mark.angle - 0.13,
        0.26,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 2
          ..color = Palette.danger.withValues(alpha: alpha * 0.35),
      );
    }

    final me = vm.myActor;
    if (me == null || vm.spectator) return;
    final playerScreen = vm.worldToScreen(me.pos);
    final dir = Offset(math.cos(vm.myAim), math.sin(vm.myAim));
    final Offset cross;
    if (!touch && hasPointer) {
      cross = crosshair.value;
    } else {
      cross = playerScreen + dir * (touch ? 148 : 176);
    }

    canvas.drawLine(
      playerScreen + dir * (kPlayerRadius + 12),
      cross - dir * 15,
      Paint()
        ..strokeWidth = 1
        ..color = Palette.accent.withValues(alpha: 0.18),
    );

    final color = firing ? Palette.magenta : Palette.accent;
    final reticle = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = color.withValues(alpha: 0.92);
    final inner = touch ? 9.0 : 7.5;
    canvas.drawCircle(cross, inner, reticle);
    canvas.drawCircle(cross, 2, Paint()..color = color.withValues(alpha: 0.95));
    final tick = Paint()
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.75);
    for (var i = 0; i < 4; i++) {
      final a = i * math.pi / 2;
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(cross + d * (inner + 3), cross + d * (inner + 9), tick);
    }

    _marker(canvas, cross, hitAt, 0.23, color, 8);
    _marker(canvas, cross, killAt, 0.6, Palette.gold, 12);
  }

  void _marker(
    Canvas canvas,
    Offset center,
    double at,
    double duration,
    Color color,
    double base,
  ) {
    final t = (vm.time - at) / duration;
    if (t < 0 || t > 1) return;
    final alpha = (1 - t).clamp(0.0, 1.0);
    final size = base + t * 9;
    final paint = Paint()
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: alpha);
    for (var i = 0; i < 4; i++) {
      final a = math.pi / 4 + i * math.pi / 2;
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(center + d * (size * 0.35), center + d * size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CombatOverlayPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Оверлеи
// ---------------------------------------------------------------------------

class _CountdownOverlay extends StatelessWidget {
  const _CountdownOverlay({
    required this.seconds,
    required this.touch,
    required this.compact,
  });

  final double seconds;
  final bool touch;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final count = seconds.ceil().clamp(1, kCountdownSeconds);
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'ПРИГОТОВЬТЕСЬ',
                style: TextStyle(
                  fontSize: compact ? 12 : 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 5,
                  color: Palette.muted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: compact ? 72 : 104,
                  fontWeight: FontWeight.w900,
                  height: 0.95,
                  color: Palette.accent,
                  shadows: <Shadow>[
                    Shadow(
                      color: Palette.accent.withValues(alpha: 0.5),
                      blurRadius: 30,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                constraints: const BoxConstraints(maxWidth: 560),
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Palette.line.withValues(alpha: 0.8),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      touch
                          ? 'Левый стик — движение · правый — прицел и огонь'
                          : 'WASD — движение · мышь — прицел · ЛКМ / пробел — огонь',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Palette.text,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      touch ? 'Кнопки справа: рывок, перезарядка, огонь' : 'Shift — рывок · R — перезарядка · Tab — таблица · Esc — меню',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Palette.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpectatorBar extends StatelessWidget {
  const _SpectatorBar({
    required this.name,
    required this.onPrev,
    required this.onNext,
  });

  final String? name;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF7FB2FF).withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          NeonIconButton(
            icon: Icons.chevron_left_rounded,
            size: 34,
            onPressed: onPrev,
            tooltip: 'Предыдущий (Q)',
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              const Text(
                'ВЫ УСТРАНЕНЫ · НАБЛЮДЕНИЕ',
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: Color(0xFF7FB2FF),
                ),
              ),
              Text(
                name ?? 'Матч завершается…',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Palette.text,
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          NeonIconButton(
            icon: Icons.chevron_right_rounded,
            size: 34,
            onPressed: onNext,
            tooltip: 'Следующий (E)',
          ),
        ],
      ),
    );
  }
}

class _GameMenu extends StatelessWidget {
  const _GameMenu({
    required this.practice,
    required this.touchControls,
    required this.paused,
    required this.onResume,
    required this.onSettings,
    required this.onToggleControls,
    required this.onExit,
    required this.lobbyMode,
    required this.canLobby,
    required this.awaitingLobby,
    required this.onLobby,
    required this.compact,
  });

  final bool practice;
  final bool touchControls;
  final bool paused;
  final VoidCallback onResume;
  final VoidCallback onSettings;
  final VoidCallback onToggleControls;
  final VoidCallback onExit;
  final bool lobbyMode;
  final bool canLobby;
  final bool awaitingLobby;
  final VoidCallback onLobby;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.72),
        padding: const EdgeInsets.all(18),
        child: Center(
          child: SingleChildScrollView(
            child: NeonPanel(
              padding: const EdgeInsets.all(20),
              glow: true,
              borderColor: Palette.accent.withValues(alpha: 0.35),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(
                          practice
                              ? Icons.pause_circle_outline_rounded
                              : Icons.sports_esports_rounded,
                          size: 24,
                          color: Palette.accent,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          practice ? 'ПАУЗА' : 'МЕНЮ',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      practice
                          ? 'Тренировка остановлена. Можно спокойно вернуться в бой.'
                          : 'В сетевой игре матч не останавливается. Соперники могут атаковать.',
                      style: const TextStyle(
                        fontSize: 11.5,
                        height: 1.45,
                        color: Palette.muted,
                      ),
                    ),
                    const SizedBox(height: 16),
                    NeonButton(
                      label: 'Продолжить',
                      icon: Icons.play_arrow_rounded,
                      primary: true,
                      height: 50,
                      onPressed: onResume,
                    ),
                    const SizedBox(height: 9),
                    NeonButton(
                      label: touchControls
                          ? 'Управление: сенсор'
                          : 'Управление: мышь',
                      subtitle: 'Нажмите, чтобы переключить',
                      icon: touchControls
                          ? Icons.touch_app_rounded
                          : Icons.mouse_rounded,
                      height: 50,
                      onPressed: onToggleControls,
                    ),
                    const SizedBox(height: 9),
                    NeonButton(
                      label: 'Настройки игры',
                      subtitle: 'Звук, управление и графика',
                      icon: Icons.settings_outlined,
                      height: 50,
                      onPressed: onSettings,
                    ),
                    const SizedBox(height: 9),
                    if (lobbyMode) ...<Widget>[
                      NeonButton(
                        label: canLobby ? 'В лобби' : 'Ждём хоста',
                        subtitle: canLobby
                            ? 'Сменить настройки без пересоздания комнаты'
                            : 'Хост вернёт всех в лобби',
                        icon: Icons.meeting_room_outlined,
                        busy: awaitingLobby,
                        height: 50,
                        onPressed: canLobby && !awaitingLobby ? onLobby : null,
                      ),
                      const SizedBox(height: 9),
                    ],
                    NeonButton(
                      label: 'Покинуть игру',
                      subtitle: practice
                          ? 'Вернуться в главное меню'
                          : 'Выйти из комнаты',
                      icon: Icons.exit_to_app_rounded,
                      danger: true,
                      height: 50,
                      onPressed: onExit,
                    ),
                    if (!compact) ...<Widget>[
                      const SizedBox(height: 16),
                      const SectionLabel('Управление'),
                      const SizedBox(height: 8),
                      Text(
                        touchControls
                            ? 'Левый стик — движение. Правый стик — прицел и автоматический огонь. '
                                  'Огонь — удержание кнопки. Рывок и перезарядка — кнопки справа.'
                            : 'WASD — движение. Мышь — прицел. ЛКМ или пробел — огонь. '
                                  'Shift — рывок. R — перезарядка. Tab — таблица. Esc — меню. '
                                  'C — переключить управление.',
                        style: const TextStyle(
                          fontSize: 10.5,
                          height: 1.5,
                          color: Palette.mutedDark,
                        ),
                      ),
                    ],
                    if (practice && paused) ...<Widget>[
                      const SizedBox(height: 10),
                      const Text(
                        'Сервер на паузе',
                        style: TextStyle(
                          fontSize: 9,
                          color: Palette.accentDeep,
                          letterSpacing: 0.6,
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

class _ErrorOverlay extends StatelessWidget {
  const _ErrorOverlay({required this.message, required this.onExit});

  final String message;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.8),
        padding: const EdgeInsets.all(20),
        child: Center(
          child: NeonPanel(
            padding: const EdgeInsets.all(22),
            borderColor: Palette.danger.withValues(alpha: 0.5),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    Icons.wifi_off_rounded,
                    size: 38,
                    color: Palette.danger,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'СОЕДИНЕНИЕ ПОТЕРЯНО',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: Palette.muted,
                    ),
                  ),
                  const SizedBox(height: 18),
                  NeonButton(
                    label: 'В меню',
                    icon: Icons.home_outlined,
                    expand: false,
                    height: 46,
                    onPressed: onExit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LeavingOverlay extends StatelessWidget {
  const _LeavingOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.6),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Palette.accent,
                ),
              ),
              SizedBox(height: 14),
              Text(
                'ВЫХОДИМ ИЗ МАТЧА…',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                  color: Palette.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

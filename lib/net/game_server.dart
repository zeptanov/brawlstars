import 'dart:async';
import 'dart:math' as math;

import '../game/constants.dart';
import '../game/sim.dart';
import '../net/messages.dart';

class _Peer {
  _Peer({
    required this.id,
    required this.name,
    required this.send,
    required this.local,
  });

  final int id;
  final String name;
  final void Function(Map<String, dynamic> message) send;
  final bool local;
  DateTime lastSeen = DateTime.now();
  int spectateId = 0;
}

/// Авторитетный сервер комнаты. Один и тот же код обслуживает
/// LAN-игру и офлайн-тренировку с ботами.
class GameServer {
  GameServer({
    required this.roomName,
    required this.hostName,
    this.allowPause = false,
  }) : roomId = _randomRoomId();

  final String roomName;
  final String hostName;
  final String roomId;
  final bool allowPause;

  final Map<int, _Peer> _peers = <int, _Peer>{};
  final List<ChatLine> _chat = <ChatLine>[];
  final math.Random _rng = math.Random();

  int _nextId = 1;
  int hostId = 0;
  int botCount = 0;
  int mapSize = kDefaultMapSize;
  int mapGeneration = 0;
  int tempo = 1;
  int skill = 1;
  bool teams = false;
  int deathVision = 1;
  int loot = 1;
  bool friendlyFire = false;
  bool respawn = false;
  int respawnDelay = kDefaultRespawnDelay;
  bool allyVision = true;

  bool started = false;
  bool paused = false;
  GameSim? sim;

  int _matchSeed = 0;
  Timer? _ticker;
  Timer? _heartbeat;
  final Stopwatch _clock = Stopwatch();
  Duration _lastElapsed = Duration.zero;
  double _simAccum = 0;
  double _snapAccum = 0;

  int get humanCount => _peers.length;
  bool get isEmpty => _peers.isEmpty;
  int get totalPlayers =>
      sim?.players.length ?? (_peers.length + botCount).clamp(0, kMaxPlayers);

  static String _randomRoomId() {
    final rng = math.Random();
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  static String _sanitizeName(String raw) {
    var name = raw.replaceAll(RegExp(r'[\u0000-\u001F]'), '').trim();
    if (name.isEmpty) name = 'Игрок';
    if (name.length > 16) name = name.substring(0, 16);
    return name;
  }

  static double skillValue(int value) {
    switch (value) {
      case 0:
        return 0.55;
      case 2:
        return 1.5;
      default:
        return 1.0;
    }
  }

  // -------------------------------------------------------------------------
  // Подключение
  // -------------------------------------------------------------------------

  int addPeer({
    required String name,
    required void Function(Map<String, dynamic>) send,
    bool local = false,
  }) {
    final id = _nextId++;
    final peer = _Peer(
      id: id,
      name: _sanitizeName(name),
      send: send,
      local: local,
    );
    _peers[id] = peer;
    if (hostId == 0) hostId = id;

    _sendHi(peer);
    _broadcastLobby();
    _ensureHeartbeat();

    if (started && sim != null) {
      final phase = sim!.phase;
      if (phase != MatchPhase.finished) {
        sim!.addPlayer(
          PlayerSpec(
            id: id,
            name: peer.name,
            isBot: false,
            team: _teamForJoin(),
          ),
        );
        _broadcast({'t': 'notice', 'm': '${peer.name} подключился к бою'});
        _broadcastLobby();
      }
    }
    return id;
  }

  int _teamForJoin() {
    final live = sim;
    if (!teams || live == null) return -1;
    final counts = <int, int>{};
    for (final p in live.players.values) {
      if (p.team < 0) continue;
      counts[p.team] = (counts[p.team] ?? 0) + 1;
    }
    for (var t = 0; t < kMaxPlayers; t++) {
      if ((counts[t] ?? 0) < kTeamSize) return t;
    }
    return counts.length;
  }

  void _sendHi(_Peer peer) {
    final live = sim;
    _send(peer.id, <String, dynamic>{
      't': 'hi',
      'id': peer.id,
      'host': hostId,
      'room': roomName,
      'seed': live?.seed ?? 0,
      'size': live?.mapSize ?? mapSize,
      'mg': mapGeneration,
      'ver': kProtocolVersion,
      'name': peer.name,
    });
  }

  void removePeer(int id) {
    final peer = _peers.remove(id);
    if (peer == null) return;
    sim?.removePlayer(id);
    if (hostId == id) {
      hostId = _peers.isEmpty ? 0 : _peers.keys.first;
    }
    _broadcastLobby();
    if (_peers.isEmpty) {
      _stopMatch();
    }
  }

  void _kick(int id, String reason) {
    final peer = _peers[id];
    if (peer == null) return;
    _send(id, <String, dynamic>{'t': 'bye', 'reason': reason});
    removePeer(id);
  }

  // -------------------------------------------------------------------------
  // Сообщения
  // -------------------------------------------------------------------------

  void handleMessage(int id, Map<String, dynamic> message) {
    final peer = _peers[id];
    if (peer == null) return;
    peer.lastSeen = DateTime.now();
    final type = '${message['t']}';

    switch (type) {
      case 'join':
        _sendHi(peer);
        _broadcastLobby();
      case 'ping':
        _send(id, <String, dynamic>{'t': 'pong', 'ts': message['ts']});
      case 'in':
        final live = sim;
        if (!started || live == null) return;
        final player = live.players[id];
        if (player == null || !player.alive) return;
        if (live.phase == MatchPhase.finished) return;
        player.input = InputState.fromJson(message);
      case 'chat':
        _handleChat(peer, '${message['m'] ?? ''}');
      case 'leave':
        removePeer(id);
      case 'spec':
        peer.spectateId = (message['id'] as num?)?.toInt() ?? 0;
      case 'cmd':
        if (id != hostId) return;
        _handleCommand('${message['c']}', message);
    }
  }

  void _handleChat(_Peer peer, String raw) {
    var text = raw.replaceAll(RegExp(r'[\u0000-\u001F]'), ' ').trim();
    if (text.isEmpty) return;
    if (text.length > 140) text = text.substring(0, 140);
    _chat.add(ChatLine(peer.id, peer.name, text));
    while (_chat.length > 40) {
      _chat.removeAt(0);
    }
    _broadcastLobby();
  }

  void _handleCommand(String command, Map<String, dynamic> message) {
    switch (command) {
      case 'start':
        if (started) return;
        startMatch();
      case 'again':
        if (started && sim?.phase != MatchPhase.finished) return;
        startMatch();
      case 'bots':
        final next = (message['n'] as num?)?.toInt() ?? botCount;
        botCount = next.clamp(0, kMaxPlayers);
        _broadcastLobby();
      case 'map':
        mapSize = (message['n'] as num?)?.toInt() ?? mapSize;
        if (!kMapSizes.contains(mapSize)) mapSize = kDefaultMapSize;
        _broadcastLobby();
      case 'generation':
        mapGeneration = ((message['n'] as num?)?.toInt() ?? mapGeneration)
            .clamp(0, kMapGenerationCount - 1);
        _broadcastLobby();
      case 'tempo':
        tempo = ((message['n'] as num?)?.toInt() ?? tempo).clamp(0, 2);
        _broadcastLobby();
      case 'skill':
        skill = ((message['n'] as num?)?.toInt() ?? skill).clamp(0, 2);
        _broadcastLobby();
      case 'teams':
        teams = ((message['n'] as num?)?.toInt() ?? (teams ? 1 : 0)) == 1;
        _broadcastLobby();
      case 'death':
        deathVision = ((message['n'] as num?)?.toInt() ?? deathVision).clamp(
          0,
          1,
        );
        _broadcastLobby();
      case 'loot':
        loot = ((message['n'] as num?)?.toInt() ?? loot).clamp(0, 2);
        _broadcastLobby();
      case 'ff':
        friendlyFire =
            ((message['n'] as num?)?.toInt() ?? (friendlyFire ? 1 : 0)) == 1;
        _broadcastLobby();
      case 'respawn':
        respawn = ((message['n'] as num?)?.toInt() ?? (respawn ? 1 : 0)) == 1;
        _broadcastLobby();
      case 'respawnDelay':
        respawnDelay = ((message['n'] as num?)?.toInt() ?? respawnDelay).clamp(
          kMinRespawnDelay,
          kMaxRespawnDelay,
        );
        _broadcastLobby();
      case 'allyVision':
        allyVision =
            ((message['n'] as num?)?.toInt() ?? (allyVision ? 1 : 0)) == 1;
        _broadcastLobby();
      case 'lobby':
        if (!started) return;
        _stopMatch();
        for (final peer in _peers.values) {
          peer.spectateId = 0;
        }
        _ensureHeartbeat();
        _broadcastLobby();
      case 'pause':
        if (!allowPause || !started) return;
        paused = !paused;
        _broadcastLobby();
      case 'kick':
        final target = (message['id'] as num?)?.toInt() ?? 0;
        if (target != hostId) {
          _kick(target, 'Вас исключил хост');
        }
    }
  }

  void _broadcastLobby() {
    final payload = _lobbyJson();
    for (final peer in _peers.values) {
      _send(peer.id, payload);
    }
  }

  Map<String, dynamic> _lobbyJson() {
    final peers = _peers.values.toList();
    final players = <List<Object?>>[];
    for (var i = 0; i < peers.length; i++) {
      final peer = peers[i];
      var team = -1;
      final live = sim?.players[peer.id];
      if (live != null) {
        team = live.team;
      } else if (teams) {
        team = i ~/ kTeamSize;
      }
      players.add(<Object?>[peer.id, peer.name, 0, team]);
    }
    return <String, dynamic>{
      't': 'lobby',
      'room': roomName,
      'p': players,
      'host': hostId,
      'started': started ? 1 : 0,
      'paused': paused ? 1 : 0,
      'bots': botCount,
      'max': kMaxPlayers,
      'map': mapSize,
      'mg': mapGeneration,
      'tempo': tempo,
      'skill': skill,
      'tms': teams ? 1 : 0,
      'dv': deathVision,
      'loot': loot,
      'ff': friendlyFire ? 1 : 0,
      'rs': respawn ? 1 : 0,
      'rsec': respawnDelay,
      'av': allyVision ? 1 : 0,
      'seed': sim?.seed ?? 0,
      'chat': _chat.map((c) => c.toList()).toList(),
      'canPause': allowPause ? 1 : 0,
      'code': roomId,
    };
  }

  // -------------------------------------------------------------------------
  // Матч
  // -------------------------------------------------------------------------

  /// Запускает новый матч (используется и для реванша).
  void startMatch() {
    final specs = <PlayerSpec>[];
    for (final peer in _peers.values) {
      specs.add(PlayerSpec(id: peer.id, name: peer.name, isBot: false));
    }

    final roomForBots = (kMaxPlayers - specs.length).clamp(0, kMaxPlayers);
    var botTarget = botCount.clamp(0, roomForBots);
    if (teams) {
      // Командный режим: минимум две команды по kTeamSize и ровное число
      // бойцов, чтобы у каждого был напарник.
      final minimum = kTeamSize * 2;
      var total = specs.length + botTarget;
      while ((total < minimum || total.isOdd) && botTarget < roomForBots) {
        botTarget++;
        total++;
      }
      if (total < minimum) {
        if (hostId != 0) {
          _send(hostId, <String, dynamic>{
            't': 'notice',
            'm': 'Для командной игры нужно минимум $minimum бойцов.',
          });
        }
        return;
      }
    } else if (specs.length + botTarget < 2) {
      if (hostId != 0) {
        _send(hostId, <String, dynamic>{
          't': 'notice',
          'm': 'Нужен хотя бы один соперник — добавьте ботов или позовите друга.',
        });
      }
      return;
    }

    final usedNames = specs.map((s) => s.name).toSet();
    final botNames = List<String>.of(kBotNames)..shuffle(_rng);
    var nameIndex = 0;
    for (var i = 0; i < botTarget; i++) {
      var name = botNames[nameIndex % botNames.length];
      var guard = 0;
      while (usedNames.contains(name) && guard++ < botNames.length) {
        nameIndex++;
        name = botNames[nameIndex % botNames.length];
      }
      nameIndex++;
      usedNames.add(name);
      specs.add(PlayerSpec(id: _nextId++, name: name, isBot: true));
    }

    if (teams) {
      for (var i = 0; i < specs.length; i++) {
        final s = specs[i];
        specs[i] = PlayerSpec(
          id: s.id,
          name: s.name,
          isBot: s.isBot,
          team: i ~/ kTeamSize,
        );
      }
    }

    _matchSeed = _rng.nextInt(1 << 31);
    sim = GameSim(
      seed: _matchSeed,
      mapSize: mapSize,
      mapGeneration: mapGeneration,
      specs: specs,
      tempo: tempo,
      botSkill: skillValue(skill),
      teams: teams,
      friendlyFire: friendlyFire,
      deathVision: deathVision,
      loot: loot,
      respawn: respawn,
      respawnDelay: respawnDelay,
      allyVision: allyVision,
    );
    started = true;
    paused = false;
    for (final peer in _peers.values) {
      peer.spectateId = 0;
    }
    _broadcast(<String, dynamic>{
      't': 'w',
      'seed': _matchSeed,
      'size': mapSize,
      'mg': mapGeneration,
    });
    _broadcastLobby();
    _ensureTicker();
  }

  void _stopMatch() {
    started = false;
    paused = false;
    sim = null;
    _ticker?.cancel();
    _ticker = null;
    _heartbeat?.cancel();
    _heartbeat = null;
    _clock.stop();
    _clock.reset();
    _lastElapsed = Duration.zero;
    _simAccum = 0;
    _snapAccum = 0;
  }

  void _ensureTicker() {
    _heartbeat ??= Timer.periodic(const Duration(seconds: 1), (_) {
      _broadcast(<String, dynamic>{'t': 'hb'});
      _broadcastLobby();
    });
    if (_ticker != null) return;
    _clock
      ..reset()
      ..start();
    _lastElapsed = Duration.zero;
    _simAccum = 0;
    _snapAccum = kSnapshotInterval;
    _ticker = Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => _onTick(),
    );
  }

  void _ensureHeartbeat() {
    _heartbeat ??= Timer.periodic(const Duration(seconds: 1), (_) {
      _broadcast(<String, dynamic>{'t': 'hb'});
      _broadcastLobby();
    });
  }

  void _onTick() {
    final live = sim;
    final elapsed = _clock.elapsed;
    var delta = (elapsed - _lastElapsed).inMicroseconds / 1000000.0;
    _lastElapsed = elapsed;
    if (live == null) return;
    if (paused) return;
    if (delta < 0) delta = 0;
    if (delta > 0.25) delta = 0.25;

    _simAccum += delta;
    var steps = 0;
    while (_simAccum >= kSimDt && steps < 4) {
      live.step(kSimDt);
      _simAccum -= kSimDt;
      steps++;
    }
    _snapAccum += delta;
    if (_snapAccum >= kSnapshotInterval) {
      _snapAccum = 0;
      _sendSnapshots();
    }
  }

  void _sendSnapshots() {
    final live = sim;
    if (live == null || _peers.isEmpty) return;
    final events = live.takeEvents();
    for (final peer in _peers.values) {
      final snapshot = live.buildSnapshot(
        peer.id,
        events,
        spectateId: peer.spectateId,
      );
      _send(peer.id, snapshot.toJson());
    }
  }

  void _send(int id, Map<String, dynamic> message) {
    final peer = _peers[id];
    if (peer == null) return;
    try {
      peer.send(message);
    } catch (_) {
      // Сокет мог закрыться — соединение уберёт таймаут.
    }
  }

  void _broadcast(Map<String, dynamic> message) {
    for (final peer in _peers.values) {
      try {
        peer.send(message);
      } catch (_) {
        // ignore
      }
    }
  }

  Map<String, dynamic> discoveryPayload({required int port}) =>
      <String, dynamic>{
        't': 'disc',
        'ver': kProtocolVersion,
        'id': roomId,
        'room': roomName,
        'host': hostName,
        'port': port,
        'players': _peers.length,
        'bots': botCount,
        'max': kMaxPlayers,
        'phase': started ? (sim?.phase.index ?? 0) : -1,
      };

  void dispose() {
    _broadcast(<String, dynamic>{'t': 'bye', 'reason': 'Комната закрыта'});
    _stopMatch();
    _peers.clear();
    hostId = 0;
  }
}

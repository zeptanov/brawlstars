import 'dart:async';

import 'package:flutter/foundation.dart';

import '../game/constants.dart';
import '../game/maze.dart';
import 'link.dart';
import 'messages.dart';

/// Клиент комнаты: держит последний снапшот, лобби и отправляет ввод.
class GameClient {
  GameClient({required this.link, required this.playerName});

  final GameLink link;
  final String playerName;

  final ValueNotifier<LobbyState?> lobby = ValueNotifier<LobbyState?>(null);
  final ValueNotifier<Snapshot?> snapshot = ValueNotifier<Snapshot?>(null);
  final ValueNotifier<int> latency = ValueNotifier<int>(0);
  final ValueNotifier<String?> error = ValueNotifier<String?>(null);

  final StreamController<GameEvent> events =
      StreamController<GameEvent>.broadcast();
  final StreamController<String> notices = StreamController<String>.broadcast();

  int id = 0;
  int hostId = 0;
  String roomName = '';
  int mapSize = kDefaultMapSize;
  int mapGeneration = 0;
  int seed = 0;
  Maze? maze;

  StreamSubscription<Map<String, dynamic>>? _subscription;
  Timer? _joinTimer;
  Timer? _pingTimer;
  Timer? _timeoutTimer;
  Timer? _startRetryTimer;
  int _startAttempts = 0;
  bool _welcomed = false;
  Completer<bool>? _welcomeCompleter;

  bool get isHost => id != 0 && id == hostId;
  bool get isConnected => _welcomed && error.value == null;
  bool get started => lobby.value?.started ?? false;
  bool get paused => lobby.value?.paused ?? false;

  /// Подключается и ждёт приветствия. [true] — можно играть.
  Future<bool> connect() {
    _subscription = link.messages.listen(
      _onMessage,
      onError: (Object e) => _fail('Ошибка сети: $e'),
      onDone: () {
        if (error.value == null && !_welcomed) {
          _fail('Сервер закрыл соединение');
        }
      },
    );
    _welcomeCompleter = Completer<bool>();
    _sendJoin();
    _joinTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!_welcomed) _sendJoin();
    });
    _timeoutTimer = Timer(const Duration(seconds: 9), () {
      if (!_welcomed) _fail('Не удалось подключиться к комнате');
    });
    return _welcomeCompleter!.future;
  }

  void _sendJoin() {
    link.send(<String, dynamic>{
      't': 'join',
      'name': playerName,
      'ver': kProtocolVersion,
    });
  }

  void _onMessage(Map<String, dynamic> message) {
    switch ('${message['t']}') {
      case 'hi':
        _handleHi(message);
      case 'w':
        _handleWorld(message);
      case 'lobby':
        final state = LobbyState.fromJson(message);
        final wasStarted = lobby.value?.started ?? false;
        if (state.started && state.seed != 0) {
          _buildMaze(state.seed, state.mapSize, state.mapGeneration);
        }
        roomName = state.roomName;
        hostId = state.hostId;
        lobby.value = state;
        if (state.started) _startRetryTimer?.cancel();
        if (wasStarted && !state.started) {
          snapshot.value = null;
        }
      case 's':
        final parsed = Snapshot.fromJson(message);
        snapshot.value = parsed;
        for (final event in parsed.events) {
          if (!events.isClosed) events.add(event);
        }
      case 'pong':
        final ts = (message['ts'] as num?)?.toInt() ?? 0;
        if (ts > 0) {
          final rtt = DateTime.now().millisecondsSinceEpoch - ts;
          if (rtt >= 0 && rtt < 5000) latency.value = rtt;
        }
      case 'notice':
        if (!notices.isClosed) notices.add('${message['m'] ?? ''}');
      case 'bye':
        _fail('${message['reason'] ?? 'Комната закрыта'}');
      case 'net':
        _fail('Связь потеряна');
      case 'hb':
        break;
    }
  }

  void _handleHi(Map<String, dynamic> message) {
    final version = (message['ver'] as num?)?.toInt() ?? 0;
    if (version != kProtocolVersion) {
      _fail(
        'Несовпадение версий игры. Обновите приложение на обоих устройствах.',
      );
      return;
    }
    id = (message['id'] as num?)?.toInt() ?? 0;
    hostId = (message['host'] as num?)?.toInt() ?? 0;
    roomName = '${message['room'] ?? 'Комната'}';
    final seedValue = (message['seed'] as num?)?.toInt() ?? 0;
    final sizeValue = (message['size'] as num?)?.toInt() ?? kDefaultMapSize;
    final generationValue = ((message['mg'] as num?)?.toInt() ?? 0).clamp(
      0,
      kMapGenerationCount - 1,
    );
    mapSize = sizeValue;
    if (seedValue != 0) {
      _buildMaze(seedValue, sizeValue, generationValue);
    } else {
      mapGeneration = generationValue;
    }
    _welcomed = true;
    _joinTimer?.cancel();
    _timeoutTimer?.cancel();
    _startPing();
    final completer = _welcomeCompleter;
    if (completer != null && !completer.isCompleted) completer.complete(true);
  }

  void _handleWorld(Map<String, dynamic> message) {
    final seedValue = (message['seed'] as num?)?.toInt() ?? 0;
    final sizeValue = (message['size'] as num?)?.toInt() ?? kDefaultMapSize;
    final generationValue = ((message['mg'] as num?)?.toInt() ?? 0).clamp(
      0,
      kMapGenerationCount - 1,
    );
    mapSize = sizeValue;
    snapshot.value = null;
    if (seedValue != 0) {
      _buildMaze(seedValue, sizeValue, generationValue);
    } else {
      mapGeneration = generationValue;
    }
  }

  void _buildMaze(int seedValue, int sizeValue, int generationValue) {
    if (seed == seedValue &&
        maze != null &&
        mapSize == sizeValue &&
        mapGeneration == generationValue) {
      return;
    }
    seed = seedValue;
    mapSize = sizeValue;
    mapGeneration = generationValue;
    try {
      maze = Maze.generate(
        size: sizeValue,
        seed: seedValue,
        generation: generationValue,
      );
    } catch (_) {
      maze = null;
    }
  }

  void _startPing() {
    _pingTimer ??= Timer.periodic(const Duration(milliseconds: 1500), (_) {
      link.send(<String, dynamic>{
        't': 'ping',
        'ts': DateTime.now().millisecondsSinceEpoch,
      });
    });
  }

  void _fail(String reason) {
    if (error.value == null) error.value = reason;
    final completer = _welcomeCompleter;
    if (completer != null && !completer.isCompleted) completer.complete(false);
    _joinTimer?.cancel();
    _timeoutTimer?.cancel();
  }

  // -------------------------------------------------------------------------
  // Отправка
  // -------------------------------------------------------------------------

  void sendInput(InputState input) {
    if (!isConnected) return;
    link.send(<String, dynamic>{'t': 'in', ...input.toJson()});
  }

  void sendCommand(String command, [Map<String, dynamic> extra = const {}]) {
    link.send(<String, dynamic>{'t': 'cmd', 'c': command, ...extra});
  }

  void startMatch() {
    if (!isHost || lobby.value?.started == true) return;
    _startRetryTimer?.cancel();
    _startAttempts = 0;
    _sendStartAttempt();
    _startRetryTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (lobby.value?.started == true || _startAttempts >= 8) {
        _startRetryTimer?.cancel();
        _startRetryTimer = null;
        return;
      }
      _sendStartAttempt();
    });
  }

  void _sendStartAttempt() {
    _startAttempts++;
    sendCommand('start');
  }

  void playAgain() => sendCommand('again');
  void returnToLobby() => sendCommand('lobby');
  void setBots(int count) => sendCommand('bots', <String, dynamic>{'n': count});
  void setMapSize(int size) => sendCommand('map', <String, dynamic>{'n': size});
  void setMapGeneration(int generation) =>
      sendCommand('generation', <String, dynamic>{'n': generation});
  void setTempo(int value) =>
      sendCommand('tempo', <String, dynamic>{'n': value});
  void setSkill(int value) =>
      sendCommand('skill', <String, dynamic>{'n': value});
  void setTeams(bool value) =>
      sendCommand('teams', <String, dynamic>{'n': value ? 1 : 0});
  void setDeathVision(int value) =>
      sendCommand('death', <String, dynamic>{'n': value});
  void setLoot(int value) => sendCommand('loot', <String, dynamic>{'n': value});
  void setFriendlyFire(bool value) =>
      sendCommand('ff', <String, dynamic>{'n': value ? 1 : 0});
  void setRespawn(bool value) =>
      sendCommand('respawn', <String, dynamic>{'n': value ? 1 : 0});
  void setRespawnDelay(int seconds) =>
      sendCommand('respawnDelay', <String, dynamic>{'n': seconds});
  void setAllyVision(bool value) =>
      sendCommand('allyVision', <String, dynamic>{'n': value ? 1 : 0});
  void togglePause() => sendCommand('pause');
  void kick(int playerId) =>
      sendCommand('kick', <String, dynamic>{'id': playerId});

  void spectate(int playerId) {
    if (!isConnected) return;
    link.send(<String, dynamic>{'t': 'spec', 'id': playerId});
  }

  void sendChat(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    link.send(<String, dynamic>{'t': 'chat', 'm': trimmed});
  }

  Future<void> close() async {
    _joinTimer?.cancel();
    _pingTimer?.cancel();
    _timeoutTimer?.cancel();
    _startRetryTimer?.cancel();
    if (_welcomed) {
      try {
        link.send(<String, dynamic>{'t': 'leave'});
      } catch (_) {
        // ссылка уже недоступна
      }
    }
    await _subscription?.cancel();
    await link.close();
  }

  void dispose() {
    _joinTimer?.cancel();
    _pingTimer?.cancel();
    _timeoutTimer?.cancel();
    _startRetryTimer?.cancel();
    unawaited(_subscription?.cancel());
    unawaited(link.close());
    lobby.dispose();
    snapshot.dispose();
    latency.dispose();
    error.dispose();
    events.close();
    notices.close();
  }
}

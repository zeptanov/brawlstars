import 'dart:async';

import '../game/constants.dart';
import '../net/game_client.dart';
import '../net/game_server.dart';
import '../net/lan_types.dart';
import '../net/local_link.dart';
import '../net/transport.dart';

class RoomException implements Exception {
  RoomException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Владение комнатой: сервер (если мы хост), клиент и LAN-сокет.
class Room {
  Room._({
    required this.server,
    required this.client,
    required this.hostHandle,
    required this.isPractice,
    this.remoteEndpoint,
  });

  final GameServer? server;
  final GameClient client;
  final LanHostHandle? hostHandle;
  final bool isPractice;
  final String? remoteEndpoint;
  bool _closed = false;

  bool get isHost => client.isHost;
  bool get isLanHost => hostHandle != null;
  List<String> get addresses => hostHandle?.addresses ?? const <String>[];
  int get port => hostHandle?.port ?? kGamePort;

  String get endpoint {
    final list = addresses;
    if (list.isEmpty) return '';
    final address = list.first;
    return port == kGamePort ? address : '$address:$port';
  }

  static Future<Room> host({required String nickname}) async {
    final server = GameServer(roomName: 'Логово $nickname', hostName: nickname);
    LanHostHandle? handle;
    GameClient? client;
    try {
      handle = await startLanHost(game: server);
      final link = LocalLink.connect(server, nickname);
      client = GameClient(link: link, playerName: nickname);
      final ok = await client.connect();
      if (!ok) {
        throw RoomException(client.error.value ?? 'Не удалось создать комнату');
      }
      return Room._(
        server: server,
        client: client,
        hostHandle: handle,
        isPractice: false,
      );
    } catch (error) {
      client?.dispose();
      await handle?.stop();
      server.dispose();
      rethrow;
    }
  }

  static Future<Room> practice({
    required String nickname,
    required int bots,
    required int mapSize,
    required int tempo,
    required int skill,
    bool teams = false,
    int deathVision = 1,
    int loot = 1,
    bool friendlyFire = false,
    bool respawn = false,
  }) async {
    final server = GameServer(
      roomName: 'Тренировка',
      hostName: nickname,
      allowPause: true,
    );
    server.botCount = bots.clamp(1, 7);
    server.mapSize = kMapSizes.contains(mapSize) ? mapSize : kDefaultMapSize;
    server.tempo = tempo.clamp(0, 2);
    server.skill = skill.clamp(0, 2);
    server.teams = teams;
    server.deathVision = deathVision.clamp(0, 1);
    server.loot = loot.clamp(0, 2);
    server.friendlyFire = friendlyFire;
    server.respawn = respawn;

    GameClient? client;
    try {
      final link = LocalLink.connect(server, nickname);
      client = GameClient(link: link, playerName: nickname);
      final ok = await client.connect();
      if (!ok) {
        throw RoomException(
          client.error.value ?? 'Не удалось запустить тренировку',
        );
      }
      server.startMatch();
      for (var i = 0; i < 40; i++) {
        if (client.lobby.value?.started == true) break;
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
      return Room._(
        server: server,
        client: client,
        hostHandle: null,
        isPractice: true,
      );
    } catch (error) {
      client?.dispose();
      server.dispose();
      rethrow;
    }
  }

  static Future<Room> join({
    required String nickname,
    required String address,
    required int port,
  }) async {
    GameClient? client;
    try {
      final link = await connectLan(address: address, port: port);
      client = GameClient(link: link, playerName: nickname);
      final ok = await client.connect();
      if (!ok) {
        throw RoomException(client.error.value ?? 'Не удалось подключиться');
      }
      for (var i = 0; i < 100; i++) {
        if (client.lobby.value != null || client.error.value != null) break;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      if (client.error.value != null) {
        throw RoomException(client.error.value!);
      }
      if (client.lobby.value == null) {
        throw RoomException('Сервер не отвечает. Проверьте IP и Wi-Fi.');
      }
      return Room._(
        server: null,
        client: client,
        hostHandle: null,
        isPractice: false,
        remoteEndpoint: port == kGamePort ? address : '$address:$port',
      );
    } catch (error) {
      client?.dispose();
      rethrow;
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    try {
      await client.close();
    } catch (_) {
      // уже закрыт
    }
    try {
      await hostHandle?.stop();
    } catch (_) {
      // сокет уже закрыт
    }
    server?.dispose();
  }
}

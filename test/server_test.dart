import 'package:flutter_test/flutter_test.dart';
import 'package:maze_royale/game/constants.dart';
import 'package:maze_royale/net/game_server.dart';
import 'package:maze_royale/net/messages.dart';

void main() {
  group('GameServer', () {
    test('командный старт сам добавляет ботов до формата 2×2', () {
      final messages = <Map<String, dynamic>>[];
      final server = GameServer(roomName: 'T', hostName: 'Host');
      addTearDown(server.dispose);
      server.addPeer(name: 'Host', local: true, send: messages.add);
      server.teams = true;
      server.botCount = 0;

      server.startMatch();

      expect(server.started, isTrue);
      final sim = server.sim;
      expect(sim, isNotNull);
      expect(sim!.players.length, kTeamSize * 2);
      final teams = sim.players.values.map((p) => p.team).toList()..sort();
      expect(teams, <int>[0, 0, 1, 1]);
    });

    test('команда lobby возвращает всех в лобби без пересоздания комнаты', () {
      final messages = <Map<String, dynamic>>[];
      final server = GameServer(roomName: 'T', hostName: 'Host');
      addTearDown(server.dispose);
      final hostId = server.addPeer(
        name: 'Host',
        local: true,
        send: messages.add,
      );
      server.botCount = 1;

      server.startMatch();
      expect(server.started, isTrue);
      expect(server.sim, isNotNull);

      messages.clear();
      server.handleMessage(hostId, <String, dynamic>{'t': 'cmd', 'c': 'lobby'});

      expect(server.started, isFalse);
      expect(server.sim, isNull);
      final lobby = messages.lastWhere((m) => m['t'] == 'lobby');
      expect(lobby['started'], 0);
      expect(lobby['room'], 'T');
      expect((lobby['p'] as List<dynamic>).length, 1);

      // Комната жива: можно сразу запустить новый матч с другими настройками.
      server.botCount = 1;
      server.startMatch();
      expect(server.started, isTrue);
      expect(server.sim, isNotNull);
    });

    test('настройка возрождения передаётся лобби и симуляции матча', () {
      final messages = <Map<String, dynamic>>[];
      final server = GameServer(roomName: 'T', hostName: 'Host');
      addTearDown(server.dispose);
      final hostId = server.addPeer(
        name: 'Host',
        local: true,
        send: messages.add,
      );
      server.teams = true;
      server.handleMessage(hostId, <String, dynamic>{
        't': 'cmd',
        'c': 'respawn',
        'n': 1,
      });

      final lobbyJson = messages.lastWhere(
        (message) => message['t'] == 'lobby',
      );
      expect(LobbyState.fromJson(lobbyJson).respawn, isTrue);

      server.startMatch();
      expect(server.sim?.respawn, isTrue);
    });
  });
}

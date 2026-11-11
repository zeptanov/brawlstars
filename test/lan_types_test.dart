import 'package:flutter_test/flutter_test.dart';
import 'package:maze_royale/game/constants.dart';
import 'package:maze_royale/net/lan_types.dart';

void main() {
  test('room protocol compatibility requires an exact version match', () {
    DiscoveredRoom make(int protocolVersion) => DiscoveredRoom(
      roomId: 'room',
      name: 'Room',
      hostName: 'Host',
      address: '127.0.0.1',
      port: kGamePort,
      players: 1,
      maxPlayers: kMaxPlayers,
      phase: -1,
      protocolVersion: protocolVersion,
      lastSeen: DateTime.now(),
    );

    expect(make(kProtocolVersion).protocolCompatible, isTrue);
    expect(make(kProtocolVersion + 1).protocolCompatible, isFalse);
    expect(make(kProtocolVersion - 1).protocolCompatible, isFalse);
  });
}

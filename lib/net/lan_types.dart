import 'package:flutter/foundation.dart';

import '../game/constants.dart';

class DiscoveredRoom {
  const DiscoveredRoom({
    required this.roomId,
    required this.name,
    required this.hostName,
    required this.address,
    required this.port,
    required this.players,
    required this.maxPlayers,
    required this.phase,
    required this.protocolVersion,
    required this.lastSeen,
  });

  final String roomId;
  final String name;
  final String hostName;
  final String address;
  final int port;
  final int players;
  final int maxPlayers;
  final int phase;
  final int protocolVersion;
  final DateTime lastSeen;

  bool get protocolCompatible => protocolVersion == kProtocolVersion;

  String get endpoint => port == 47777 ? address : '$address:$port';
}

abstract class LanHostHandle {
  List<String> get addresses;
  int get port;
  String get roomId;
  Future<void> stop();
}

abstract class RoomScanner {
  ValueListenable<List<DiscoveredRoom>> get rooms;
  Future<void> stop();
}

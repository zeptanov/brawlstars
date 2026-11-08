import 'lan_types.dart';
import 'link.dart';
import 'game_server.dart';

bool get lanSupported => false;

Future<List<String>> localAddresses() async => const <String>[];

Future<LanHostHandle> startLanHost({
  required GameServer game,
  int port = 47777,
}) {
  return Future<LanHostHandle>.error(
    UnsupportedError('Локальная сеть недоступна в браузере'),
  );
}

Future<GameLink> connectLan({
  required String address,
  required int port,
}) {
  return Future<GameLink>.error(
    UnsupportedError('Локальная сеть недоступна в браузере'),
  );
}

Future<RoomScanner?> startRoomScanner({int port = 47780}) async => null;

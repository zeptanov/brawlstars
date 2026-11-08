import 'dart:async';

import 'link.dart';
import 'game_server.dart';

/// Транспорт внутри одного процесса: хост играет на своём же сервере
/// без реального сокета и сетевой задержки.
class LocalLink implements GameLink {
  LocalLink._(this._server, this.playerName);

  static LocalLink connect(GameServer server, String name) {
    final link = LocalLink._(server, name);
    link._peerId = server.addPeer(
      name: name,
      send: link._deliver,
      local: true,
    );
    return link;
  }

  final GameServer _server;
  final String playerName;
  final StreamController<Map<String, dynamic>> _controller =
      StreamController<Map<String, dynamic>>();
  int _peerId = 0;

  int get peerId => _peerId;

  void _deliver(Map<String, dynamic> message) {
    if (!_controller.isClosed) _controller.add(message);
  }

  @override
  Stream<Map<String, dynamic>> get messages => _controller.stream;

  @override
  void send(Map<String, dynamic> message) {
    if (_peerId == 0) return;
    _server.handleMessage(_peerId, message);
  }

  @override
  Future<void> close() async {
    if (_peerId != 0) {
      _server.removePeer(_peerId);
      _peerId = 0;
    }
    await _controller.close();
  }
}

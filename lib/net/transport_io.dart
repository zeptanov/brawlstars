import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../game/constants.dart';
import 'game_server.dart';
import 'lan_types.dart';
import 'link.dart';

bool get lanSupported => true;

Future<List<String>> localAddresses() async {
  try {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    final result = <String>[];
    for (final iface in interfaces) {
      for (final address in iface.addresses) {
        final ip = address.address;
        if (ip.startsWith('169.254.')) continue;
        if (!result.contains(ip)) result.add(ip);
      }
    }
    int score(String ip) {
      if (ip.startsWith('192.168.')) return 0;
      if (ip.startsWith('10.')) return 1;
      if (ip.startsWith('172.')) return 2;
      return 3;
    }

    result.sort((a, b) => score(a).compareTo(score(b)));
    return result;
  } catch (_) {
    return const <String>[];
  }
}

Future<LanHostHandle> startLanHost({
  required GameServer game,
  int port = kGamePort,
}) async {
  RawDatagramSocket? socket;
  var boundPort = port;
  try {
    socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      port,
      reuseAddress: true,
    );
  } catch (_) {
    socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    boundPort = socket.port;
  }
  try {
    socket.broadcastEnabled = true;
  } catch (_) {
    // ignore
  }
  final addresses = await localAddresses();
  return _LanHost(game, socket, boundPort, addresses);
}

class _LanHost implements LanHostHandle {
  _LanHost(this._game, this._socket, this.port, this._addresses) {
    _socket.listen(_onEvent);
    _announceTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _announce();
    });
    _checkTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _checkTimeouts();
    });
    _announce();
  }

  final GameServer _game;
  final RawDatagramSocket _socket;
  final List<String> _addresses;

  @override
  final int port;

  final Map<String, int> _peerByAddress = <String, int>{};
  final Map<int, String> _addressByPeer = <int, String>{};
  final Map<int, DateTime> _lastSeen = <int, DateTime>{};
  Timer? _announceTimer;
  Timer? _checkTimer;
  bool _stopped = false;

  @override
  List<String> get addresses => _addresses;

  @override
  String get roomId => _game.roomId;

  static String _key(InternetAddress address, int port) =>
      '${address.address}:$port';

  void _onEvent(RawSocketEvent event) {
    if (event != RawSocketEvent.read || _stopped) return;
    final datagram = _socket.receive();
    if (datagram == null) return;
    Map<String, dynamic>? message;
    try {
      final decoded = jsonDecode(utf8.decode(datagram.data));
      if (decoded is Map) message = decoded.cast<String, dynamic>();
    } catch (_) {
      return;
    }
    if (message == null) return;

    final key = _key(datagram.address, datagram.port);
    final knownId = _peerByAddress[key];
    final type = '${message['t']}';

    if (knownId != null) {
      _lastSeen[knownId] = DateTime.now();
      _game.handleMessage(knownId, message);
      return;
    }

    if (type != 'join') return;

    if (_game.humanCount >= kMaxPlayers) {
      _sendRaw(datagram.address, datagram.port, <String, dynamic>{
        't': 'bye',
        'reason': 'Комната заполнена',
      });
      return;
    }

    final name = '${message['name'] ?? 'Игрок'}';
    final id = _game.addPeer(
      name: name,
      send: (out) => _sendRaw(datagram.address, datagram.port, out),
      local: false,
    );
    _peerByAddress[key] = id;
    _addressByPeer[id] = key;
    _lastSeen[id] = DateTime.now();
  }

  void _checkTimeouts() {
    if (_stopped) return;
    final now = DateTime.now();
    final dead = <int>[];
    _lastSeen.forEach((id, seen) {
      if (now.difference(seen) > const Duration(seconds: 10)) dead.add(id);
    });
    for (final id in dead) {
      _game.removePeer(id);
      final key = _addressByPeer.remove(id);
      if (key != null) _peerByAddress.remove(key);
      _lastSeen.remove(id);
    }
  }

  void _announce() {
    if (_stopped) return;
    final payload = _game.discoveryPayload(port: port);
    final bytes = utf8.encode(jsonEncode(payload));
    try {
      _socket.send(bytes, InternetAddress('255.255.255.255'), kDiscoveryPort);
    } catch (_) {
      // некоторые адаптеры не разрешают broadcast
    }
    try {
      _socket.send(bytes, InternetAddress.loopbackIPv4, kDiscoveryPort);
    } catch (_) {
      // ignore
    }
  }

  void _sendRaw(
    InternetAddress address,
    int targetPort,
    Map<String, dynamic> message,
  ) {
    if (_stopped) return;
    try {
      _socket.send(utf8.encode(jsonEncode(message)), address, targetPort);
    } catch (_) {
      // ignore
    }
  }

  @override
  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    _announceTimer?.cancel();
    _checkTimer?.cancel();
    for (final id in _addressByPeer.keys.toList()) {
      try {
        final key = _addressByPeer[id];
        if (key == null) continue;
        final parts = key.split(':');
        final addr = InternetAddress(parts.first);
        final remotePort = int.tryParse(parts.last) ?? 0;
        if (remotePort > 0) {
          _sendRaw(addr, remotePort, <String, dynamic>{
            't': 'bye',
            'reason': 'Хост закрыл комнату',
          });
        }
      } catch (_) {
        // ignore
      }
    }
    _peerByAddress.clear();
    _addressByPeer.clear();
    _lastSeen.clear();
    _socket.close();
  }
}

// ---------------------------------------------------------------------------
// Клиент по UDP
// ---------------------------------------------------------------------------

Future<GameLink> connectLan({
  required String address,
  required int port,
}) async {
  final addresses = await InternetAddress.lookup(address);
  if (addresses.isEmpty) {
    throw const SocketException('Не удалось найти адрес');
  }
  final target = addresses.firstWhere(
    (a) => a.type == InternetAddressType.IPv4,
    orElse: () => addresses.first,
  );
  final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
  try {
    socket.broadcastEnabled = true;
  } catch (_) {
    // ignore
  }
  return _UdpLink(socket, target, port);
}

class _UdpLink implements GameLink {
  _UdpLink(this._socket, this._target, this._port) {
    _socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final datagram = _socket.receive();
      if (datagram == null) return;
      try {
        final decoded = jsonDecode(utf8.decode(datagram.data));
        if (decoded is Map) {
          _lastMessage = DateTime.now();
          _lostReported = false;
          if (!_controller.isClosed) {
            _controller.add(decoded.cast<String, dynamic>());
          }
        }
      } catch (_) {
        // повреждённый пакет
      }
    });
    _watchdog = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_lostReported) return;
      if (DateTime.now().difference(_lastMessage) >
          const Duration(seconds: 8)) {
        _lostReported = true;
        if (!_controller.isClosed) {
          _controller.add(<String, dynamic>{'t': 'net', 's': 'lost'});
        }
      }
    });
  }

  final RawDatagramSocket _socket;
  final InternetAddress _target;
  final int _port;
  final StreamController<Map<String, dynamic>> _controller =
      StreamController<Map<String, dynamic>>();
  Timer? _watchdog;
  DateTime _lastMessage = DateTime.now();
  bool _lostReported = false;
  bool _closed = false;

  @override
  Stream<Map<String, dynamic>> get messages => _controller.stream;

  @override
  void send(Map<String, dynamic> message) {
    if (_closed) return;
    try {
      _socket.send(utf8.encode(jsonEncode(message)), _target, _port);
    } catch (_) {
      // ignore
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _watchdog?.cancel();
    _socket.close();
    await _controller.close();
  }
}

// ---------------------------------------------------------------------------
// Автопоиск комнат
// ---------------------------------------------------------------------------

Future<RoomScanner?> startRoomScanner({int port = kDiscoveryPort}) async {
  RawDatagramSocket? socket;
  try {
    socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      port,
      reuseAddress: true,
      reusePort: true,
    );
  } catch (_) {
    try {
      socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        port,
        reuseAddress: true,
      );
    } catch (_) {
      return null;
    }
  }
  try {
    socket.broadcastEnabled = true;
  } catch (_) {
    // ignore
  }
  return _LanScanner(socket);
}

class _LanScanner implements RoomScanner {
  _LanScanner(this._socket) {
    _socket.listen(_onEvent);
    _expireTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _expire();
    });
  }

  final RawDatagramSocket _socket;
  final Map<String, DiscoveredRoom> _byId = <String, DiscoveredRoom>{};
  final ValueNotifier<List<DiscoveredRoom>> _rooms =
      ValueNotifier<List<DiscoveredRoom>>(const <DiscoveredRoom>[]);
  Timer? _expireTimer;
  bool _stopped = false;

  @override
  ValueListenable<List<DiscoveredRoom>> get rooms => _rooms;

  void _onEvent(RawSocketEvent event) {
    if (event != RawSocketEvent.read || _stopped) return;
    final datagram = _socket.receive();
    if (datagram == null) return;
    Map<String, dynamic>? message;
    try {
      final decoded = jsonDecode(utf8.decode(datagram.data));
      if (decoded is Map) message = decoded.cast<String, dynamic>();
    } catch (_) {
      return;
    }
    if (message == null || '${message['t']}' != 'disc') return;
    final version = (message['ver'] as num?)?.toInt() ?? 0;
    final id = '${message['id'] ?? ''}';
    if (id.isEmpty) return;
    final roomPort = (message['port'] as num?)?.toInt() ?? kGamePort;
    final room = DiscoveredRoom(
      roomId: id,
      name: '${message['room'] ?? 'Комната'}',
      hostName: '${message['host'] ?? ''}',
      address: datagram.address.address,
      port: roomPort,
      players: (message['players'] as num?)?.toInt() ?? 0,
      maxPlayers: (message['max'] as num?)?.toInt() ?? kMaxPlayers,
      phase: (message['phase'] as num?)?.toInt() ?? -1,
      protocolVersion: version,
      lastSeen: DateTime.now(),
    );
    _byId[id] = room;
    _publish();
  }

  void _expire() {
    if (_stopped) return;
    final now = DateTime.now();
    final before = _byId.length;
    _byId.removeWhere(
      (_, room) => now.difference(room.lastSeen) > const Duration(seconds: 6),
    );
    if (before != _byId.length) _publish();
  }

  void _publish() {
    final list = _byId.values.toList()
      ..sort((a, b) => b.players.compareTo(a.players));
    _rooms.value = List<DiscoveredRoom>.unmodifiable(list);
  }

  @override
  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    _expireTimer?.cancel();
    _socket.close();
    _rooms.value = const <DiscoveredRoom>[];
  }
}

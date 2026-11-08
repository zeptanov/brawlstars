import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app/room.dart';
import '../app/theme.dart';
import '../game/constants.dart';
import '../net/lan_types.dart';
import '../net/transport.dart' as transport;
import 'widgets.dart';

class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key, required this.nickname});

  final String nickname;

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _addressController = TextEditingController();
  late final AnimationController _radar = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();

  RoomScanner? _scanner;
  ValueListenable<List<DiscoveredRoom>>? _rooms;
  bool _scanning = true;
  String? _error;
  String? _connecting;

  @override
  void initState() {
    super.initState();
    _startScanner();
  }

  Future<void> _startScanner() async {
    setState(() {
      _scanning = true;
      _rooms = null;
    });
    await _scanner?.stop();
    _scanner = null;
    final scanner = await transport.startRoomScanner();
    if (!mounted) {
      await scanner?.stop();
      return;
    }
    setState(() {
      _scanner = scanner;
      _rooms = scanner?.rooms;
      _scanning = scanner != null;
    });
  }

  @override
  void dispose() {
    _radar.dispose();
    _addressController.dispose();
    _scanner?.stop();
    super.dispose();
  }

  Future<void> _connect(String address, int port) async {
    if (_connecting != null) return;
    setState(() {
      _connecting = 'Подключаемся к $address...';
      _error = null;
    });
    Room? room;
    try {
      room = await Room.join(
        nickname: widget.nickname,
        address: address,
        port: port,
      );
      if (!mounted) {
        await room.close();
        return;
      }
      final ready = room;
      room = null;
      Navigator.of(context).pop(ready);
    } catch (error) {
      room?.close();
      if (mounted) {
        setState(() {
          _connecting = null;
          _error = error is RoomException
              ? error.message
              : 'Не удалось подключиться: $error';
        });
      }
    }
  }

  void _connectManual() {
    var raw = _addressController.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = 'Введите IP-адрес хоста');
      return;
    }
    var port = kGamePort;
    final colon = raw.lastIndexOf(':');
    if (colon > 0) {
      final maybePort = int.tryParse(raw.substring(colon + 1));
      if (maybePort != null) {
        port = maybePort;
        raw = raw.substring(0, colon);
      }
    }
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      raw = raw.replaceFirst(RegExp(r'https?://'), '');
    }
    _connect(raw, port);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: <Widget>[
          const NeonBackground(),
          SafeArea(
            child: Column(
              children: <Widget>[
                _header(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 30),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 940),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final wide = constraints.maxWidth >= 780;
                            final search = _searchPanel();
                            final manual = _manualPanel();
                            if (!wide) {
                              return Column(
                                children: <Widget>[
                                  search,
                                  const SizedBox(height: 16),
                                  manual,
                                ],
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Expanded(flex: 6, child: search),
                                const SizedBox(width: 16),
                                Expanded(flex: 5, child: manual),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_connecting != null)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.6),
                child: Center(
                  child: NeonPanel(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _connecting!,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Проверяем соединение с комнатой',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Palette.mutedDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 20, 6),
      child: Row(
        children: <Widget>[
          NeonIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Назад',
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'ПОИСК КОМНАТЫ',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.2,
                  ),
                ),
                Text(
                  'Устройства должны быть в одной Wi-Fi сети',
                  style: TextStyle(fontSize: 11.5, color: Palette.mutedDark),
                ),
              ],
            ),
          ),
          if (_scanner != null)
            const Pill(
              text: 'ПОИСК...',
              color: Palette.accent,
              icon: Icons.radar_rounded,
              small: true,
            ),
        ],
      ),
    );
  }

  Widget _searchPanel() {
    return NeonPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              SizedBox(
                width: 118,
                height: 118,
                child: AnimatedBuilder(
                  animation: _radar,
                  builder: (context, _) => CustomPaint(
                    painter: _RadarPainter(_radar.value),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Ищем комнаты рядом',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Хост создаёт комнату — она появится здесь через пару секунд. '
                      'Можно подключиться и вручную по IP.',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        color: Palette.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              const SectionLabel('Доступные комнаты'),
              const Spacer(),
              TextButton.icon(
                onPressed: _scanning ? null : _startScanner,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text(
                  'Обновить',
                  style: TextStyle(fontSize: 11.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (_rooms == null)
            const _EmptyRooms(
              icon: Icons.portable_wifi_off_rounded,
              title: 'Автопоиск недоступен',
              text:
                  'Не удалось открыть порт обнаружения. Введите IP-адрес хоста справа.',
            )
          else
            ValueListenableBuilder<List<DiscoveredRoom>>(
              valueListenable: _rooms!,
              builder: (context, rooms, _) {
                if (rooms.isEmpty) {
                  return const _EmptyRooms(
                    icon: Icons.wifi_find_rounded,
                    title: 'Пока никого',
                    text:
                        'Убедитесь, что хост нажал «Создать комнату», и вы в одной сети. '
                        'Комната появится здесь автоматически.',
                  );
                }
                return Column(
                  children: <Widget>[
                    for (final room in rooms)
                      _RoomTile(
                        room: room,
                        onTap: () => _connect(room.address, room.port),
                      ),
                  ],
                );
              },
            ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 14),
            _ErrorNote(text: _error!),
          ],
        ],
      ),
    );
  }

  Widget _manualPanel() {
    return NeonPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SectionLabel('Подключиться по IP'),
          const SizedBox(height: 9),
          const Text(
            'IP-адрес показан на экране хоста. Порт можно указать через двоеточие, '
            'по умолчанию $kGamePort.',
            style: TextStyle(fontSize: 12, height: 1.45, color: Palette.muted),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _addressController,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.go,
            onSubmitted: (_) => _connectManual(),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
            decoration: const InputDecoration(
              hintText: '192.168.1.42',
              prefixIcon: Icon(Icons.lan_outlined, size: 19),
            ),
          ),
          const SizedBox(height: 12),
          NeonButton(
            label: 'Подключиться',
            icon: Icons.login_rounded,
            primary: true,
            onPressed: _connecting == null ? _connectManual : null,
          ),
          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 14),
          const _MiniStep(
            number: '1',
            text: 'Хост нажимает «Создать комнату» на своём устройстве.',
          ),
          const _MiniStep(
            number: '2',
            text: 'Все устройства подключены к одной Wi-Fi сети.',
          ),
          const _MiniStep(
            number: '3',
            text: 'Выберите комнату в списке или введите IP вручную.',
          ),
          const SizedBox(height: 10),
          const _ErrorNote(
            text:
                'Не подключается? Разрешите доступ в брандмауэре и отключите '
                'изоляцию клиентов на роутере.',
            danger: false,
          ),
        ],
      ),
    );
  }
}

class _RoomTile extends StatelessWidget {
  const _RoomTile({required this.room, required this.onTap});

  final DiscoveredRoom room;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final inGame = room.phase >= 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: const Color(0xFF0A111B),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Palette.line),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Palette.accent.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: Palette.accent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Icon(
                    Icons.meeting_room_outlined,
                    size: 20,
                    color: Palette.accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        room.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${room.address} · хост ${room.hostName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Palette.mutedDark,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Pill(
                      text: '${room.players}/${room.maxPlayers}',
                      color: Palette.accent,
                      icon: Icons.people_alt_outlined,
                      small: true,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      inGame ? 'В БОЮ' : 'В ЛОББИ',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: inGame ? Palette.gold : Palette.mutedDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Palette.mutedDark,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyRooms extends StatelessWidget {
  const _EmptyRooms({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF080E16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Palette.line.withValues(alpha: 0.7)),
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, size: 30, color: Palette.mutedDark),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11.5,
              height: 1.45,
              color: Palette.mutedDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStep extends StatelessWidget {
  const _MiniStep({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Palette.accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: Palette.accent.withValues(alpha: 0.35),
              ),
            ),
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Palette.accent,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.45,
                color: Palette.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote({required this.text, this.danger = true});

  final String text;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? Palette.danger : Palette.mutedDark;
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            danger ? Icons.error_outline_rounded : Icons.info_outline_rounded,
            size: 15,
            color: color,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.4,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 4;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Palette.accent.withValues(alpha: 0.25);
    canvas.drawCircle(center, radius, ring);
    canvas.drawCircle(center, radius * 0.66, ring);
    canvas.drawCircle(center, radius * 0.33, ring);
    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx + radius, center.dy),
      ring,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - radius),
      Offset(center.dx, center.dy + radius),
      ring,
    );

    final sweep = t * math.pi * 2;
    final shader = SweepGradient(
      startAngle: sweep - 0.9,
      endAngle: sweep,
      colors: <Color>[
        Palette.accent.withValues(alpha: 0),
        Palette.accent.withValues(alpha: 0.35),
      ],
    ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, Paint()..shader = shader);

    final beamEnd = center +
        Offset(math.cos(sweep), math.sin(sweep)) * radius;
    canvas.drawLine(
      center,
      beamEnd,
      Paint()
        ..color = Palette.accent.withValues(alpha: 0.8)
        ..strokeWidth = 1.4,
    );

    final dot = Paint()..color = Palette.gold;
    for (var i = 0; i < 3; i++) {
      final a = sweep * 0.6 + i * 2.1;
      final r = radius * (0.35 + i * 0.18);
      final p = center + Offset(math.cos(a), math.sin(a)) * r;
      canvas.drawCircle(p, 2.2, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) =>
      oldDelegate.t != t;
}

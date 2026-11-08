import 'dart:async';

import 'package:flutter/material.dart';

import '../app/room.dart';
import '../app/theme.dart';
import '../game/constants.dart';
import '../net/messages.dart';
import 'game_screen.dart';
import 'widgets.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key, required this.room});

  final Room room;

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScroll = ScrollController();
  bool _handedOff = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    widget.room.client.lobby.addListener(_onLobby);
    widget.room.client.error.addListener(_onError);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onLobby());
  }

  @override
  void dispose() {
    widget.room.client.lobby.removeListener(_onLobby);
    widget.room.client.error.removeListener(_onError);
    _chatController.dispose();
    _chatScroll.dispose();
    if (!_handedOff) {
      unawaited(widget.room.close());
    }
    super.dispose();
  }

  void _onLobby() {
    if (!mounted) return;
    final lobby = widget.room.client.lobby.value;
    if (lobby == null) return;
    if (lobby.started) {
      _goToGame();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _chatScroll.hasClients) _chatScroll.jumpTo(0);
    });
  }

  void _onError() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _goToGame() async {
    if (_navigated) return;
    _navigated = true;
    _handedOff = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => GameScreen(room: widget.room, fromLobby: true),
        ),
      );
      if (!mounted) return;
      _navigated = false;
      _handedOff = false;
      _onLobby();
    });
  }

  Future<void> _leave() async {
    final isHost = widget.room.client.isHost;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Palette.surfaceAlt,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Palette.line),
        ),
        title: Text(isHost ? 'Закрыть комнату?' : 'Покинуть комнату?'),
        content: Text(
          isHost
              ? 'Все игроки потеряют соединение с вашей комнатой.'
              : 'Вы вернётесь в главное меню.',
          style: const TextStyle(color: Palette.muted),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              isHost ? 'Закрыть' : 'Выйти',
              style: const TextStyle(color: Palette.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  void _start() {
    final client = widget.room.client;
    final lobby = client.lobby.value;
    if (lobby == null) return;
    final total = lobby.players.length + lobby.botCount;
    final needed = lobby.teams ? 1 : 2;
    if (total < needed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lobby.teams
                ? 'В командном режиме не хватает бойцов — боты добавятся автоматически.'
                : 'Нужен хотя бы один соперник: добавьте бота или позовите друга.',
          ),
        ),
      );
      return;
    }
    client.startMatch();
  }

  void _sendChat() {
    final text = _chatController.text;
    if (text.trim().isEmpty) return;
    widget.room.client.sendChat(text);
    _chatController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: <Widget>[
          const NeonBackground(),
          SafeArea(
            child: AnimatedBuilder(
              animation: Listenable.merge(<Listenable>[
                widget.room.client.lobby,
                widget.room.client.error,
              ]),
              builder: (context, _) {
                final lobby = widget.room.client.lobby.value;
                return Column(
                  children: <Widget>[
                    _header(lobby),
                    Expanded(
                      child: lobby == null
                          ? const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                              ),
                            )
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                final wide = constraints.maxWidth >= 980;
                                return SingleChildScrollView(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    6,
                                    20,
                                    26,
                                  ),
                                  child: Center(
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 1180,
                                      ),
                                      child: wide
                                          ? Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: <Widget>[
                                                Expanded(
                                                  flex: 6,
                                                  child: _leftColumn(lobby),
                                                ),
                                                const SizedBox(width: 16),
                                                Expanded(
                                                  flex: 5,
                                                  child: _rightColumn(lobby),
                                                ),
                                              ],
                                            )
                                          : Column(
                                              children: <Widget>[
                                                _leftColumn(lobby),
                                                const SizedBox(height: 14),
                                                _rightColumn(lobby),
                                              ],
                                            ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
          AnimatedBuilder(
            animation: widget.room.client.error,
            builder: (context, _) {
              final error = widget.room.client.error.value;
              if (error == null) return const SizedBox.shrink();
              return Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.72),
                  child: Center(
                    child: NeonPanel(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(
                            Icons.wifi_off_rounded,
                            size: 34,
                            color: Palette.danger,
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'СОЕДИНЕНИЕ ПОТЕРЯНО',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            error,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Palette.muted,
                            ),
                          ),
                          const SizedBox(height: 18),
                          NeonButton(
                            label: 'В меню',
                            icon: Icons.home_outlined,
                            expand: false,
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _header(LobbyState? lobby) {
    final code = lobby?.code ?? widget.room.server?.roomId ?? '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 20, 8),
      child: Row(
        children: <Widget>[
          NeonIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Выйти',
            onPressed: _leave,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  (lobby?.roomName ?? 'КОМНАТА').toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                  ),
                ),
                Text(
                  lobby == null
                      ? 'Подключение...'
                      : '${lobby.players.length} игроков · ${lobby.botCount} ботов · до $kMaxPlayers',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Palette.mutedDark,
                  ),
                ),
              ],
            ),
          ),
          if (code.isNotEmpty)
            Pill(
              text: 'КОД $code',
              color: Palette.magenta,
              icon: Icons.tag_rounded,
              small: true,
            ),
          const SizedBox(width: 12),
          if (widget.room.client.isHost)
            const Pill(
              text: 'ВЫ ХОСТ',
              color: Palette.gold,
              icon: Icons.star_outline_rounded,
              small: true,
            ),
        ],
      ),
    );
  }

  Widget _leftColumn(LobbyState lobby) {
    return Column(
      children: <Widget>[
        _roomInfo(lobby),
        const SizedBox(height: 14),
        _playersCard(lobby),
        const SizedBox(height: 14),
        _startCard(lobby),
      ],
    );
  }

  Widget _rightColumn(LobbyState lobby) {
    return Column(
      children: <Widget>[
        _settingsCard(lobby),
        const SizedBox(height: 14),
        _chatCard(lobby),
      ],
    );
  }

  Widget _roomInfo(LobbyState lobby) {
    final addresses = widget.room.addresses;
    return NeonPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionLabel(
            'Комната',
            trailing: widget.room.isLanHost
                ? const Pill(
                    text: 'LAN',
                    color: Palette.accent,
                    icon: Icons.wifi_rounded,
                    small: true,
                  )
                : const Pill(
                    text: 'ГОСТЬ',
                    color: Palette.muted,
                    icon: Icons.person_outline_rounded,
                    small: true,
                  ),
          ),
          const SizedBox(height: 12),
          Text(
            lobby.roomName,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 12),
          if (widget.room.isLanHost && addresses.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (var i = 0; i < addresses.length && i < 3; i++)
                  AddressChip(
                    label: i == 0 ? 'IP для друзей' : 'IP',
                    value: widget.room.port == kGamePort
                        ? addresses[i]
                        : '${addresses[i]}:${widget.room.port}',
                  ),
                AddressChip(
                  label: 'Порт',
                  value: '${widget.room.port}',
                  icon: Icons.settings_ethernet_rounded,
                  copyable: false,
                ),
              ],
            )
          else if (widget.room.remoteEndpoint != null)
            AddressChip(
              label: 'Сервер',
              value: widget.room.remoteEndpoint!,
              icon: Icons.lan_outlined,
            ),
          if (widget.room.isLanHost) ...<Widget>[
            const SizedBox(height: 12),
            const Text(
              'Друзья в этой Wi-Fi сети увидят комнату в разделе «Найти игру». '
              'Если нет — передайте им IP выше.',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.45,
                color: Palette.mutedDark,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _playersCard(LobbyState lobby) {
    final isHost = widget.room.client.isHost;
    final total = lobby.players.length + lobby.botCount;
    return NeonPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionLabel(
            'Участники',
            trailing: Pill(
              text: '$total/$kMaxPlayers',
              color: total >= 2 ? Palette.accent : Palette.gold,
              icon: Icons.people_alt_outlined,
              small: true,
            ),
          ),
          const SizedBox(height: 12),
          for (final player in lobby.players)
            _PlayerTile(
              player: player,
              isSelf: player.id == widget.room.client.id,
              isHost: player.id == lobby.hostId,
              showTeam: lobby.teams,
              canKick:
                  isHost &&
                  player.id != widget.room.client.id &&
                  player.id != lobby.hostId,
              onKick: () => widget.room.client.kick(player.id),
            ),
          const SizedBox(height: 4),
          _BotsTile(
            count: lobby.botCount,
            canEdit: isHost,
            maxBots: (kMaxPlayers - lobby.players.length).clamp(0, kMaxPlayers),
            onChange: (value) => widget.room.client.setBots(value),
          ),
          if (!lobby.teams &&
              lobby.players.length == 1 &&
              lobby.botCount == 0) ...<Widget>[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: Palette.gold.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Palette.gold.withValues(alpha: 0.25)),
              ),
              child: const Row(
                children: <Widget>[
                  Icon(
                    Icons.info_outline_rounded,
                    size: 15,
                    color: Palette.gold,
                  ),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Добавьте бота или дождитесь друга — одному играть не с кем.',
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.4,
                        color: Palette.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _startCard(LobbyState lobby) {
    final isHost = widget.room.client.isHost;
    final total = lobby.players.length + lobby.botCount;
    final needed = lobby.teams ? 1 : 2;
    final enough = total >= needed;
    if (!isHost) {
      return NeonPanel(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          children: <Widget>[
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'ЖДЁМ ХОСТА',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.6,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    enough
                        ? 'Хост запустит бой, как только будет готов.'
                        : 'Хост добавляет ботов или ждёт игроков.',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Palette.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return NeonPanel(
      padding: const EdgeInsets.all(18),
      glow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          NeonButton(
            label: 'Начать бой',
            subtitle: enough
                ? '$total участников · ${_mapLabel(lobby.mapSize)}'
                : 'Нужен хотя бы один соперник',
            icon: Icons.play_arrow_rounded,
            primary: true,
            height: 64,
            onPressed: _start,
          ),
          const SizedBox(height: 10),
          const Text(
            'Подсказка: зона начнёт сжиматься вскоре после старта. '
            'Не тратьте время на открытые коридоры.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              height: 1.4,
              color: Palette.mutedDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingsCard(LobbyState lobby) {
    final isHost = widget.room.client.isHost;
    return NeonPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionLabel(
            'Настройки боя',
            trailing: isHost
                ? const Pill(
                    text: 'МЕНЯЕТ ХОСТ',
                    color: Palette.magenta,
                    small: true,
                  )
                : null,
          ),
          const SizedBox(height: 14),
          const Text(
            'Размер карты',
            style: TextStyle(fontSize: 12.5, color: Palette.muted),
          ),
          const SizedBox(height: 7),
          SegmentedOptions(
            options: const <String>['Малая', 'Стандарт', 'Большая'],
            selected: kMapSizes.indexOf(lobby.mapSize).clamp(0, 2),
            enabled: isHost,
            compact: true,
            onChanged: isHost
                ? (i) => widget.room.client.setMapSize(kMapSizes[i])
                : null,
          ),
          const SizedBox(height: 13),
          const Text(
            'Темп зоны',
            style: TextStyle(fontSize: 12.5, color: Palette.muted),
          ),
          const SizedBox(height: 7),
          SegmentedOptions(
            options: const <String>['Быстро', 'Обычно', 'Медленно'],
            selected: lobby.tempo,
            enabled: isHost,
            compact: true,
            onChanged: isHost ? widget.room.client.setTempo : null,
          ),
          const SizedBox(height: 13),
          const Text(
            'Сложность ботов',
            style: TextStyle(fontSize: 12.5, color: Palette.muted),
          ),
          const SizedBox(height: 7),
          SegmentedOptions(
            options: const <String>['Легко', 'Средне', 'Сложно'],
            selected: lobby.skill,
            enabled: isHost,
            compact: true,
            onChanged: isHost ? widget.room.client.setSkill : null,
          ),
          const SizedBox(height: 13),
          const Text(
            'Формат боя',
            style: TextStyle(fontSize: 12.5, color: Palette.muted),
          ),
          const SizedBox(height: 7),
          SegmentedOptions(
            options: const <String>['Каждый за себя', 'Команды 2×2'],
            selected: lobby.teams ? 1 : 0,
            enabled: isHost,
            compact: true,
            onChanged: isHost
                ? (i) => widget.room.client.setTeams(i == 1)
                : null,
          ),
          const SizedBox(height: 13),
          const Text(
            'Мёртвые видят',
            style: TextStyle(fontSize: 12.5, color: Palette.muted),
          ),
          const SizedBox(height: 7),
          SegmentedOptions(
            options: const <String>['Только туман', 'Всю карту'],
            selected: lobby.deathVision,
            enabled: isHost,
            compact: true,
            onChanged: isHost ? widget.room.client.setDeathVision : null,
          ),
          const SizedBox(height: 13),
          const Text(
            'Количество лута',
            style: TextStyle(fontSize: 12.5, color: Palette.muted),
          ),
          const SizedBox(height: 7),
          SegmentedOptions(
            options: const <String>['Мало', 'Обычно', 'Много'],
            selected: lobby.loot,
            enabled: isHost,
            compact: true,
            onChanged: isHost ? widget.room.client.setLoot : null,
          ),
          const SizedBox(height: 13),
          const Text(
            'Дружественный огонь',
            style: TextStyle(fontSize: 12.5, color: Palette.muted),
          ),
          const SizedBox(height: 7),
          SegmentedOptions(
            options: const <String>['Выкл', 'Вкл'],
            selected: lobby.friendlyFire ? 1 : 0,
            enabled: isHost && lobby.teams,
            compact: true,
            onChanged: isHost && lobby.teams
                ? (i) => widget.room.client.setFriendlyFire(i == 1)
                : null,
          ),
          const SizedBox(height: 13),
          const Text(
            'Возрождение союзников',
            style: TextStyle(fontSize: 12.5, color: Palette.muted),
          ),
          const SizedBox(height: 7),
          SegmentedOptions(
            options: const <String>['Выкл', 'Вкл'],
            selected: lobby.respawn ? 1 : 0,
            enabled: isHost && lobby.teams,
            compact: true,
            onChanged: isHost && lobby.teams
                ? (i) => widget.room.client.setRespawn(i == 1)
                : null,
          ),
          const SizedBox(height: 12),
          Text(
            lobby.teams
                ? 'Команды по 2 бойца. Если людей не хватает, сервер сам добавит '
                      'ботов-напарников. При включённом возрождении павший игрок '
                      'вернётся через ${kRespawnDelay.toInt()} секунд, если союзник ещё жив.'
                : 'Время матча — около 3–4 минут. Побеждает последний выживший.',
            style: const TextStyle(
              fontSize: 11,
              height: 1.4,
              color: Palette.mutedDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chatCard(LobbyState lobby) {
    final lines = lobby.chat.length > 40
        ? lobby.chat.sublist(lobby.chat.length - 40)
        : lobby.chat;
    return NeonPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SectionLabel('Чат комнаты'),
          const SizedBox(height: 10),
          Container(
            height: 168,
            decoration: BoxDecoration(
              color: const Color(0xFF070C14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Palette.line),
            ),
            child: lines.isEmpty
                ? const Center(
                    child: Text(
                      'Напишите что-нибудь друзьям',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Palette.mutedDark,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _chatScroll,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    itemCount: lines.length,
                    itemBuilder: (context, index) {
                      final line = lines[lines.length - 1 - index];
                      final isSelf = line.authorId == widget.room.client.id;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: RichText(
                          text: TextSpan(
                            children: <TextSpan>[
                              TextSpan(
                                text: '${line.author}: ',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isSelf
                                      ? Palette.accent
                                      : Palette.magenta,
                                ),
                              ),
                              TextSpan(
                                text: line.text,
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.35,
                                  color: Palette.text,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _chatController,
                  maxLength: 140,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendChat(),
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'Сообщение...',
                    counterText: '',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              NeonIconButton(
                icon: Icons.send_rounded,
                tooltip: 'Отправить сообщение',
                size: 46,
                color: Palette.accent,
                onPressed: _sendChat,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _mapLabel(int size) {
  switch (size) {
    case 41:
      return 'малая карта';
    case 81:
      return 'большая карта';
    default:
      return 'стандартная карта';
  }
}

class _PlayerTile extends StatelessWidget {
  const _PlayerTile({
    required this.player,
    required this.isSelf,
    required this.isHost,
    required this.canKick,
    required this.onKick,
    this.showTeam = false,
  });

  final LobbyPlayer player;
  final bool isSelf;
  final bool isHost;
  final bool canKick;
  final VoidCallback onKick;
  final bool showTeam;

  static const List<Color> _colors = <Color>[
    Color(0xFF3BE8C8),
    Color(0xFFFF4E8E),
    Color(0xFFFFC857),
    Color(0xFF7FB2FF),
    Color(0xFF9BFF6B),
    Color(0xFFC792FF),
    Color(0xFFFF8A5B),
    Color(0xFF5BE7FF),
  ];

  static const List<Color> _teamColors = <Color>[
    Color(0xFF3BE8C8),
    Color(0xFFFF4E8E),
    Color(0xFFFFC857),
    Color(0xFF7FB2FF),
  ];

  @override
  Widget build(BuildContext context) {
    final color = showTeam && player.team >= 0
        ? _teamColors[player.team % _teamColors.length]
        : _colors[player.id % _colors.length];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelf
              ? Palette.accent.withValues(alpha: 0.05)
              : const Color(0xFF0A111B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelf
                ? Palette.accent.withValues(alpha: 0.4)
                : Palette.line,
          ),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    color.withValues(alpha: 0.35),
                    color.withValues(alpha: 0.12),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withValues(alpha: 0.5)),
              ),
              child: Text(
                player.name.isEmpty ? '?' : player.name[0].toUpperCase(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Row(
                children: <Widget>[
                  Flexible(
                    child: Text(
                      player.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  if (showTeam && player.team >= 0) ...<Widget>[
                    Pill(
                      text: 'T${player.team + 1}',
                      color: color,
                      small: true,
                    ),
                    const SizedBox(width: 5),
                  ],
                  if (isSelf)
                    const Pill(text: 'ВЫ', color: Palette.accent, small: true),
                  if (isHost) ...<Widget>[
                    const SizedBox(width: 5),
                    const Pill(text: 'ХОСТ', color: Palette.gold, small: true),
                  ],
                ],
              ),
            ),
            if (canKick)
              IconButton(
                tooltip: 'Исключить',
                onPressed: onKick,
                icon: const Icon(
                  Icons.person_remove_outlined,
                  size: 17,
                  color: Palette.mutedDark,
                ),
              )
            else
              const Icon(
                Icons.check_circle_outline_rounded,
                size: 17,
                color: Palette.accentDeep,
              ),
          ],
        ),
      ),
    );
  }
}

class _BotsTile extends StatelessWidget {
  const _BotsTile({
    required this.count,
    required this.canEdit,
    required this.maxBots,
    required this.onChange,
  });

  final int count;
  final bool canEdit;
  final int maxBots;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0A111B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Palette.line),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Palette.magenta.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Palette.magenta.withValues(alpha: 0.3)),
            ),
            child: const Icon(
              Icons.smart_toy_outlined,
              size: 18,
              color: Palette.magenta,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Боты',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
                Text(
                  count == 0
                      ? 'Не добавлены'
                      : '$count ${count == 1 ? 'боец' : 'бойцов'} · ИИ',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Palette.mutedDark,
                  ),
                ),
              ],
            ),
          ),
          if (canEdit) ...<Widget>[
            NeonIconButton(
              icon: Icons.remove_rounded,
              tooltip: 'Уменьшить число ботов',
              size: 30,
              onPressed: count <= 0 ? null : () => onChange(count - 1),
            ),
            SizedBox(
              width: 34,
              child: Text(
                '$count',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            NeonIconButton(
              icon: Icons.add_rounded,
              tooltip: 'Увеличить число ботов',
              size: 30,
              onPressed: count >= maxBots ? null : () => onChange(count + 1),
            ),
          ] else
            Pill(text: '$count', color: Palette.magenta, small: true),
        ],
      ),
    );
  }
}

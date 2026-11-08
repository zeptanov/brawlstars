import 'package:flutter/material.dart';

import '../app/room.dart';
import '../app/settings.dart';
import '../app/theme.dart';
import '../game/constants.dart';
import '../net/transport.dart' as transport;
import 'game_screen.dart';
import 'join_screen.dart';
import 'lobby_screen.dart';
import 'guide_screen.dart';
import 'widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AppSettings _settings = AppSettings.instance;
  late final TextEditingController _nickController =
      TextEditingController(text: _settings.nickname);
  String? _busy;

  @override
  void dispose() {
    _nickController.dispose();
    super.dispose();
  }

  String _nickname() {
    final value = _nickController.text.trim();
    if (value.isEmpty) {
      _nickController.text = _settings.nickname;
      return _settings.nickname;
    }
    _settings.setNickname(value);
    return _settings.nickname;
  }

  Future<void> _createRoom() async {
    if (!transport.lanSupported) {
      _toast('LAN-режим работает в приложениях на ПК и телефоне, не в браузере.');
      return;
    }
    final nickname = _nickname();
    setState(() => _busy = 'Создаём комнату...');
    Room? room;
    try {
      room = await Room.host(nickname: nickname);
      if (!mounted) {
        await room.close();
        return;
      }
      final created = room;
      room = null;
      setState(() => _busy = null);
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => LobbyScreen(room: created)),
      );
    } catch (error) {
      room?.close();
      if (mounted) {
        setState(() => _busy = null);
        _toast(_describe(error));
      }
    }
  }

  Future<void> _practice() async {
    final nickname = _nickname();
    setState(() => _busy = 'Готовим арену...');
    Room? room;
    try {
      room = await Room.practice(
        nickname: nickname,
        bots: _settings.defaultBots,
        mapSize: _settings.defaultMapSize,
        tempo: _settings.defaultTempo,
        skill: _settings.defaultSkill,
        teams: _settings.defaultTeams,
        deathVision: _settings.defaultDeathVision,
        loot: _settings.defaultLoot,
        friendlyFire: _settings.defaultFriendlyFire,
        respawn: _settings.defaultRespawn,
      );
      if (!mounted) {
        await room.close();
        return;
      }
      final created = room;
      room = null;
      setState(() => _busy = null);
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => GameScreen(room: created)),
      );
    } catch (error) {
      room?.close();
      if (mounted) {
        setState(() => _busy = null);
        _toast(_describe(error));
      }
    }
  }

  Future<void> _findRoom() async {
    if (!transport.lanSupported) {
      _toast('Поиск комнат работает в нативных приложениях на одной Wi-Fi сети.');
      return;
    }
    final nickname = _nickname();
    final room = await Navigator.of(context).push<Room>(
      MaterialPageRoute<Room>(
        builder: (_) => JoinScreen(nickname: nickname),
      ),
    );
    if (room == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => LobbyScreen(room: room)),
    );
  }

  String _describe(Object error) {
    if (error is RoomException) return error.message;
    return 'Не получилось: $error';
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _openSettings() {
    showNeonSheet(
      context: context,
      title: 'Настройки',
      child: AnimatedBuilder(
        animation: _settings,
        builder: (context, _) => _SettingsBody(settings: _settings),
      ),
    );
  }

  void _openHelp() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const GuideScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: <Widget>[
          const NeonBackground(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 940;
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 26,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 52,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1180),
                        child: wide
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: <Widget>[
                                  Expanded(
                                    flex: 6,
                                    child: _Hero(
                                      settings: _settings,
                                      compact: false,
                                    ),
                                  ),
                                  const SizedBox(width: 48),
                                  SizedBox(
                                    width: 412,
                                    child: _buildPanel(),
                                  ),
                                ],
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  _Hero(
                                    settings: _settings,
                                    compact: true,
                                  ),
                                  const SizedBox(height: 26),
                                  ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 460),
                                    child: _buildPanel(),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_busy != null) _BusyOverlay(label: _busy!),
        ],
      ),
    );
  }

  Widget _buildPanel() {
    return NeonPanel(
      glow: true,
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SectionLabel('Твой позывной'),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _nickController,
                  maxLength: 16,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                  decoration: const InputDecoration(
                    counterText: '',
                    prefixIcon: Icon(Icons.person_outline_rounded, size: 19),
                    hintText: 'Введите имя',
                  ),
                  onSubmitted: (_) => _nickname(),
                ),
              ),
              const SizedBox(width: 10),
              NeonIconButton(
                icon: Icons.casino_outlined,
                tooltip: 'Случайный позывной',
                size: 52,
                onPressed: () {
                  _settings.rerollNickname();
                  _nickController.text = _settings.nickname;
                },
              ),
            ],
          ),
          const SizedBox(height: 22),
          NeonButton(
            label: 'Создать комнату',
            subtitle: 'Друзья подключатся по Wi-Fi',
            icon: Icons.groups_2_outlined,
            primary: true,
            height: 64,
            onPressed: _busy == null ? _createRoom : null,
          ),
          const SizedBox(height: 10),
          NeonButton(
            label: 'Найти игру',
            subtitle: 'Автопоиск комнат в локальной сети',
            icon: Icons.radar_rounded,
            onPressed: _busy == null ? _findRoom : null,
          ),
          const SizedBox(height: 10),
          NeonButton(
            label: 'Тренировка с ботами',
            subtitle:
                '${_settings.defaultBots} ботов · ${_mapLabel(_settings.defaultMapSize)}',
            icon: Icons.smart_toy_outlined,
            accent: Palette.gold,
            onPressed: _busy == null ? _practice : null,
          ),
          if (!transport.lanSupported) ...<Widget>[
            const SizedBox(height: 14),
            _InfoNote(
              icon: Icons.language_rounded,
              text:
                  'В браузере доступна только тренировка. LAN-комнаты — в приложении на ПК, Android, iOS или macOS.',
            ),
          ],
          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _TextAction(
                  icon: Icons.menu_book_outlined,
                  label: 'Как играть',
                  onTap: _openHelp,
                ),
              ),
              Expanded(
                child: _TextAction(
                  icon: Icons.tune_rounded,
                  label: 'Настройки',
                  onTap: _openSettings,
                ),
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

class _Hero extends StatelessWidget {
  const _Hero({required this.settings, required this.compact});

  final AppSettings settings;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final titleSize = compact ? 54.0 : 76.0;
    return Column(
      crossAxisAlignment:
          compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            MazeLogo(size: compact ? 62 : 78),
            const SizedBox(width: 14),
            Pill(
              text: 'LAN · 2–8 ИГРОКОВ',
              color: Palette.accent,
              icon: Icons.wifi_rounded,
              small: compact,
            ),
          ],
        ),
        const SizedBox(height: 20),
        ShaderMask(
          shaderCallback: (rect) => const LinearGradient(
            colors: <Color>[
              Color(0xFFFFFFFF),
              Color(0xFF8CF7E6),
              Color(0xFF4FB7FF),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(rect),
          child: Text(
            'MAZE\nROYALE',
            textAlign: compact ? TextAlign.center : TextAlign.left,
            style: TextStyle(
              fontSize: titleSize,
              height: 0.88,
              fontWeight: FontWeight.w900,
              letterSpacing: compact ? 8 : 12,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'ЛАБИРИНТ · ОХОТА · ОДИН ВЫЖИВШИЙ',
          textAlign: compact ? TextAlign.center : TextAlign.left,
          style: TextStyle(
            fontSize: compact ? 11 : 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 3.2,
            color: Palette.accent.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: 22),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const <Widget>[
              _FeatureRow(
                icon: Icons.visibility_off_outlined,
                title: 'Туман войны',
                text:
                    'Видно только то, что рядом. Стены скрывают силуэты — ищите друг друга вслепую.',
              ),
              _FeatureRow(
                icon: Icons.gps_fixed_rounded,
                title: 'Зона сужается',
                text:
                    'Арена сжимается волнами. Остаться последним — единственный способ победить.',
              ),
              _FeatureRow(
                icon: Icons.bolt_rounded,
                title: '5 стволов и снаряжение',
                text:
                    'Дробовик, ПП, винтовка, снайперка, щиты, аптечки, радар и маскировка.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        AnimatedBuilder(
          animation: settings,
          builder: (context, _) {
            return Row(
              mainAxisAlignment:
                  compact ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: <Widget>[
                _Stat(value: '${settings.matchesPlayed}', label: 'МАТЧЕЙ'),
                _Stat(value: '${settings.wins}', label: 'ПОБЕД'),
                _Stat(value: '${settings.totalKills}', label: 'УБИЙСТВ'),
              ],
            );
          },
        ),
        if (!compact) ...<Widget>[
          const SizedBox(height: 18),
          Text(
            'Побеждает тот, кто остался последним.',
            style: TextStyle(
              fontSize: 12.5,
              color: Palette.mutedDark,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Palette.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Palette.accent.withValues(alpha: 0.22),
              ),
            ),
            child: Icon(icon, size: 17, color: Palette.accent),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
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
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Palette.text,
              height: 1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8,
              color: Palette.mutedDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _TextAction extends StatelessWidget {
  const _TextAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 16, color: Palette.muted),
            const SizedBox(width: 7),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Palette.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoNote extends StatelessWidget {
  const _InfoNote({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Palette.gold.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Palette.gold.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 16, color: Palette.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.4,
                color: Palette.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BusyOverlay extends StatelessWidget {
  const _BusyOverlay({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.55),
        child: Center(
          child: NeonPanel(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
                const SizedBox(width: 14),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Настройки
// ---------------------------------------------------------------------------

class _SettingsBody extends StatelessWidget {
  const _SettingsBody({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const SectionLabel('Управление'),
        const SizedBox(height: 9),
        SegmentedOptions(
          options: const <String>['Авто', 'Сенсор', 'Мышь'],
          selected: settings.inputMode,
          onChanged: settings.setInputMode,
        ),
        const SizedBox(height: 20),
        const SectionLabel('Качество тумана войны'),
        const SizedBox(height: 9),
        SegmentedOptions(
          options: const <String>['Низкое', 'Среднее', 'Высокое'],
          selected: settings.quality,
          onChanged: settings.setQuality,
        ),
        const SizedBox(height: 18),
        _ToggleRow(
          title: 'Показывать FPS',
          subtitle: 'Диагностика производительности',
          value: settings.showFps,
          onChanged: settings.setShowFps,
        ),
        _ToggleRow(
          title: 'Тряска камеры',
          subtitle: 'Отдача и попадания',
          value: settings.screenShake,
          onChanged: settings.setScreenShake,
        ),
        const SizedBox(height: 20),
        const Divider(height: 1),
        const SizedBox(height: 16),
        const SectionLabel('Тренировка по умолчанию'),
        const SizedBox(height: 14),
        Row(
          children: <Widget>[
            const Expanded(
              child: Text(
                'Количество ботов',
                style: TextStyle(fontSize: 13, color: Palette.muted),
              ),
            ),
            NeonIconButton(
              icon: Icons.remove_rounded,
              size: 32,
              onPressed: () => settings.setDefaultBots(settings.defaultBots - 1),
            ),
            SizedBox(
              width: 42,
              child: Text(
                '${settings.defaultBots}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            NeonIconButton(
              icon: Icons.add_rounded,
              size: 32,
              onPressed: () => settings.setDefaultBots(settings.defaultBots + 1),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Text(
          'Размер карты',
          style: TextStyle(fontSize: 13, color: Palette.muted),
        ),
        const SizedBox(height: 8),
        SegmentedOptions(
          options: const <String>['Малая', 'Стандарт', 'Большая'],
          selected: kMapSizes.indexOf(settings.defaultMapSize).clamp(0, 2),
          onChanged: (i) => settings.setDefaultMapSize(kMapSizes[i]),
        ),
        const SizedBox(height: 14),
        const Text(
          'Темп зоны',
          style: TextStyle(fontSize: 13, color: Palette.muted),
        ),
        const SizedBox(height: 8),
        SegmentedOptions(
          options: const <String>['Быстрый', 'Обычный', 'Медленный'],
          selected: settings.defaultTempo,
          onChanged: settings.setDefaultTempo,
        ),
        const SizedBox(height: 14),
        const Text(
          'Сложность ботов',
          style: TextStyle(fontSize: 13, color: Palette.muted),
        ),
        const SizedBox(height: 8),
        SegmentedOptions(
          options: const <String>['Легко', 'Средне', 'Сложно'],
          selected: settings.defaultSkill,
          onChanged: settings.setDefaultSkill,
        ),
        const SizedBox(height: 14),
        const Text(
          'Формат боя',
          style: TextStyle(fontSize: 13, color: Palette.muted),
        ),
        const SizedBox(height: 8),
        SegmentedOptions(
          options: const <String>['Каждый за себя', 'Команды 2×2'],
          selected: settings.defaultTeams ? 1 : 0,
          onChanged: (i) => settings.setDefaultTeams(i == 1),
        ),
        const SizedBox(height: 14),
        const Text(
          'Мёртвые видят',
          style: TextStyle(fontSize: 13, color: Palette.muted),
        ),
        const SizedBox(height: 8),
        SegmentedOptions(
          options: const <String>['Только туман', 'Всю карту'],
          selected: settings.defaultDeathVision,
          onChanged: settings.setDefaultDeathVision,
        ),
        const SizedBox(height: 14),
        const Text(
          'Количество лута',
          style: TextStyle(fontSize: 13, color: Palette.muted),
        ),
        const SizedBox(height: 8),
        SegmentedOptions(
          options: const <String>['Мало', 'Обычно', 'Много'],
          selected: settings.defaultLoot,
          onChanged: settings.setDefaultLoot,
        ),
        const SizedBox(height: 14),
        const Text(
          'Дружественный огонь',
          style: TextStyle(fontSize: 13, color: Palette.muted),
        ),
        const SizedBox(height: 8),
        SegmentedOptions(
          options: const <String>['Выкл', 'Вкл'],
          selected: settings.defaultFriendlyFire ? 1 : 0,
          enabled: settings.defaultTeams,
          onChanged: settings.defaultTeams
              ? (i) => settings.setDefaultFriendlyFire(i == 1)
              : null,
        ),
        const SizedBox(height: 14),
        _ToggleRow(
          title: 'Возрождение союзников',
          subtitle: settings.defaultTeams
              ? 'Возврат через 6 секунд, пока союзник жив'
              : 'Доступно только в командном режиме',
          value: settings.defaultRespawn,
          onChanged: settings.setDefaultRespawn,
        ),
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Palette.mutedDark,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Palette.accent,
          ),
        ],
      ),
    );
  }
}

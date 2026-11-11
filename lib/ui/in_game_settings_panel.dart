import 'package:flutter/material.dart';

import '../app/settings.dart';
import '../app/theme.dart';
import 'widgets.dart';

class InGameSettingsPanel extends StatelessWidget {
  const InGameSettingsPanel({
    super.key,
    required this.settings,
    required this.onInputModeChanged,
  });

  final AppSettings settings;
  final ValueChanged<int> onInputModeChanged;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SectionLabel('Управление'),
          const SizedBox(height: 8),
          SegmentedOptions(
            options: const <String>['Авто', 'Сенсор', 'Мышь'],
            selected: settings.inputMode,
            onChanged: onInputModeChanged,
          ),
          const SizedBox(height: 16),
          const SectionLabel('Графика и интерфейс'),
          const SizedBox(height: 6),
          SegmentedOptions(
            options: const <String>['Низкое', 'Среднее', 'Высокое'],
            selected: settings.quality,
            onChanged: settings.setQuality,
          ),
          _SettingsToggle(
            title: 'Показывать FPS',
            value: settings.showFps,
            onChanged: settings.setShowFps,
          ),
          _SettingsToggle(
            title: 'Тряска камеры',
            value: settings.screenShake,
            onChanged: settings.setScreenShake,
          ),
          const Divider(height: 22),
          const SectionLabel('Звук'),
          _SettingsToggle(
            title: 'Включить звук',
            value: settings.soundEnabled,
            onChanged: settings.setSoundEnabled,
          ),
          _VolumeRow(
            label: 'Музыка',
            value: settings.musicVolume,
            onChanged: settings.setMusicVolume,
          ),
          _VolumeRow(
            label: 'Оружие',
            value: settings.weaponVolume,
            onChanged: settings.setWeaponVolume,
          ),
          _VolumeRow(
            label: 'Взрывы и урон',
            value: settings.explosionVolume,
            onChanged: settings.setExplosionVolume,
          ),
          _VolumeRow(
            label: 'Бонусы',
            value: settings.pickupVolume,
            onChanged: settings.setPickupVolume,
          ),
          _VolumeRow(
            label: 'Интерфейс',
            value: settings.uiVolume,
            onChanged: settings.setUiVolume,
          ),
        ],
      ),
    );
  }
}

class _SettingsToggle extends StatelessWidget {
  const _SettingsToggle({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(child: Text(title, style: const TextStyle(fontSize: 12.5))),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: Palette.accent,
        ),
      ],
    );
  }
}

class _VolumeRow extends StatelessWidget {
  const _VolumeRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 112,
          child: Text(
            label,
            style: const TextStyle(fontSize: 11.5, color: Palette.muted),
          ),
        ),
        Expanded(
          child: Slider(
            min: 0,
            max: 1,
            divisions: 20,
            value: value,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 34,
          child: Text(
            '${(value * 100).round()}%',
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 10, color: Palette.mutedDark),
          ),
        ),
      ],
    );
  }
}

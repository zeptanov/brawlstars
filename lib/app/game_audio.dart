import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../game/weapons.dart';
import 'settings.dart';

enum _SoundCue {
  pistol,
  smg,
  shotgun,
  rifle,
  sniper,
  explosion,
  damage,
  pickup,
  dash,
  respawn,
  reload,
  hit,
  kill,
  ui,
}

class GameAudio {
  GameAudio._();

  static final GameAudio instance = GameAudio._();

  static const Map<_SoundCue, String> _assets = <_SoundCue, String>{
    _SoundCue.pistol: 'audio/sfx/pistol.wav',
    _SoundCue.smg: 'audio/sfx/smg.wav',
    _SoundCue.shotgun: 'audio/sfx/shotgun.wav',
    _SoundCue.rifle: 'audio/sfx/rifle.wav',
    _SoundCue.sniper: 'audio/sfx/sniper.wav',
    _SoundCue.explosion: 'audio/sfx/explosion.wav',
    _SoundCue.damage: 'audio/sfx/damage.wav',
    _SoundCue.pickup: 'audio/sfx/pickup.wav',
    _SoundCue.dash: 'audio/sfx/dash.wav',
    _SoundCue.respawn: 'audio/sfx/respawn.wav',
    _SoundCue.reload: 'audio/sfx/reload.wav',
    _SoundCue.hit: 'audio/sfx/hit.wav',
    _SoundCue.kill: 'audio/sfx/kill.wav',
    _SoundCue.ui: 'audio/sfx/ui.wav',
  };

  final AudioPlayer _music = AudioPlayer();
  final Map<_SoundCue, Future<AudioPool>> _pools =
      <_SoundCue, Future<AudioPool>>{};
  AppSettings? _settings;
  bool _musicRequested = false;
  bool _musicLoaded = false;

  void bind(AppSettings settings) {
    if (identical(_settings, settings)) return;
    _settings?.removeListener(_onSettingsChanged);
    _settings = settings..addListener(_onSettingsChanged);
  }

  Future<void> startMatchMusic() async {
    _musicRequested = true;
    await _applySettings();
  }

  Future<void> stopMatchMusic() async {
    _musicRequested = false;
    await _reportErrors(_music.stop());
  }

  Future<void> playWeapon(int weaponIndex) {
    final cue = switch (weaponByIndex(weaponIndex).id) {
      WeaponId.pistol => _SoundCue.pistol,
      WeaponId.smg => _SoundCue.smg,
      WeaponId.shotgun => _SoundCue.shotgun,
      WeaponId.rifle => _SoundCue.rifle,
      WeaponId.sniper => _SoundCue.sniper,
    };
    return _play(cue);
  }

  Future<void> playExplosion() => _play(_SoundCue.explosion);
  Future<void> playDamage() => _play(_SoundCue.damage);
  Future<void> playPickup() => _play(_SoundCue.pickup);
  Future<void> playDash() => _play(_SoundCue.dash);
  Future<void> playRespawn() => _play(_SoundCue.respawn);
  Future<void> playReload() => _play(_SoundCue.reload);
  Future<void> playHit() => _play(_SoundCue.hit);
  Future<void> playKill() => _play(_SoundCue.kill);
  Future<void> playUi() => _play(_SoundCue.ui);

  Future<void> _play(_SoundCue cue) async {
    final settings = _settings;
    if (settings == null || !settings.soundEnabled) return;
    final volume = _volumeFor(cue, settings);
    if (volume <= 0) return;
    await _reportErrors(
      _poolFor(cue).then((pool) => pool.start(volume: volume)).then((_) {}),
    );
  }

  Future<AudioPool> _poolFor(_SoundCue cue) => _pools.putIfAbsent(
    cue,
    () => AudioPool.createFromAsset(
      path: _assets[cue]!,
      minPlayers: 1,
      maxPlayers: 4,
    ),
  );

  double _volumeFor(_SoundCue cue, AppSettings settings) => switch (cue) {
    _SoundCue.pistol ||
    _SoundCue.smg ||
    _SoundCue.shotgun ||
    _SoundCue.rifle ||
    _SoundCue.sniper => settings.weaponVolume,
    _SoundCue.explosion || _SoundCue.damage => settings.explosionVolume,
    _SoundCue.pickup || _SoundCue.respawn => settings.pickupVolume,
    _SoundCue.dash ||
    _SoundCue.reload ||
    _SoundCue.hit => settings.weaponVolume,
    _SoundCue.kill || _SoundCue.ui => settings.uiVolume,
  };

  void _onSettingsChanged() {
    unawaited(_applySettings());
  }

  Future<void> _applySettings() async {
    await _syncMusic();
    final settings = _settings;
    if (_musicRequested && settings != null && settings.soundEnabled) {
      await _reportErrors(Future.wait(_assets.keys.map(_poolFor)).then((_) {}));
    }
  }

  Future<void> _syncMusic() async {
    final settings = _settings;
    if (settings == null) return;
    if (!settings.soundEnabled ||
        !_musicRequested ||
        settings.musicVolume <= 0) {
      if (_music.state == PlayerState.playing) {
        await _reportErrors(_music.stop());
      }
      return;
    }

    await _reportErrors(() async {
      if (!_musicLoaded) {
        await _music.setReleaseMode(ReleaseMode.loop);
        await _music.setSource(AssetSource('audio/music/arena_theme.wav'));
        _musicLoaded = true;
      }
      await _music.setVolume(settings.musicVolume);
      if (_music.state != PlayerState.playing) await _music.resume();
    }());
  }

  Future<void> _reportErrors(Future<void> operation) async {
    try {
      await operation;
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'Maze Royale audio',
          context: ErrorDescription('while playing a game audio cue'),
        ),
      );
    }
  }
}

import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../game/constants.dart';
import 'local_settings_store.dart';

class AppSettings extends ChangeNotifier {
  AppSettings._({LocalSettingsStore? store})
    : _store = store ?? LocalSettingsStore();

  static final AppSettings instance = AppSettings._();

  @visibleForTesting
  factory AppSettings.forTesting(LocalSettingsStore store) =>
      AppSettings._(store: store);

  final LocalSettingsStore _store;
  Future<void> _pendingWrites = Future<void>.value();

  String nickname = _generateNickname();

  int inputMode = 0; // 0 авто, 1 сенсор, 2 мышь
  int quality = 1; // 0 низко, 1 средне, 2 высоко
  bool showFps = false;
  bool screenShake = true;
  bool soundEnabled = false;
  double musicVolume = 0.45;
  double weaponVolume = 0.65;
  double explosionVolume = 0.7;
  double pickupVolume = 0.6;
  double uiVolume = 0.5;

  int defaultBots = 3;
  int lastLobbyBotCount = 0;
  int defaultMapSize = kDefaultMapSize;
  int defaultMapGeneration = 0;
  int defaultTempo = 1;
  int defaultSkill = 1;
  bool defaultTeams = false;
  bool defaultAllyVision = true;
  int defaultDeathVision = 1;
  int defaultLoot = 1;
  bool defaultFriendlyFire = false;
  bool defaultRespawn = false;
  int defaultRespawnDelay = kDefaultRespawnDelay;

  int matchesPlayed = 0;
  int wins = 0;
  int totalKills = 0;
  double totalDamage = 0;

  Future<void> load() async {
    try {
      final savedSettings = await _store.readSettings();
      if (savedSettings != null) _restoreSettings(savedSettings);
    } on CorruptLocalDataException catch (error, stackTrace) {
      _reportStorageError(error, stackTrace);
    }

    try {
      final savedStatistics = await _store.readStatistics();
      if (savedStatistics != null) _restoreStatistics(savedStatistics);
    } on CorruptLocalDataException catch (error, stackTrace) {
      _reportStorageError(error, stackTrace);
    }
    notifyListeners();
  }

  bool get isTouchDefault {
    if (inputMode == 1) return true;
    if (inputMode == 2) return false;
    if (kIsWeb) {
      return defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS;
    }
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  int get fogRays {
    switch (quality) {
      case 0:
        return 44;
      case 2:
        return 104;
      default:
        return 72;
    }
  }

  void setNickname(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    nickname = trimmed.length > 16 ? trimmed.substring(0, 16) : trimmed;
    _changed();
  }

  void rerollNickname() {
    nickname = _generateNickname();
    _changed();
  }

  void setInputMode(int value) {
    inputMode = value.clamp(0, 2);
    _changed();
  }

  void setQuality(int value) {
    quality = value.clamp(0, 2);
    _changed();
  }

  void setShowFps(bool value) {
    showFps = value;
    _changed();
  }

  void setScreenShake(bool value) {
    screenShake = value;
    _changed();
  }

  void setSoundEnabled(bool value) {
    soundEnabled = value;
    _changed();
  }

  void setMusicVolume(double value) {
    musicVolume = value.clamp(0.0, 1.0).toDouble();
    _changed();
  }

  void setWeaponVolume(double value) {
    weaponVolume = value.clamp(0.0, 1.0).toDouble();
    _changed();
  }

  void setExplosionVolume(double value) {
    explosionVolume = value.clamp(0.0, 1.0).toDouble();
    _changed();
  }

  void setPickupVolume(double value) {
    pickupVolume = value.clamp(0.0, 1.0).toDouble();
    _changed();
  }

  void setUiVolume(double value) {
    uiVolume = value.clamp(0.0, 1.0).toDouble();
    _changed();
  }

  void setDefaultBots(int value) {
    defaultBots = value.clamp(1, 7);
    _changed();
  }

  void setDefaultAllyVision(bool value) {
    defaultAllyVision = value;
    _changed();
  }

  void saveLastLobbySettings({
    required int botCount,
    required int mapSize,
    required int mapGeneration,
    required int tempo,
    required int skill,
    required bool teams,
    required int deathVision,
    required int loot,
    required bool friendlyFire,
    required bool respawn,
    required int respawnDelay,
    required bool allyVision,
  }) {
    final nextBotCount = botCount.clamp(0, 7);
    final nextMapSize = kMapSizes.contains(mapSize) ? mapSize : defaultMapSize;
    final nextMapGeneration = mapGeneration.clamp(0, kMapGenerationCount - 1);
    final nextTempo = tempo.clamp(0, 2);
    final nextSkill = skill.clamp(0, 2);
    final nextDeathVision = deathVision.clamp(0, 1);
    final nextLoot = loot.clamp(0, 2);
    final nextRespawnDelay = respawnDelay.clamp(
      kMinRespawnDelay,
      kMaxRespawnDelay,
    );
    if (lastLobbyBotCount == nextBotCount &&
        defaultMapSize == nextMapSize &&
        defaultMapGeneration == nextMapGeneration &&
        defaultTempo == nextTempo &&
        defaultSkill == nextSkill &&
        defaultTeams == teams &&
        defaultDeathVision == nextDeathVision &&
        defaultLoot == nextLoot &&
        defaultFriendlyFire == friendlyFire &&
        defaultRespawn == respawn &&
        defaultRespawnDelay == nextRespawnDelay &&
        defaultAllyVision == allyVision) {
      return;
    }

    lastLobbyBotCount = nextBotCount;
    defaultMapSize = nextMapSize;
    defaultMapGeneration = nextMapGeneration;
    defaultTempo = nextTempo;
    defaultSkill = nextSkill;
    defaultTeams = teams;
    defaultDeathVision = nextDeathVision;
    defaultLoot = nextLoot;
    defaultFriendlyFire = friendlyFire;
    defaultRespawn = respawn;
    defaultRespawnDelay = nextRespawnDelay;
    defaultAllyVision = allyVision;
    _changed();
  }

  void setDefaultMapSize(int value) {
    if (!kMapSizes.contains(value)) return;
    defaultMapSize = value;
    _changed();
  }

  void setDefaultMapGeneration(int value) {
    defaultMapGeneration = value.clamp(0, kMapGenerationCount - 1);
    _changed();
  }

  void setDefaultTempo(int value) {
    defaultTempo = value.clamp(0, 2);
    _changed();
  }

  void setDefaultSkill(int value) {
    defaultSkill = value.clamp(0, 2);
    _changed();
  }

  void setDefaultTeams(bool value) {
    defaultTeams = value;
    _changed();
  }

  void setDefaultDeathVision(int value) {
    defaultDeathVision = value.clamp(0, 1);
    _changed();
  }

  void setDefaultLoot(int value) {
    defaultLoot = value.clamp(0, 2);
    _changed();
  }

  void setDefaultFriendlyFire(bool value) {
    defaultFriendlyFire = value;
    _changed();
  }

  void setDefaultRespawn(bool value) {
    defaultRespawn = value;
    _changed();
  }

  void setDefaultRespawnDelay(int value) {
    defaultRespawnDelay = value.clamp(kMinRespawnDelay, kMaxRespawnDelay);
    _changed();
  }

  void recordMatch({
    required int placement,
    required int kills,
    required double damage,
    bool won = false,
  }) {
    matchesPlayed++;
    totalKills += kills;
    totalDamage += damage;
    if (won) wins++;
    _changed();
  }

  Future<void> flushPendingWrites() => _pendingWrites;

  void _changed() {
    notifyListeners();
    final write = _pendingWrites.then((_) async {
      await _store.writeSettings(_settingsJson());
      await _store.writeStatistics(_statisticsJson());
    });
    _pendingWrites = write.catchError((Object error, StackTrace stackTrace) {
      _reportStorageError(error, stackTrace);
    });
  }

  Map<String, Object?> _settingsJson() => <String, Object?>{
    'nickname': nickname,
    'inputMode': inputMode,
    'quality': quality,
    'showFps': showFps,
    'screenShake': screenShake,
    'soundEnabled': soundEnabled,
    'musicVolume': musicVolume,
    'weaponVolume': weaponVolume,
    'explosionVolume': explosionVolume,
    'pickupVolume': pickupVolume,
    'uiVolume': uiVolume,
    'defaultBots': defaultBots,
    'lastLobbyBotCount': lastLobbyBotCount,
    'defaultMapSize': defaultMapSize,
    'defaultMapGeneration': defaultMapGeneration,
    'defaultTempo': defaultTempo,
    'defaultSkill': defaultSkill,
    'defaultTeams': defaultTeams,
    'defaultAllyVision': defaultAllyVision,
    'defaultDeathVision': defaultDeathVision,
    'defaultLoot': defaultLoot,
    'defaultFriendlyFire': defaultFriendlyFire,
    'defaultRespawn': defaultRespawn,
    'defaultRespawnDelay': defaultRespawnDelay,
  };

  Map<String, Object?> _statisticsJson() => <String, Object?>{
    'matchesPlayed': matchesPlayed,
    'wins': wins,
    'totalKills': totalKills,
    'totalDamage': totalDamage,
  };

  void _restoreSettings(Map<String, Object?> saved) {
    final savedNickname = saved['nickname'];
    if (savedNickname is String && savedNickname.trim().isNotEmpty) {
      final value = savedNickname.trim();
      nickname = value.length > 16 ? value.substring(0, 16) : value;
    }
    inputMode = _intInRange(saved['inputMode'], 0, 2, inputMode);
    quality = _intInRange(saved['quality'], 0, 2, quality);
    showFps = _boolOr(saved['showFps'], showFps);
    screenShake = _boolOr(saved['screenShake'], screenShake);
    soundEnabled = _boolOr(saved['soundEnabled'], soundEnabled);
    musicVolume = _doubleInRange(saved['musicVolume'], musicVolume);
    weaponVolume = _doubleInRange(saved['weaponVolume'], weaponVolume);
    explosionVolume = _doubleInRange(saved['explosionVolume'], explosionVolume);
    pickupVolume = _doubleInRange(saved['pickupVolume'], pickupVolume);
    uiVolume = _doubleInRange(saved['uiVolume'], uiVolume);
    defaultBots = _intInRange(saved['defaultBots'], 1, 7, defaultBots);
    lastLobbyBotCount = _intInRange(
      saved['lastLobbyBotCount'],
      0,
      7,
      lastLobbyBotCount,
    );
    final mapSize = saved['defaultMapSize'];
    if (mapSize is int && kMapSizes.contains(mapSize)) {
      defaultMapSize = mapSize;
    }
    defaultMapGeneration = _intInRange(
      saved['defaultMapGeneration'],
      0,
      kMapGenerationCount - 1,
      defaultMapGeneration,
    );
    defaultTempo = _intInRange(saved['defaultTempo'], 0, 2, defaultTempo);
    defaultSkill = _intInRange(saved['defaultSkill'], 0, 2, defaultSkill);
    defaultTeams = _boolOr(saved['defaultTeams'], defaultTeams);
    defaultAllyVision = _boolOr(saved['defaultAllyVision'], defaultAllyVision);
    defaultDeathVision = _intInRange(
      saved['defaultDeathVision'],
      0,
      1,
      defaultDeathVision,
    );
    defaultLoot = _intInRange(saved['defaultLoot'], 0, 2, defaultLoot);
    defaultFriendlyFire = _boolOr(
      saved['defaultFriendlyFire'],
      defaultFriendlyFire,
    );
    defaultRespawn = _boolOr(saved['defaultRespawn'], defaultRespawn);
    defaultRespawnDelay = _intInRange(
      saved['defaultRespawnDelay'],
      kMinRespawnDelay,
      kMaxRespawnDelay,
      defaultRespawnDelay,
    );
  }

  void _restoreStatistics(Map<String, Object?> saved) {
    final matches = _nonNegativeInt(saved, 'matchesPlayed');
    final savedWins = _nonNegativeInt(saved, 'wins');
    final kills = _nonNegativeInt(saved, 'totalKills');
    final damage = saved['totalDamage'];
    if (savedWins > matches ||
        damage is! num ||
        !damage.isFinite ||
        damage < 0) {
      throw const CorruptLocalDataException('Некорректная игровая статистика');
    }
    matchesPlayed = matches;
    wins = savedWins;
    totalKills = kills;
    totalDamage = damage.toDouble();
  }

  static int _nonNegativeInt(Map<String, Object?> saved, String key) {
    final value = saved[key];
    if (value is! int || value < 0) {
      throw CorruptLocalDataException('Некорректное поле статистики "$key"');
    }
    return value;
  }

  static int _intInRange(Object? value, int min, int max, int fallback) =>
      value is int && value >= min && value <= max ? value : fallback;

  static bool _boolOr(Object? value, bool fallback) =>
      value is bool ? value : fallback;

  static double _doubleInRange(Object? value, double fallback) =>
      value is num && value.isFinite
      ? value.toDouble().clamp(0.0, 1.0).toDouble()
      : fallback;

  static void _reportStorageError(Object error, StackTrace stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'Maze Royale local settings',
        context: ErrorDescription('while reading or writing local game data'),
      ),
    );
  }

  static String _generateNickname() {
    final rng = math.Random();
    final adj = kNickAdjectives[rng.nextInt(kNickAdjectives.length)];
    final noun = kNickNouns[rng.nextInt(kNickNouns.length)];
    final suffix = 10 + rng.nextInt(90);
    return '$adj $noun $suffix';
  }
}

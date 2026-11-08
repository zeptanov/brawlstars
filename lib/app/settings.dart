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

  int defaultBots = 3;
  int defaultMapSize = kDefaultMapSize;
  int defaultTempo = 1;
  int defaultSkill = 1;
  bool defaultTeams = false;
  int defaultDeathVision = 1;
  int defaultLoot = 1;
  bool defaultFriendlyFire = false;
  bool defaultRespawn = false;

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

  void setDefaultBots(int value) {
    defaultBots = value.clamp(1, 7);
    _changed();
  }

  void setDefaultMapSize(int value) {
    defaultMapSize = value;
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
    'defaultBots': defaultBots,
    'defaultMapSize': defaultMapSize,
    'defaultTempo': defaultTempo,
    'defaultSkill': defaultSkill,
    'defaultTeams': defaultTeams,
    'defaultDeathVision': defaultDeathVision,
    'defaultLoot': defaultLoot,
    'defaultFriendlyFire': defaultFriendlyFire,
    'defaultRespawn': defaultRespawn,
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
    defaultBots = _intInRange(saved['defaultBots'], 1, 7, defaultBots);
    final mapSize = saved['defaultMapSize'];
    if (mapSize is int && kMapSizes.contains(mapSize)) {
      defaultMapSize = mapSize;
    }
    defaultTempo = _intInRange(saved['defaultTempo'], 0, 2, defaultTempo);
    defaultSkill = _intInRange(saved['defaultSkill'], 0, 2, defaultSkill);
    defaultTeams = _boolOr(saved['defaultTeams'], defaultTeams);
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

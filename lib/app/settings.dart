import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../game/constants.dart';

/// Настройки на время сессии + статистика.
/// Без внешних зависимостей: всё живёт в памяти приложения.
class AppSettings extends ChangeNotifier {
  AppSettings._();

  static final AppSettings instance = AppSettings._();

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
    notifyListeners();
  }

  void rerollNickname() {
    nickname = _generateNickname();
    notifyListeners();
  }

  void setInputMode(int value) {
    inputMode = value.clamp(0, 2);
    notifyListeners();
  }

  void setQuality(int value) {
    quality = value.clamp(0, 2);
    notifyListeners();
  }

  void setShowFps(bool value) {
    showFps = value;
    notifyListeners();
  }

  void setScreenShake(bool value) {
    screenShake = value;
    notifyListeners();
  }

  void setDefaultBots(int value) {
    defaultBots = value.clamp(1, 7);
    notifyListeners();
  }

  void setDefaultMapSize(int value) {
    defaultMapSize = value;
    notifyListeners();
  }

  void setDefaultTempo(int value) {
    defaultTempo = value.clamp(0, 2);
    notifyListeners();
  }

  void setDefaultSkill(int value) {
    defaultSkill = value.clamp(0, 2);
    notifyListeners();
  }

  void setDefaultTeams(bool value) {
    defaultTeams = value;
    notifyListeners();
  }

  void setDefaultDeathVision(int value) {
    defaultDeathVision = value.clamp(0, 1);
    notifyListeners();
  }

  void setDefaultLoot(int value) {
    defaultLoot = value.clamp(0, 2);
    notifyListeners();
  }

  void setDefaultFriendlyFire(bool value) {
    defaultFriendlyFire = value;
    notifyListeners();
  }

  void setDefaultRespawn(bool value) {
    defaultRespawn = value;
    notifyListeners();
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
    notifyListeners();
  }

  static String _generateNickname() {
    final rng = math.Random();
    final adj = kNickAdjectives[rng.nextInt(kNickAdjectives.length)];
    final noun = kNickNouns[rng.nextInt(kNickNouns.length)];
    final suffix = 10 + rng.nextInt(90);
    return '$adj $noun $suffix';
  }
}

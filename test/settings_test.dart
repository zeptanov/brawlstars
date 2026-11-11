import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:maze_royale/app/local_settings_store.dart';
import 'package:maze_royale/app/settings.dart';

void main() {
  group('AppSettings local persistence', () {
    late _MemoryBackend preferences;
    late _MemoryBackend secrets;

    LocalSettingsStore createStore() =>
        LocalSettingsStore(preferences: preferences, secrets: secrets);

    setUp(() {
      preferences = _MemoryBackend();
      secrets = _MemoryBackend();
    });

    test('sound is muted by default and exposes independent mix levels', () {
      final settings = AppSettings.forTesting(createStore());

      expect(settings.soundEnabled, isFalse);
      expect(settings.musicVolume, 0.45);
      expect(settings.weaponVolume, 0.65);
      expect(settings.explosionVolume, 0.7);
      expect(settings.pickupVolume, 0.6);
      expect(settings.uiVolume, 0.5);
    });

    test(
      'restores settings and statistics after creating a new instance',
      () async {
        final settings = AppSettings.forTesting(createStore());
        await settings.load();
        settings
          ..setNickname('Pilot')
          ..setInputMode(2)
          ..setQuality(0)
          ..setSoundEnabled(true)
          ..setMusicVolume(0.35)
          ..setWeaponVolume(0.8)
          ..setExplosionVolume(0.55)
          ..setPickupVolume(0.65)
          ..setUiVolume(0.25)
          ..setDefaultBots(5)
          ..setDefaultTeams(true)
          ..setDefaultRespawn(true)
          ..setDefaultRespawnDelay(24)
          ..recordMatch(placement: 1, kills: 4, damage: 275.5, won: true);
        settings.saveLastLobbySettings(
          botCount: 2,
          mapSize: 61,
          mapGeneration: 2,
          tempo: 2,
          skill: 0,
          teams: true,
          deathVision: 0,
          loot: 2,
          friendlyFire: true,
          respawn: true,
          respawnDelay: 24,
          allyVision: false,
        );
        await settings.flushPendingWrites();

        final restored = AppSettings.forTesting(createStore());
        await restored.load();

        expect(restored.nickname, 'Pilot');
        expect(restored.inputMode, 2);
        expect(restored.quality, 0);
        expect(restored.soundEnabled, isTrue);
        expect(restored.musicVolume, 0.35);
        expect(restored.weaponVolume, 0.8);
        expect(restored.explosionVolume, 0.55);
        expect(restored.pickupVolume, 0.65);
        expect(restored.uiVolume, 0.25);
        expect(restored.defaultBots, 5);
        expect(restored.lastLobbyBotCount, 2);
        expect(restored.defaultMapSize, 61);
        expect(restored.defaultMapGeneration, 2);
        expect(restored.defaultTempo, 2);
        expect(restored.defaultSkill, 0);
        expect(restored.defaultTeams, isTrue);
        expect(restored.defaultAllyVision, isFalse);
        expect(restored.defaultDeathVision, 0);
        expect(restored.defaultLoot, 2);
        expect(restored.defaultFriendlyFire, isTrue);
        expect(restored.defaultRespawn, isTrue);
        expect(restored.defaultRespawnDelay, 24);
        expect(restored.matchesPlayed, 1);
        expect(restored.wins, 1);
        expect(restored.totalKills, 4);
        expect(restored.totalDamage, 275.5);
      },
    );

    test('stores statistics as authenticated ciphertext', () async {
      final store = createStore();
      await store.writeStatistics(<String, Object?>{
        'matchesPlayed': 2,
        'wins': 1,
        'totalKills': 42,
        'totalDamage': 987.5,
      });

      final encrypted = preferences.values.values.single;
      expect(encrypted, startsWith('v1:'));
      expect(encrypted, isNot(contains('987.5')));
      expect(encrypted, isNot(contains('totalKills')));
      expect(await store.readStatistics(), <String, Object?>{
        'matchesPlayed': 2,
        'wins': 1,
        'totalKills': 42,
        'totalDamage': 987.5,
      });
      expect(secrets.values, hasLength(1));
    });

    test('rejects modified or unauthentic statistics', () async {
      final store = createStore();
      await store.writeStatistics(<String, Object?>{
        'matchesPlayed': 1,
        'wins': 0,
        'totalKills': 0,
        'totalDamage': 0,
      });
      final key = preferences.values.keys.single;
      final envelope = jsonDecode(
        utf8.decode(base64Decode(preferences.values[key]!.substring(3))),
      ) as Map<String, dynamic>;
      final ciphertext = base64Decode(envelope['ciphertext'] as String);
      ciphertext[0] ^= 1;
      envelope['ciphertext'] = base64Encode(ciphertext);
      preferences.values[key] =
          'v1:${base64Encode(utf8.encode(jsonEncode(envelope)))}';

      await expectLater(
        store.readStatistics(),
        throwsA(isA<CorruptLocalDataException>()),
      );
    });
  });
}

class _MemoryBackend implements LocalPreferencesBackend, LocalSecretsBackend {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

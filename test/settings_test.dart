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

    test(
      'restores settings and statistics after creating a new instance',
      () async {
        final settings = AppSettings.forTesting(createStore());
        await settings.load();
        settings
          ..setNickname('Pilot')
          ..setInputMode(2)
          ..setQuality(0)
          ..setDefaultBots(5)
          ..setDefaultTeams(true)
          ..setDefaultRespawn(true)
          ..recordMatch(placement: 1, kills: 4, damage: 275.5, won: true);
        await settings.flushPendingWrites();

        final restored = AppSettings.forTesting(createStore());
        await restored.load();

        expect(restored.nickname, 'Pilot');
        expect(restored.inputMode, 2);
        expect(restored.quality, 0);
        expect(restored.defaultBots, 5);
        expect(restored.defaultTeams, isTrue);
        expect(restored.defaultRespawn, isTrue);
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

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all game audio files are included in the asset bundle', () async {
    const assets = <String>[
      'assets/audio/music/arena_theme.wav',
      'assets/audio/sfx/pistol.wav',
      'assets/audio/sfx/smg.wav',
      'assets/audio/sfx/shotgun.wav',
      'assets/audio/sfx/rifle.wav',
      'assets/audio/sfx/sniper.wav',
      'assets/audio/sfx/explosion.wav',
      'assets/audio/sfx/damage.wav',
      'assets/audio/sfx/pickup.wav',
      'assets/audio/sfx/dash.wav',
      'assets/audio/sfx/respawn.wav',
      'assets/audio/sfx/reload.wav',
      'assets/audio/sfx/hit.wav',
      'assets/audio/sfx/kill.wav',
      'assets/audio/sfx/ui.wav',
    ];

    for (final asset in assets) {
      expect(await rootBundle.load(asset), isNotNull, reason: asset);
    }
  });
}
